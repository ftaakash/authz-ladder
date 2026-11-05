package pilot08kc2tx;

import org.eclipse.edc.connector.controlplane.contract.spi.policy.ContractNegotiationPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.engine.spi.PolicyEngine;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

/**
 * Pilot 08 KC2 — INV-6 MUTATION add-on (local testbed only; Tractus-X target).
 *
 * <p><b>LABELLED TEST-ONLY.</b> This extension is on the classpath ONLY in the INV-6 <i>mutation</i> cell and
 * NEVER on a current-release (verdict) run. It encodes the generic INV-6 violation — "the contract/usage
 * policy constraint is not enforced at negotiation" — the spec-rule negation (INVARIANTS amendment A1/A2). It
 * reveals no finding.
 *
 * <p><b>What the release does (pinned source, Tractus-X 0.13.0 → EDC 0.17.0).</b> The per-party discriminator
 * at the contract-negotiation scope is the BusinessPartnerNumber constraint:
 * {@code BusinessPartnerNumberValidationExtension#initialize} (bpn-validation-core, lines 82/92-93) binds
 * {@code BusinessPartnerNumberPermissionLegacyFunction} to {@code NEGOTIATION_SCOPE} and registers it
 * <i>keyed</i> under {@value #BPN_KEY} and {@value #TX_BPN_KEY} for {@link ContractNegotiationPolicyContext}.
 * (cx-policy's Membership admits every member, so it cannot deny a specific party — BPN can.)
 *
 * <p><b>How this mutation wins deterministically.</b> EDC resolves a keyed permission constraint via a
 * last-registration-wins map ({@code PolicyEvaluator.permissionFunctions.put}, rebuilt per evaluate() by
 * iterating {@code PolicyEngineImpl.constraintFunctions} in registration order). The release registers the BPN
 * function in {@code initialize()}; this extension re-registers a permissive stand-in for the same keys in
 * {@code start()} — which the EDC boot sequence runs after every {@code initialize()} — so our entry is
 * appended last and overrides the release function. The driver still confirms the override actually fired
 * (log marker below) and that the mutation produced a violation; otherwise the cell is INVALID, never a false
 * FAIL.
 *
 * <p><b>Gating.</b> Inert unless {@value #TOGGLE} is {@code true}, so the same add-on jar can be mounted
 * without side effects and only the intended cell activates the mutation.
 */
public class Inv6NegotiationMutationExtension implements ServiceExtension {

    static final String BPN_KEY = "BusinessPartnerNumber";
    static final String TX_BPN_KEY = "https://w3id.org/tractusx/v0.0.1/ns/BusinessPartnerNumber";
    static final String TOGGLE = "pilot08.kc2.mutation.inv6.bpn-permissive";

    @Inject
    private PolicyEngine policyEngine;

    private Monitor monitor;
    private boolean active;

    @Override
    public String name() {
        return "Pilot08 KC2 INV-6 negotiation-constraint MUTATION (test-only add-on)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        monitor = context.getMonitor();
        active = Boolean.parseBoolean(context.getSetting(TOGGLE, "false"));
        monitor.warning("[pilot08-kc2][INV-6 MUTATION] add-on loaded; active=" + active
                + " (toggle " + TOGGLE + ")");
    }

    @Override
    public void start() {
        if (!active) {
            return;
        }
        AtomicConstraintRuleFunction<Permission, ContractNegotiationPolicyContext> permissive =
                (Operator operator, Object rightValue, Permission rule, ContractNegotiationPolicyContext ctx) -> {
                    monitor.warning("[pilot08-kc2][INV-6 MUTATION] permissive negotiation BPN constraint"
                            + " op=" + operator + " right='" + rightValue + "' -> ALLOW (test-only add-on)");
                    return true;
                };
        policyEngine.registerFunction(ContractNegotiationPolicyContext.class, Permission.class, BPN_KEY, permissive);
        policyEngine.registerFunction(ContractNegotiationPolicyContext.class, Permission.class, TX_BPN_KEY, permissive);
        monitor.warning("[pilot08-kc2][INV-6 MUTATION] ACTIVE: negotiation BusinessPartnerNumber constraint"
                + " overridden permissively for keys [" + BPN_KEY + ", " + TX_BPN_KEY + "]");
    }
}
