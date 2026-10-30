package pilot08kc2v;

import org.eclipse.edc.connector.controlplane.catalog.spi.policy.CatalogPolicyContext;
import org.eclipse.edc.connector.controlplane.contract.spi.policy.ContractNegotiationPolicyContext;
import org.eclipse.edc.participant.spi.ParticipantAgentPolicyContext;
import org.eclipse.edc.policy.engine.spi.AtomicConstraintRuleFunction;
import org.eclipse.edc.policy.engine.spi.PolicyEngine;
import org.eclipse.edc.policy.engine.spi.RuleBindingRegistry;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

/**
 * Pilot 08 KC2 — INV-6 probe + admission mutation (local testbed only; vanilla Eclipse EDC target).
 *
 * <p>INV-6 (kc2/INVARIANTS.md) asks whether the connector evaluates a <b>contract/usage policy</b> at
 * contract <b>negotiation</b>, not only when filtering the catalogue. This extension registers a single,
 * purpose-built usage-policy constraint — left operand {@value #MEMBER} — whose evaluation function simply
 * checks that the authenticated counterparty's identity (DID) equals the constraint's right value. It is a
 * faithful probe of the connector's native policy pipeline: the <i>function</i> is ours, but whether the
 * pipeline runs negotiation-scope functions at all is the connector's behaviour under test.
 *
 * <p>Scope registration is the knob:
 * <ul>
 *   <li>The function/operand is always bound in the <b>catalog</b> scope.</li>
 *   <li>It is bound in the <b>negotiation</b> scope <b>unless</b> the test-only mutation toggle
 *       {@value #MUT_UNBIND} is set. Leaving the negotiation scope unbound makes the connector's policy
 *       engine filter the constraint out before evaluation — i.e. it models exactly the INV-6 violation
 *       "no constraint function bound in the negotiation scope" (the generic negation of the spec rule).</li>
 * </ul>
 *
 * <p>{@value #MUT_UNBIND} defaults to {@code false}, so the <b>sanity</b> and <b>current-release</b>
 * configurations run the real, bound function; only the labelled <b>mutation</b> cell sets it. The toggle is
 * never used for a current-release verdict and encodes no finding (INVARIANTS amendment A1). No-op unless the
 * runtime is asked to register (the function is cheap and inert when no policy references {@value #MEMBER}).
 */
public class Kc2Inv6PolicyExtension implements ServiceExtension {

    // edc default vocab (https://w3id.org/edc/v0.0.1/ns/) + "pilot08Member" expands to this IRI in mgmt-API policies
    static final String MEMBER = "https://w3id.org/edc/v0.0.1/ns/pilot08Member";
    static final String USE = "use";
    static final String USE_IRI = "http://www.w3.org/ns/odrl/2/use";
    static final String MUT_UNBIND = "pilot08.kc2.mutation.inv6.unbind-negotiation";

    @Inject
    private PolicyEngine policyEngine;
    @Inject
    private RuleBindingRegistry ruleBindingRegistry;

    @Override
    public String name() {
        return "Pilot08 KC2 INV-6 contract-policy-at-negotiation probe (test fixture)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        monitor = context.getMonitor();
        var unbindNegotiation = Boolean.parseBoolean(context.getSetting(MUT_UNBIND, "false"));

        // catalog scope: always bound (consistent catalogue filtering; INV-6 is about the negotiation decision)
        bindScope(CatalogPolicyContext.CATALOG_SCOPE);
        policyEngine.registerFunction(CatalogPolicyContext.class, Permission.class, MEMBER, memberFn("catalog"));
        monitor.info("[pilot08-kc2][INV-6] registered member fn in CATALOG scope (" + CatalogPolicyContext.CATALOG_SCOPE + ")");

        if (unbindNegotiation) {
            monitor.warning("[pilot08-kc2][INV-6] MUTATION: negotiation-scope member constraint UNBOUND (test-only)");
            return;
        }
        // negotiation scope: the behaviour under test — bind + register so a deny usage policy is enforced at negotiation
        bindScope(ContractNegotiationPolicyContext.NEGOTIATION_SCOPE);
        policyEngine.registerFunction(ContractNegotiationPolicyContext.class, Permission.class, MEMBER, memberFn("negotiation"));
        monitor.info("[pilot08-kc2][INV-6] registered member fn in NEGOTIATION scope (" + ContractNegotiationPolicyContext.NEGOTIATION_SCOPE + ")");
    }

    // bind the action (both the odrl short form and full IRI) and the member left-operand so the policy engine's
    // scope filter keeps the permission + evaluates the constraint. Belt-and-braces across EDC term representations.
    private void bindScope(String scope) {
        ruleBindingRegistry.bind(USE, scope);
        ruleBindingRegistry.bind(USE_IRI, scope);
        ruleBindingRegistry.bind(MEMBER, scope);
    }

    private Monitor monitor;

    // allow iff the authenticated counterparty's identity (DID) matches the constraint's right value
    private <C extends ParticipantAgentPolicyContext> AtomicConstraintRuleFunction<Permission, C> memberFn(String where) {
        return (Operator op, Object right, Permission rule, C ctx) -> {
            var identity = ctx.participantAgent() == null ? null : ctx.participantAgent().getIdentity();
            var want = right == null ? null : right.toString();
            var equal = identity != null && identity.equals(want);
            var ok = op == Operator.NEQ ? !equal : equal;   // EQ (default) -> equal; NEQ -> not equal
            monitor.info("[pilot08-kc2][INV-6] EVAL scope=" + where + " identity='" + identity + "' want='" + want + "' op=" + op + " -> " + ok);
            if (!ok) {
                ctx.reportProblem("[pilot08-kc2][INV-6] member constraint not satisfied for '" + identity + "'");
            }
            return ok;
        };
    }
}
