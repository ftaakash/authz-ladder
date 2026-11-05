package pilot08kc2tx;

import org.eclipse.edc.connector.controlplane.asset.spi.index.AssetIndex;
import org.eclipse.edc.connector.controlplane.contract.policy.PolicyEquality;
import org.eclipse.edc.connector.controlplane.contract.spi.negotiation.NegotiationProcessors;
import org.eclipse.edc.connector.controlplane.contract.spi.types.agreement.ContractAgreement;
import org.eclipse.edc.connector.controlplane.contract.spi.types.negotiation.ContractNegotiation;
import org.eclipse.edc.connector.controlplane.contract.spi.types.offer.ContractOffer;
import org.eclipse.edc.connector.controlplane.contract.spi.validation.ContractValidationService;
import org.eclipse.edc.connector.controlplane.contract.spi.validation.ValidatableConsumerOffer;
import org.eclipse.edc.connector.controlplane.contract.spi.validation.ValidatedConsumerOffer;
import org.eclipse.edc.connector.controlplane.contract.validation.ContractValidationServiceImpl;
import org.eclipse.edc.participant.spi.ParticipantAgent;
import org.eclipse.edc.policy.engine.spi.PolicyEngine;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.types.TypeManager;

/**
 * Pilot 08 KC2 — INV-4 MUTATION add-on (local testbed only; Tractus-X target).
 *
 * <p><b>LABELLED TEST-ONLY.</b> On the classpath ONLY in the INV-4 <i>mutation</i> cell, NEVER on a
 * current-release (verdict) run. It encodes the generic INV-4 violation — "the transfer is not bound to a
 * valid agreement for this counterparty" — the spec-rule negation (INVARIANTS amendment A1/A2). No finding.
 *
 * <p><b>What the release does (EDC 0.17.0).</b> On an incoming transfer the provider enforces the
 * agreement&harr;counterparty binding through {@link ContractValidationService}:
 * {@code TransferProcessProtocolServiceImpl.validateRequestMessage} calls {@code validateAgreement(agent,
 * agreement)} and {@code onMessageDo/validateCounterParty} calls {@code validateRequest(agent, agreement)}.
 * A party reusing another party's agreement, or citing an agreement for a different asset, fails there.
 *
 * <p><b>This mutation.</b> It provides a {@link ContractValidationService} that delegates every method to a
 * real {@link ContractValidationServiceImpl} (so contract <i>negotiation</i> is untouched and A's legitimate
 * setup is realistic) EXCEPT the two transfer-time checks — {@code validateAgreement} and
 * {@code validateRequest(agent, agreement)} — which it forces to success. With those bypassed, a transfer
 * citing an agreement that is not the counterparty's proceeds, which is exactly the violation.
 *
 * <p><b>Precedence.</b> {@code ContractCoreExtension} registers the real service; injecting
 * {@link NegotiationProcessors} (which only that extension provides) orders this extension after it, so this
 * {@code @Provider} registers last and every consumer (which depends on all providers) receives it — the same
 * ordering trick the DSP-TCK PolicyArchive stand-in uses. The driver confirms the mutation fired (log marker)
 * and that it produced a violation; otherwise the cell is INVALID, never a false FAIL.
 *
 * <p><b>Gating.</b> Inert unless {@value #TOGGLE} is {@code true}; when off it provides the plain real service.
 */
public class Inv4TransferBindingMutationExtension implements ServiceExtension {

    static final String TOGGLE = "pilot08.kc2.mutation.inv4.skip-agreement-binding";

    @Inject
    private AssetIndex assetIndex;
    @Inject
    private PolicyEngine policyEngine;
    @Inject
    private TypeManager typeManager;
    @Inject
    private NegotiationProcessors orderAfterContractCore; // ordering handle only (provided by ContractCoreExtension)

    private Monitor monitor;
    private boolean active;

    @Override
    public String name() {
        return "Pilot08 KC2 INV-4 agreement-binding MUTATION (test-only add-on)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        monitor = context.getMonitor();
        active = Boolean.parseBoolean(context.getSetting(TOGGLE, "false"));
        monitor.warning("[pilot08-kc2][INV-4 MUTATION] add-on loaded; active=" + active + " (toggle " + TOGGLE + ")");
    }

    @Provider
    public ContractValidationService contractValidationService() {
        var real = new ContractValidationServiceImpl(assetIndex, policyEngine, new PolicyEquality(typeManager));
        if (!active) {
            return real;
        }
        monitor.warning("[pilot08-kc2][INV-4 MUTATION] ACTIVE: transfer agreement-binding checks"
                + " (validateAgreement / validateRequest(agreement)) bypassed");
        return new PermissiveTransferBinding(real, monitor);
    }

    /** Delegates negotiation checks to the real service; forces the two transfer-time checks to success. */
    static final class PermissiveTransferBinding implements ContractValidationService {
        private final ContractValidationService delegate;
        private final Monitor monitor;

        PermissiveTransferBinding(ContractValidationService delegate, Monitor monitor) {
            this.delegate = delegate;
            this.monitor = monitor;
        }

        @Override
        public Result<ValidatedConsumerOffer> validateInitialOffer(ParticipantAgent agent, ValidatableConsumerOffer offer) {
            return delegate.validateInitialOffer(agent, offer);
        }

        @Override
        public Result<ContractAgreement> validateAgreement(ParticipantAgent agent, ContractAgreement agreement) {
            monitor.warning("[pilot08-kc2][INV-4 MUTATION] validateAgreement -> ALLOW (agreement-binding bypassed)");
            return Result.success(agreement);
        }

        @Override
        public Result<Void> validateRequest(ParticipantAgent agent, ContractAgreement agreement) {
            monitor.warning("[pilot08-kc2][INV-4 MUTATION] validateRequest(agreement) -> ALLOW (counterparty binding bypassed)");
            return Result.success();
        }

        @Override
        public Result<Void> validateRequest(ParticipantAgent agent, ContractNegotiation negotiation) {
            return delegate.validateRequest(agent, negotiation);
        }

        @Override
        public Result<Void> validateConfirmed(ParticipantAgent agent, ContractAgreement agreement, ContractOffer latestOffer) {
            return delegate.validateConfirmed(agent, agreement, latestOffer);
        }
    }
}
