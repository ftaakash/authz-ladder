package pilot08kc2;

import org.eclipse.edc.identityhub.defaults.EdcScopeToCriterionTransformer;
import org.eclipse.edc.identityhub.spi.transformation.DiscriminatorMappingRegistry;
import org.eclipse.edc.identityhub.spi.transformation.ScopeToCriterionTransformer;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.spi.system.ServiceExtension;

/**
 * Pilot 08 KC2 identity-stack interop adapter (local testbed only).
 *
 * The Tractus-X 0.13.0 connector requests presentations with the scope alias
 * {@code org.eclipse.tractusx.vc.type} (e.g. {@code org.eclipse.tractusx.vc.type:MembershipCredential:read}),
 * whereas vanilla EDC IdentityHub 0.17.0's default {@link EdcScopeToCriterionTransformer} accepts only
 * {@code org.eclipse.dspace.dcp.vc.type}. Tractus-X normally pairs its connector with its own IdentityHub
 * distribution, which accepts the Tractus-X alias. This extension overrides the default transformer
 * (it is {@code @Provider(isDefault = true)}) with one that rewrites the Tractus-X alias to the DCP alias
 * and then delegates to EDC's own transformer unchanged.
 *
 * Scope: this only maps a holder-side presentation QUERY to a credential-store filter. It does not touch
 * the verifier: the provider still validates the returned VP signature, the credential issuer against its
 * trusted-issuer list, and the token claims. Any other alias is passed through and rejected by EDC as before.
 */
public class Kc2TxScopeExtension implements ServiceExtension {

    static final String TX_ALIAS = "org.eclipse.tractusx.vc.type";

    @Inject
    private DiscriminatorMappingRegistry discriminatorMappingRegistry;

    @Override
    public String name() {
        return "Pilot08 KC2 Tractus-X scope alias adapter (test fixture)";
    }

    @Provider
    public ScopeToCriterionTransformer scopeTransformer() {
        var edc = new EdcScopeToCriterionTransformer(discriminatorMappingRegistry);
        return scope -> {
            if (scope != null && scope.regionMatches(true, 0, TX_ALIAS + ":", 0, TX_ALIAS.length() + 1)) {
                scope = EdcScopeToCriterionTransformer.ALIAS_LITERAL + scope.substring(TX_ALIAS.length());
            }
            return edc.transformScope(scope);
        };
    }
}
