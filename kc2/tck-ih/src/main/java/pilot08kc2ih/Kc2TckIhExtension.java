package pilot08kc2ih;

import com.nimbusds.jose.jwk.ECKey;
import org.eclipse.edc.identityhub.spi.credential.request.model.HolderCredentialRequest;
import org.eclipse.edc.identityhub.spi.credential.request.model.HolderRequestState;
import org.eclipse.edc.identityhub.spi.credential.request.store.HolderCredentialRequestStore;
import org.eclipse.edc.identityhub.spi.participantcontext.IdentityHubParticipantContextService;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyDescriptor;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyPairUsage;
import org.eclipse.edc.identityhub.spi.participantcontext.model.ParticipantManifest;
import org.eclipse.edc.identityhub.spi.transformation.ScopeToCriterionTransformer;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Set;
import java.util.UUID;

/**
 * Pilot 08 KC2 DCP-TCK IdentityHub fixture (U5). Reproduces the holder-side setup of eclipse-edc/IdentityHub
 * v0.17.0 DcpPresentationFlowWithDockerTest: provides the TCK ScopeToCriterionTransformer, seeds one holder
 * participant (provided EC key, CredentialService endpoint) and one HolderCredentialRequest (REQUESTED, the
 * TCK's correlation id, MembershipCredential + SensitiveDataCredential as VC1_0_JWT), and writes the created
 * STS account's clientId/clientSecret to a file so the run script can hand them to the TCK container
 * (upstream reads them from the createParticipantContext response in-process). No credential is pre-stored —
 * the TCK issues them during the run via the correlation id. RevocationServiceRegistry is left real (deviation).
 */
public class Kc2TckIhExtension implements ServiceExtension {

    static final String PID = "pilot08.kc2.tckih.participant";          // e.g. holder
    static final String DID = "pilot08.kc2.tckih.did";
    static final String JWK = "pilot08.kc2.tckih.holderjwk.path";       // mounted EC private JWK (gitignored)
    static final String CS_URL = "pilot08.kc2.tckih.credentialservice.url";
    static final String CORRELATION = "pilot08.kc2.tckih.correlation.id";
    static final String STS_OUT = "pilot08.kc2.tckih.sts.out";          // file to write clientId/clientSecret (build/, gitignored)
    static final String AES_ALIAS = "edc.encryption.aes.key.alias";

    @Inject private IdentityHubParticipantContextService participants;
    @Inject private Vault vault;
    @Inject private HolderCredentialRequestStore requestStore;

    private ServiceExtensionContext context;

    @Override public String name() { return "Pilot08 KC2 DCP-TCK IdentityHub fixture"; }

    // Override the default scope transformer with the upstream TCK one.
    @Provider public ScopeToCriterionTransformer scopeTransformer() { return new TckTransformer(); }

    @Override public void initialize(ServiceExtensionContext context) {
        this.context = context;
        var aes = context.getSetting(AES_ALIAS, null);
        if (aes != null && !aes.isBlank() && vault.resolveSecret(aes) == null) {
            var raw = new byte[32]; new SecureRandom().nextBytes(raw);
            vault.storeSecret(aes, Base64.getEncoder().encodeToString(raw));
        }
    }

    // start(): all providers (incl. the aes algorithm) are registered by now.
    @Override public void start() {
        var id = context.getSetting(PID, null);
        if (id == null || id.isBlank()) { context.getMonitor().info("[pilot08-kc2-tckih] no participant configured; skipping"); return; }
        if (participants.getParticipantContext(id).succeeded()) { context.getMonitor().info("[pilot08-kc2-tckih] participant '" + id + "' present; skipping"); return; }
        try {
            var did = context.getSetting(DID, null);
            var key = ECKey.parse(Files.readString(Path.of(context.getSetting(JWK, null))));
            var privAlias = id + "-privatekey-alias";
            vault.storeSecret(id, privAlias, key.toJSONString());

            var kd = KeyDescriptor.Builder.newInstance()
                    .usage(Set.of(KeyPairUsage.PRESENTATION_SIGNING, KeyPairUsage.TOKEN_SIGNING))
                    .publicKeyJwk(key.toPublicJWK().toJSONObject())
                    .privateKeyAlias(privAlias)
                    .keyId(did + "#key1")   // full DID URL, so the verifier resolves the signing key via did:web
                    .build();
            var manifest = ParticipantManifest.Builder.newInstance()
                    .participantContextId(id).did(did).active(true)
                    .serviceEndpoint(new Service(UUID.randomUUID().toString(), "CredentialService", context.getSetting(CS_URL, null)))
                    .key(kd).build();
            var resp = participants.createParticipantContext(manifest)
                    .orElseThrow(f -> new RuntimeException("createParticipantContext: " + f.getFailureDetail()));

            var correlation = context.getSetting(CORRELATION, UUID.randomUUID().toString());
            requestStore.save(HolderCredentialRequest.Builder.newInstance()
                    .issuerDid("did:web:issuer")
                    .participantContextId(id)
                    .requestId(correlation)
                    .state(HolderRequestState.REQUESTED.code())
                    .issuerPid(UUID.randomUUID().toString())
                    .requestedCredential("membershipCredential-id", "MembershipCredential", "VC1_0_JWT")
                    .requestedCredential("sensitiveDataCredential-id", "SensitiveDataCredential", "VC1_0_JWT")
                    .build());

            var out = context.getSetting(STS_OUT, null);
            if (out != null) {
                Files.writeString(Path.of(out), "{\"clientId\":\"" + resp.clientId() + "\",\"clientSecret\":\"" + resp.clientSecret() + "\"}");
            }
            context.getMonitor().info("[pilot08-kc2-tckih] seeded holder '" + id + "' did=" + did + " clientId=" + resp.clientId() + " (secret written to sts.out)");
        } catch (Exception e) {
            context.getMonitor().severe("[pilot08-kc2-tckih] seeding failed: " + e.getMessage());
        }
    }
}
