package pilot08kc2;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.eclipse.edc.iam.verifiablecredentials.spi.model.CredentialFormat;
import org.eclipse.edc.iam.verifiablecredentials.spi.model.CredentialSubject;
import org.eclipse.edc.iam.verifiablecredentials.spi.model.Issuer;
import org.eclipse.edc.iam.verifiablecredentials.spi.model.VerifiableCredential;
import org.eclipse.edc.iam.verifiablecredentials.spi.model.VerifiableCredentialContainer;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.identityhub.spi.participantcontext.IdentityHubParticipantContextService;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyDescriptor;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyPairUsage;
import org.eclipse.edc.identityhub.spi.participantcontext.model.ParticipantManifest;
import org.eclipse.edc.identityhub.spi.verifiablecredentials.model.VcStatus;
import org.eclipse.edc.identityhub.spi.verifiablecredentials.model.VerifiableCredentialResource;
import org.eclipse.edc.identityhub.spi.verifiablecredentials.store.CredentialStore;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Pilot 08 KC2 minimal seeding (local testbed only). The IdentityHub BOM ships no
 * first-participant bootstrap, so a did:web document only exists once a participant
 * context + keypair are created. This extension creates exactly ONE configured
 * participant context at startup via the official IdentityHubParticipantContextService
 * (the same service the Identity API calls), which generates the keypair and publishes
 * the participant's did:web document through the local DID publisher.
 *
 * It does NOT issue or seed any VerifiableCredential (MembershipCredential): credential
 * issuance and the DCP token handshake are deliberately out of scope for the phase-2
 * did:web-resolution milestone. If the seed settings are absent, the extension is a no-op.
 */
public class Kc2SeedExtension implements ServiceExtension {

    static final String ID = "pilot08.kc2.seed.participant.id";       // e.g. provider
    static final String DID = "pilot08.kc2.seed.participant.did";     // e.g. did:web:provider-ih%3A7083:provider
    static final String KEY_ALIAS = "pilot08.kc2.seed.key.alias";     // vault alias for the generated private key
    static final String KEY_ID = "pilot08.kc2.seed.key.id";           // key id used in the DID verificationMethod
    static final String AES_ALIAS = "edc.encryption.aes.key.alias";   // the IdentityHub participant-config AES key alias
    static final String STS_SECRET = "pilot08.kc2.seed.sts.client.secret"; // known STS client secret (testbed)
    static final String BPN = "pilot08.kc2.seed.bpn";                 // holder BPN (business partner number)
    static final String ISSUER_DID = "pilot08.kc2.issuer.did";        // trusted issuer DID (resolvable did:web)
    static final String ISSUER_JWK_PATH = "pilot08.kc2.issuer.privjwk.path"; // mounted gitignored issuer private JWK
    static final String ISSUER_KEY_ID = "pilot08.kc2.issuer.keyid";   // issuer verification method key id
    static final String CRED_SVC_URL = "pilot08.kc2.seed.credentialservice.url"; // this participant's CredentialService endpoint (advertised in its DID doc)

    @Inject
    private IdentityHubParticipantContextService participantContextService;

    @Inject
    private Vault vault;

    @Inject
    private CredentialStore credentialStore;

    private ServiceExtensionContext context;

    @Override
    public String name() {
        return "Pilot08 KC2 participant seed (test fixture)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        this.context = context;
        // Seed the participant-config AES key early (lazily read at encrypt time). Harmless if unset.
        var aesAlias = context.getSetting(AES_ALIAS, null);
        if (aesAlias != null && !aesAlias.isBlank() && vault.resolveSecret(aesAlias) == null) {
            var raw = new byte[32];
            new SecureRandom().nextBytes(raw);
            vault.storeSecret(aesAlias, Base64.getEncoder().encodeToString(raw));
            context.getMonitor().info("[pilot08-kc2] seeded AES config key at alias '" + aesAlias + "'");
        }
    }

    // Seeding runs in start(): by then every extension's initialize() has completed, so the
    // "aes" encryption algorithm used by the participant-config store is registered.
    @Override
    public void start() {
        var id = context.getSetting(ID, null);
        if (id == null || id.isBlank()) {
            context.getMonitor().info("[pilot08-kc2] no seed participant configured; skipping");
            return;
        }
        var did = context.getSetting(DID, null);
        var keyAlias = context.getSetting(KEY_ALIAS, id + "-private-key");
        var keyId = context.getSetting(KEY_ID, id + "-key-1");

        var existing = participantContextService.getParticipantContext(id);
        if (existing.succeeded()) {
            context.getMonitor().info("[pilot08-kc2] participant '" + id + "' already present; skipping seed");
            return;
        }

        var key = KeyDescriptor.Builder.newInstance()
                .keyId(keyId)
                .privateKeyAlias(keyAlias)
                .active(true)
                .usage(Set.of(KeyPairUsage.PRESENTATION_SIGNING, KeyPairUsage.TOKEN_SIGNING))
                .keyGeneratorParams(Map.of("algorithm", "EdDSA", "curve", "Ed25519"))
                .build();

        var manifestBuilder = ParticipantManifest.Builder.newInstance()
                .participantContextId(id)
                .did(did)
                .active(true)
                .key(key);
        // Advertise a CredentialService endpoint in the DID document so a counterparty can fetch this
        // participant's VP (DidCredentialServiceUrlResolver looks for a service of type "CredentialService").
        var credSvcUrl = context.getSetting(CRED_SVC_URL, null);
        if (credSvcUrl != null && !credSvcUrl.isBlank()) {
            manifestBuilder.serviceEndpoint(new Service("credential-service", "CredentialService", credSvcUrl));
        }
        var manifest = manifestBuilder.build();

        var result = participantContextService.createParticipantContext(manifest);
        if (result.succeeded()) {
            context.getMonitor().info("[pilot08-kc2] seeded participant '" + id + "' did=" + did + " (keypair generated, DID published)");
            // Overwrite the STS account's randomly-generated client secret with a KNOWN testbed value
            // so the connector (remote STS client) can authenticate with a secret we also place in its
            // own vault. Default alias = "<id>-sts-client-secret" (IdentityHubParticipantContext).
            var stsSecret = context.getSetting(STS_SECRET, null);
            if (stsSecret != null && !stsSecret.isBlank()) {
                var alias = id + "-sts-client-secret";
                vault.storeSecret(id, alias, stsSecret);   // partition = participantContextId (RemoteSecureTokenService resolves here)
                vault.storeSecret(alias, stsSecret);       // in-memory vault ignores the partition; set the flat key too
                context.getMonitor().info("[pilot08-kc2] set known STS client secret at alias '" + alias + "'");
            }
            seedMembershipCredential(id, did);
        } else {
            context.getMonitor().severe("[pilot08-kc2] seed FAILED for '" + id + "': " + result.getFailureDetail());
        }
    }

