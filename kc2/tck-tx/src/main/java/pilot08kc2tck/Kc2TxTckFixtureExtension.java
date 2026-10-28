package pilot08kc2tck;

import org.eclipse.edc.connector.controlplane.profile.DataspaceProfileContextRegistryImpl;
import org.eclipse.edc.protocol.spi.DataspaceProfileContextRegistry;
import org.eclipse.edc.protocol.spi.ParticipantIdExtractionFunction;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.result.StoreResult;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.tractusx.edc.agreements.bpns.spi.store.AgreementsBpnsStore;
import org.eclipse.tractusx.edc.agreements.bpns.spi.types.AgreementsBpnsEntry;
import org.eclipse.tractusx.edc.spi.identity.mapper.BdrsClient;

/**
 * Pilot 08 KC2 TCK fixture (D14). Re-creates, as standalone services, the test-only stand-ins that Tractus-X
 * 0.13.0's own DSP-TCK test injects with registerServiceMock
 * (edc-tests/e2e/dsp-tck-tests/.../EdcCompatibilityPostgresTest.java, tag 0.13.0):
 *  - BdrsClient: identity pass-through (MockBdrsClient(s -> s, s -> s));
 *  - AgreementsBpnsStore: save succeeds; findByAgreementId returns provider = consumer = this BPN;
 *  - DataspaceProfileContextRegistry: participant id taken from the mock token's "client_id" claim.
 * (The PolicyArchive stand-in lives in Kc2TxTckPolicyArchiveExtension, ordered deterministically.)
 * They switch off the Tractus-X identity/BPN layers so the TCK's mock identity (tck-extension) works —
 * exactly as upstream; they are never used for a KC2 invariant run. Each is a NAMED class so the boot log's
 * "was already registered and has now been replaced with a <Name> instance" line identifies the winner;
 * 50_tck_baseline.sh asserts the expected winners and otherwise declares the reproduction invalid.
 */
public class Kc2TxTckFixtureExtension implements ServiceExtension {

    static final String BPN = "pilot08.kc2.tck.bpn";

    @Override
    public String name() {
        return "Pilot08 KC2 Tractus-X TCK fixture (upstream test stand-ins)";
    }

    @Provider
    public BdrsClient bdrsClient() {
        return new TckPassThroughBdrsClient();
    }

    @Provider
    public AgreementsBpnsStore agreementsBpnsStore(ServiceExtensionContext context) {
        return new TckAgreementsBpnsStore(context.getSetting(BPN, "BPNL000000TCKCUT"));
    }

    @Provider
    public DataspaceProfileContextRegistry dataspaceProfileContextRegistry() {
        return new TckClientIdProfileContextRegistry();
    }

    static final class TckPassThroughBdrsClient implements BdrsClient {
        @Override public String resolveDid(String bpn) { return bpn; }
        @Override public String resolveBpn(String did) { return did; }
    }

    static final class TckAgreementsBpnsStore implements AgreementsBpnsStore {
        private final String bpn;
        TckAgreementsBpnsStore(String bpn) { this.bpn = bpn; }
        @Override public StoreResult<Void> save(AgreementsBpnsEntry entry) { return StoreResult.success(); }
        @Override public AgreementsBpnsEntry findByAgreementId(String agreementId) {
            return AgreementsBpnsEntry.Builder.newInstance().withAgreementId(agreementId)
                    .withProviderBpn(bpn).withConsumerBpn(bpn).build();
        }
    }

    static final class TckClientIdProfileContextRegistry extends DataspaceProfileContextRegistryImpl {
        private final ParticipantIdExtractionFunction clientId = ct -> ct.getStringClaim("client_id");
        @Override public ParticipantIdExtractionFunction getIdExtractionFunction(String protocol) { return clientId; }
    }
}
