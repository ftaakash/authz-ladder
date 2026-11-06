package pilot08kc2tx;

import org.eclipse.edc.connector.controlplane.contract.spi.negotiation.store.ContractNegotiationStore;
import org.eclipse.edc.connector.controlplane.contract.spi.types.agreement.ContractAgreement;
import org.eclipse.edc.connector.controlplane.contract.spi.types.negotiation.ContractNegotiation;
import org.eclipse.edc.connector.controlplane.defaults.storage.contractnegotiation.InMemoryContractNegotiationStore;
import org.eclipse.edc.policy.model.Policy;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.query.Criterion;
import org.eclipse.edc.spi.query.CriterionOperatorRegistry;
import org.eclipse.edc.spi.query.QuerySpec;
import org.eclipse.edc.spi.result.StoreResult;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

import java.time.Clock;
import java.util.List;
import java.util.stream.Stream;

/**
 * Pilot 08 KC2 — INV-4 CONSUMER-SIDE test driver (DSP client fixture; local testbed only; Tractus-X target).
 *
 * <p><b>What this is.</b> A conformance-test client fixture (the kind SCOPE's "DSP client fixture"
 * contemplates, the way the DSP TCK emits protocol messages). It runs ONLY on the attacker consumer (party B),
 * NEVER on the provider under test, and it does NOT weaken the provider: the provider keeps every check on.
 *
 * <p><b>Why it is needed.</b> EDC's honest consumer refuses to even emit a transfer for an agreement it does
 * not hold locally ({@code TransferProcessServiceImpl.initiateTransfer} returns badRequest when
 * {@code contractNegotiationStore.findContractAgreement(contractId) == null}). That client-side refusal means
 * B can never deliver the INV-4 attack (a transfer citing another party's agreement) to the provider's
 * boundary. This fixture removes only that client-side precondition on B, so B emits a real, properly
 * DCP-authenticated DSP {@code TransferRequestMessage} citing A's (non-secret) agreement id — using B's OWN
 * legitimately-issued token. B forges nothing; A's token/VP and private keys are never touched.
 *
 * <p><b>Mechanism.</b> EDC's in-memory {@link ContractNegotiationStore} is a {@code @Provider(isDefault=true)}
 * (ControlPlaneDefaultServicesExtension). This non-default provider therefore wins, and ALL of B's real
 * negotiation persistence flows through it (it delegates to a fresh in-memory store). Only
 * {@code findContractAgreement} is altered, and only when {@value #TOGGLE} is set: if B holds no agreement with
 * the requested id, it returns a synthetic placeholder so B's connector will proceed to send the DSP request.
 * The provider resolves the id against ITS OWN agreement (consumer = A) and must reject B — that rejection is
 * the INV-4 verdict. When the toggle is off the fixture is a transparent pass-through.
 */
public class Inv4ConsumerForeignAgreementFixtureExtension implements ServiceExtension {

    static final String TOGGLE = "pilot08.kc2.attack.inv4.allow-foreign-agreement";
    static final String PROVIDER_ID = "pilot08.kc2.attack.inv4.provider-id";

    @Inject
    private Clock clock;
    @Inject
    private CriterionOperatorRegistry criterionOperatorRegistry;

    private Monitor monitor;
    private boolean active;
    private String providerId;

    @Override
    public String name() {
        return "Pilot08 KC2 INV-4 consumer-side DSP client fixture (test-only)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        monitor = context.getMonitor();
        active = Boolean.parseBoolean(context.getSetting(TOGGLE, "false"));
        providerId = context.getSetting(PROVIDER_ID, "");
        monitor.warning("[pilot08-kc2][INV-4 ATTACK] consumer fixture loaded; active=" + active
                + " providerId='" + providerId + "' (toggle " + TOGGLE + ")");
    }

    @Provider
    public ContractNegotiationStore contractNegotiationStore() {
        var inner = new InMemoryContractNegotiationStore(clock, criterionOperatorRegistry);
        return new ForeignAgreementStore(inner);
    }

    /** Delegates every method to a real in-memory store; only synthesizes a missing agreement when toggled. */
    final class ForeignAgreementStore implements ContractNegotiationStore {
        private final ContractNegotiationStore delegate;

        ForeignAgreementStore(ContractNegotiationStore delegate) {
            this.delegate = delegate;
        }

        @Override
        public ContractAgreement findContractAgreement(String contractId) {
            var real = delegate.findContractAgreement(contractId);
            if (real != null || !active) {
                return real;
            }
            monitor.warning("[pilot08-kc2][INV-4 ATTACK] synthesizing local placeholder for foreign agreement id="
                    + contractId + " assigner='" + providerId + "' so B emits the DSP request (provider still enforces)");
            // The consumer dispatcher derives the DSP counterPartyId from the contract policy's assigner
            // (TransferProcessorsImpl: counterPartyId = contractPolicy.getAssigner()), so the placeholder policy
            // must carry the provider id as assigner or the outbound send NPEs before it ever reaches the provider.
            return ContractAgreement.Builder.newInstance()
                    .id(contractId)
                    .providerId(providerId)
                    .consumerId("urn:pilot08:self")
                    .assetId("pilot08-foreign-agreement-probe")
                    .policy(Policy.Builder.newInstance().assigner(providerId).build())
                    .build();
        }

        @Override
        public ContractNegotiation findById(String negotiationId) {
            return delegate.findById(negotiationId);
        }

        @Override
        public StoreResult<Void> deleteById(String negotiationId) {
            return delegate.deleteById(negotiationId);
        }

        @Override
        public Stream<ContractNegotiation> queryNegotiations(QuerySpec querySpec) {
            return delegate.queryNegotiations(querySpec);
        }

        @Override
        public Stream<ContractAgreement> queryAgreements(QuerySpec querySpec) {
            return delegate.queryAgreements(querySpec);
        }

        @Override
        public List<ContractNegotiation> nextNotLeased(int max, Criterion... criteria) {
            return delegate.nextNotLeased(max, criteria);
        }

        @Override
        public StoreResult<ContractNegotiation> findByIdAndLease(String id) {
            return delegate.findByIdAndLease(id);
        }

        @Override
        public StoreResult<Void> save(ContractNegotiation entity) {
            return delegate.save(entity);
        }

        @Override
        public StoreResult<Void> breakLease(ContractNegotiation entity) {
            return delegate.breakLease(entity);
        }
    }
}