    // Route I (D13): issue a REALISTIC MembershipCredential signed by the trusted issuer's key and store
    // it directly in this holder's credential store, so the credential service can present a VP. This is
    // the approach the Tractus-X e2e `DataspaceIssuer` fixture uses. NOT the DCP issuance protocol.
    private void seedMembershipCredential(String holderId, String holderDid) {
        var bpn = context.getSetting(BPN, null);
        var issuerDid = context.getSetting(ISSUER_DID, null);
        var jwkPath = context.getSetting(ISSUER_JWK_PATH, null);
        var keyId = context.getSetting(ISSUER_KEY_ID, "key-1");
        if (bpn == null || issuerDid == null || jwkPath == null) {
            context.getMonitor().info("[pilot08-kc2] membership credential not configured for '" + holderId + "'; skipping");
            return;
        }
        try {
            var issuerKey = ECKey.parse(Files.readString(Path.of(jwkPath)));
            var now = Instant.now();
            var exp = now.plusSeconds(365L * 24 * 3600);

            // VC JSON (matches the Catena-X membership VC shape) carried in the JWT "vc" claim.
            var subject = new LinkedHashMap<String, Object>();
            subject.put("type", "MembershipCredential");
            subject.put("holderIdentifier", bpn);
            subject.put("id", holderDid);
            var vc = new LinkedHashMap<String, Object>();
            vc.put("@context", List.of(
                    "https://www.w3.org/2018/credentials/v1",
                    "https://w3id.org/security/suites/jws-2020/v1",
                    "https://w3id.org/catenax/credentials",
                    "https://w3id.org/vc/status-list/2021/v1"));
            vc.put("type", List.of("MembershipCredential", "VerifiableCredential"));
            vc.put("issuer", issuerDid);
            vc.put("issuanceDate", now.toString());
            vc.put("expirationDate", exp.toString());
            vc.put("credentialSubject", subject);

            var claims = new JWTClaimsSet.Builder()
                    .issuer(issuerDid)
                    .subject(holderDid)
                    .jwtID(UUID.randomUUID().toString())
                    .issueTime(Date.from(now))
                    .notBeforeTime(Date.from(now))
                    .expirationTime(Date.from(exp))
                    .claim("vc", vc)
                    .build();
            var jws = new SignedJWT(
                    new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(issuerDid + "#" + keyId).type(com.nimbusds.jose.JOSEObjectType.JWT).build(),
                    claims);
            jws.sign(new ECDSASigner(issuerKey));
            var rawVc = jws.serialize();

            var credential = VerifiableCredential.Builder.newInstance()
                    .id(holderDid)
                    .type("MembershipCredential")
                    .type("VerifiableCredential")
                    .issuer(new Issuer(issuerDid, Map.of()))
                    .issuanceDate(now)
                    .expirationDate(exp)
                    .credentialSubject(CredentialSubject.Builder.newInstance().id(holderDid).claim("holderIdentifier", bpn).build())
                    .context("https://www.w3.org/2018/credentials/v1")
                    .build();
            var container = new VerifiableCredentialContainer(rawVc, CredentialFormat.VC1_0_JWT, credential);
            var resource = VerifiableCredentialResource.Builder.newHolder()
                    .id(UUID.randomUUID().toString())
                    .issuerId(issuerDid)
                    .holderId(bpn)
                    .participantContextId(holderId)
                    .credential(container)
                    .state(VcStatus.ISSUED)
                    .build();
            var r = credentialStore.create(resource);
            if (r.succeeded()) {
                context.getMonitor().info("[pilot08-kc2] stored MembershipCredential for '" + holderId + "' (issuer " + issuerDid + ", bpn " + bpn + ")");
            } else {
                context.getMonitor().severe("[pilot08-kc2] credential store FAILED for '" + holderId + "': " + r.getFailureDetail());
            }
        } catch (Exception e) {
            context.getMonitor().severe("[pilot08-kc2] membership credential seeding error for '" + holderId + "': " + e.getMessage());
        }
    }
}
