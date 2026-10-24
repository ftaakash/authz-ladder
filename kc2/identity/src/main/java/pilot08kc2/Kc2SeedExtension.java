package pilot08kc2;

import org.eclipse.edc.identityhub.spi.participantcontext.IdentityHubParticipantContextService;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyDescriptor;
import org.eclipse.edc.identityhub.spi.participantcontext.model.KeyPairUsage;
import org.eclipse.edc.identityhub.spi.participantcontext.model.ParticipantManifest;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.Set;

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

    @Inject
    private IdentityHubParticipantContextService participantContextService;

    @Inject
    private Vault vault;

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

        var manifest = ParticipantManifest.Builder.newInstance()
                .participantContextId(id)
                .did(did)
                .active(true)
                .key(key)
                .build();

        var result = participantContextService.createParticipantContext(manifest);
        if (result.succeeded()) {
            context.getMonitor().info("[pilot08-kc2] seeded participant '" + id + "' did=" + did + " (keypair generated, DID published)");
        } else {
            context.getMonitor().severe("[pilot08-kc2] seed FAILED for '" + id + "': " + result.getFailureDetail());
        }
    }
}
