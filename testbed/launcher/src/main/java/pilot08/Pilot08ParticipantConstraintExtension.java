package pilot08;

import org.eclipse.edc.policy.engine.spi.AtomicConstraintFunction;
import org.eclipse.edc.policy.engine.spi.PolicyContext;
import org.eclipse.edc.policy.engine.spi.PolicyEngine;
import org.eclipse.edc.policy.engine.spi.RuleBindingRegistry;
import org.eclipse.edc.policy.model.Operator;
import org.eclipse.edc.policy.model.Permission;
import org.eclipse.edc.spi.agent.ParticipantAgent;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

/**
 * Pilot 08 test fixture (F1), not an EDC feature. Vanilla EDC binds no constraint
 * function in the catalog scope, so an "admit X / deny Y" policy admits everyone
 * (ScopeFilter silently drops constraints on unbound left operands). This fixture
 * binds ONE atomic constraint, "pilot08:participant" == &lt;counterparty id&gt;, in the
 * catalog and contract-negotiation scopes, keyed on the iam-mock client_id claim.
 * It lets the testbed build a policy that actually hides a dataset from a given
 * counterparty in the full catalog — the precondition the CVE-2024-9202 single-
 * dataset-bypass test needs in order to FAIL on the affected version.
 *
 * The API (AtomicConstraintFunction, PolicyEngine, RuleBindingRegistry, scope
 * "request.catalog", ParticipantAgent claims) is identical across EDC 0.6.x and
 * 0.9.x, so one source compiles for every rung.
 */
public class Pilot08ParticipantConstraintExtension implements ServiceExtension {

    static final String KEY = "pilot08:participant";
    static final String CATALOG_SCOPE = "request.catalog";
    static final String NEGOTIATION_SCOPE = "contract.negotiation";

    @Override
    public String name() {
        return "Pilot08 participant constraint (test fixture)";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var bindings = context.getService(RuleBindingRegistry.class);
        var policyEngine = context.getService(PolicyEngine.class);
        var fn = new ParticipantConstraint();
        for (var scope : new String[]{CATALOG_SCOPE, NEGOTIATION_SCOPE}) {
            bindings.bind("use", scope);   // evaluate ODRL "use" permissions in this scope
            bindings.bind(KEY, scope);     // and the pilot08:participant constraint
            policyEngine.registerFunction(scope, Permission.class, KEY, fn);
        }
        context.getMonitor().info("[pilot08] participant constraint bound in scopes "
                + CATALOG_SCOPE + ", " + NEGOTIATION_SCOPE);
    }

    /** Admits the request iff the counterparty's client_id claim matches the policy's right value. */
    static class ParticipantConstraint implements AtomicConstraintFunction<Permission> {
        @Override
        public boolean evaluate(Operator operator, Object rightValue, Permission rule, PolicyContext context) {
            var agent = context.getContextData(ParticipantAgent.class);
            if (agent == null) {
                return false;
            }
            var who = String.valueOf(agent.getClaims().get("client_id"));
            var want = String.valueOf(rightValue);
            var equal = who.equals(want);
            if (operator == Operator.EQ) {
                return equal;
            }
            if (operator == Operator.NEQ) {
                return !equal;
            }
            return false;
        }
    }
}
