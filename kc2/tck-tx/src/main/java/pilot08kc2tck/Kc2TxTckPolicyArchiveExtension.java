package pilot08kc2tck;

import org.eclipse.edc.connector.controlplane.contract.spi.negotiation.observe.ContractNegotiationObservable;
import org.eclipse.edc.connector.controlplane.policy.spi.store.PolicyArchive;
import org.eclipse.edc.policy.model.Policy;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.system.ServiceExtension;

/**
 * Pilot 08 KC2 TCK fixture (D14): the PolicyArchive stand-in from Tractus-X 0.13.0's DSP-TCK test
 * (assigner = assignee = "TCK_PARTICIPANT", agreement id = contract id). The real PolicyArchive is a plain
 * (non-default) @Provider of ContractNegotiationDefaultServicesExtension, so precedence would otherwise be
 * load-order dependent — and a first run lost it (transfer start NPE on Policy.getAssignee(), 11 TP
 * scenarios; discarded as a setup artifact). Injecting ContractNegotiationObservable, which only that
 * extension provides, orders this extension AFTER it, so this stub registers last and every PolicyArchive
 * consumer (which depends on all providers) receives it. Asserted from the boot log by 50_tck_baseline.sh.
 */
public class Kc2TxTckPolicyArchiveExtension implements ServiceExtension {

    static final String TCK_PARTICIPANT = "TCK_PARTICIPANT";

    @Inject
    private ContractNegotiationObservable orderAfterContractNegotiationDefaults;   // ordering only

    @Override
    public String name() {
        return "Pilot08 KC2 Tractus-X TCK fixture (PolicyArchive stand-in)";
    }

    @Provider
    public PolicyArchive policyArchive() {
        return new TckPolicyArchive();
    }

    static final class TckPolicyArchive implements PolicyArchive {
        @Override public Policy findPolicyForContract(String contractId) {
            return Policy.Builder.newInstance().assigner(TCK_PARTICIPANT).assignee(TCK_PARTICIPANT).build();
        }
        @Override public String getAgreementIdForContract(String contractId) { return contractId; }
    }
}
