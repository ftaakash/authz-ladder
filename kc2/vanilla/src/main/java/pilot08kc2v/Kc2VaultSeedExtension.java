package pilot08kc2v;

import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

/**
 * Pilot 08 KC2 test fixture (local testbed only): seeds the vanilla EDC in-memory vault from the setting
 * {@code pilot08.kc2.vault.secrets} = "alias:value;alias:value" (same format as Tractus-X's
 * VaultSeedExtension, tx.edc.vault.secrets). Vanilla EDC's InMemoryVault has no seeding mechanism, and
 * the remote-STS client secret and transfer-proxy keys must be resolvable from the vault. Secret values
 * are never logged. No-op when the setting is absent.
 */
public class Kc2VaultSeedExtension implements ServiceExtension {

    static final String SECRETS = "pilot08.kc2.vault.secrets";

    @Inject
    private Vault vault;

    @Override
    public String name() {
        return "Pilot08 KC2 vault seed (test fixture)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var raw = context.getSetting(SECRETS, null);
        if (raw == null || raw.isBlank()) {
            return;
        }
        var n = 0;
        for (var kv : raw.split(";")) {
            var parts = kv.split(":", 2);
            if (parts.length == 2 && !parts[0].isBlank()) {
                vault.storeSecret(parts[0].trim(), parts[1]);
                n++;
            }
        }
        context.getMonitor().info("[pilot08-kc2] seeded " + n + " vault secret(s)");
    }
}
