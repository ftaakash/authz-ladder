package pilot08kc2ih;

import org.eclipse.edc.identityhub.spi.transformation.ScopeToCriterionTransformer;
import org.eclipse.edc.spi.query.Criterion;
import org.eclipse.edc.spi.result.Result;

import java.util.List;

import static org.eclipse.edc.spi.result.Result.failure;
import static org.eclipse.edc.spi.result.Result.success;

/**
 * Verbatim reproduction of eclipse-edc/IdentityHub v0.17.0 test fixture
 * e2e-tests/tck-tests/presentation/.../tck/TckTransformer.java (commit e78f72ec), the ScopeToCriterionTransformer
 * the upstream DCP-TCK presentation test injects via registerServiceMock. Kept identical so the credential-service
 * scope handling under test matches upstream exactly (alias org.eclipse.dspace.dcp.vc.type; operations
 * read, star, all, write; discriminator context-hash-type). This is an upstream TEST fixture, not pilot logic.
 */
public class TckTransformer implements ScopeToCriterionTransformer {
    public static final String TYPE_OPERAND = "verifiableCredential.credential.type";
    public static final String ALIAS_LITERAL = "org.eclipse.dspace.dcp.vc.type";
    public static final String CONTEXT_OPERAND = "verifiableCredential.credential.context";
    public static final String CONTAINS_OPERATOR = "contains";
    private static final String SCOPE_SEPARATOR = ":";
    private final List<String> allowedOperations = List.of("read", "*", "all", "write");

    @Override
    public Result<List<Criterion>> transformScope(String scope) {
        var tokens = tokenize(scope);
        if (tokens.failed()) {
            return failure("Scope string cannot be converted: %s".formatted(tokens.getFailureDetail()));
        }
        var discriminator = tokens.getContent()[1];
        return convertDiscriminator(discriminator);
    }

    protected Result<String[]> tokenize(String scope) {
        if (scope == null) return failure("Scope was null");
        var firstSeparatorIndex = scope.indexOf(SCOPE_SEPARATOR);
        var lastSeparatorIndex = scope.lastIndexOf(SCOPE_SEPARATOR);
        if (firstSeparatorIndex == -1 || lastSeparatorIndex == -1 || firstSeparatorIndex == lastSeparatorIndex) {
            return failure("Scope string has invalid format.");
        }
        var tokens = new String[3];
        tokens[0] = scope.substring(0, firstSeparatorIndex);
        tokens[1] = scope.substring(firstSeparatorIndex + 1, lastSeparatorIndex);
        tokens[2] = scope.substring(lastSeparatorIndex + 1);
        if (!ALIAS_LITERAL.equalsIgnoreCase(tokens[0])) {
            return failure("Scope alias MUST be %s but was %s".formatted(ALIAS_LITERAL, tokens[0]));
        }
        if (!allowedOperations.contains(tokens[2])) {
            return failure("Invalid scope operation: " + tokens[2]);
        }
        return success(tokens);
    }

    private Result<List<Criterion>> convertDiscriminator(String discriminator) {
        if (discriminator == null) {
            return failure("discriminator was null");
        }
        var lastHashIndex = discriminator.lastIndexOf("#");
        if (lastHashIndex == -1) {
            var typeCriterion = new Criterion(TYPE_OPERAND, CONTAINS_OPERATOR, discriminator);
            return success(List.of(typeCriterion));
        }
        var contextPart = discriminator.substring(0, lastHashIndex);
        var typePart = discriminator.substring(lastHashIndex + 1);
        var contextCriterion = new Criterion(CONTEXT_OPERAND, CONTAINS_OPERATOR, contextPart);
        var typeCriterion = new Criterion(TYPE_OPERAND, CONTAINS_OPERATOR, typePart);
        return success(List.of(contextCriterion, typeCriterion));
    }
}
