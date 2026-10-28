package pilot08kc2tck;

import org.eclipse.edc.connector.controlplane.policy.spi.store.PolicyArchive;
import org.eclipse.edc.connector.controlplane.profile.DataspaceProfileContextRegistryImpl;
import org.eclipse.edc.policy.model.Policy;
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
 * Pilot 08 KC2 TCK fixture (D14). Re-creates, as a standalone extension, the four test-only stand-ins that
 * Tractus-X 0.13.0's own DSP-TCK test injects with registerServiceMock
 * (edc-tests/e2e/dsp-tck-tests/.../EdcCompatibilityPostgresTest.java, tag 0.13.0):
 *  - BdrsClient: identity pass-through (MockBdrsClient(s -> s, s -> s));
 *  - AgreementsBpnsStore: save succeeds; findByAgreementId returns provider = consumer = this BPN;
 *  - PolicyArchive: policy with assigner = assignee = "TCK_PARTICIPANT"; agreement id = contract id;
 *  - DataspaceProfileContextRegistry: participant id taken from the mock token's "client_id" claim.
 * They switch off the Tractus-X identity/BPN layers so the TCK's mock identity (tck-extension) works —
 * exactly as upstream; they are NOT used for any KC2 invariant run. Which provider wins for the plain
 * (non-default) BdrsClient / PolicyArchive / IdentityService is measured from the boot log, not assumed.
 */
public class Kc2TxTckFixtureExtension implements ServiceExtension {

    static final String TCK_PARTICIPANT = "TCK_PARTICIPANT";
    static final String BPN = "pilot08.kc2.tck.bpn";

    @Override
    public String name() {
        return "Pilot08 KC2 Tractus-X TCK fixture (upstream test stand-ins)";
    }

    @Provider
    public BdrsClient bdrsClient() {
        return new BdrsClient() {
            @Override public String resolveDid(String bpn) { return bpn; }
            @Override public String resolveBpn(String did) { return did; }
        };
    }

    @Provider
    public AgreementsBpnsStore agreementsBpnsStore(ServiceExtensionContext context) {
        var bpn = context.getSetting(BPN, "BPNL000000TCKCUT");
        return new AgreementsBpnsStore() {
            @Override public StoreResult<Void> save(AgreementsBpnsEntry entry) { return StoreResult.success(); }
            @Override public AgreementsBpnsEntry findByAgreementId(String agreementId) {
                return AgreementsBpnsEntry.Builder.newInstance().withAgreementId(agreementId)
                        .withProviderBpn(bpn).withConsumerBpn(bpn).build();
            }
        };
    }

    @Provider
    public PolicyArchive policyArchive() {
        return new PolicyArchive() {
            @Override public Policy findPolicyForContract(String contractId) {
                return Policy.Builder.newInstance().assigner(TCK_PARTICIPANT).assignee(TCK_PARTICIPANT).build();
            }
            @Override public String getAgreementIdForContract(String contractId) { return contractId; }
        };
    }

    @Provider
    public DataspaceProfileContextRegistry dataspaceProfileContextRegistry() {
        ParticipantIdExtractionFunction clientId = ct -> ct.getStringClaim("client_id");
        return new DataspaceProfileContextRegistryImpl() {
            @Override public ParticipantIdExtractionFunction getIdExtractionFunction(String protocol) { return clientId; }
        };
    }
}
