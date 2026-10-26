package pilot08kc2;

import com.nimbusds.jose.jwk.Curve;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jose.jwk.gen.ECKeyGenerator;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Pilot 08 KC2 one-shot generator (local testbed only). Emits, for an issuer identity:
 *   <out>/<name>.priv.jwk   — the EC P-256 private JWK (signing key; gitignored, never committed)
 *   <out>/<name>.did.json   — a resolvable did:web document exposing the matching public JWK
 * so a trusted issuer (and a separate untrusted issuer J for the INV-5 negative control) each have a
 * real, resolvable DID whose key signs MembershipCredentials (Route I, D13).
 *
 * Usage: java -cp <identityhub-all.jar> pilot08kc2.GenIssuer <outDir> <name> <issuerDid> <keyId>
 */
public final class GenIssuer {
    public static void main(String[] args) throws Exception {
        if (args.length < 4) { System.err.println("usage: GenIssuer <outDir> <name> <issuerDid> <keyId>"); System.exit(2); }
        var outDir = Path.of(args[0]); var name = args[1]; var did = args[2]; var keyId = args[3];
        Files.createDirectories(outDir);

        var ec = new ECKeyGenerator(Curve.P_256).keyID(keyId).generate();
        var pub = ec.toPublicJWK().toJSONObject();   // public JWK (crv,kty,x,y,kid) — no "d"
        var priv = ec.toJSONString();                // full private JWK (has "d") — gitignored

        Files.writeString(outDir.resolve(name + ".priv.jwk"), priv);

        // Minimal did:web document; JsonWebKey2020 verification method with the public JWK.
        var vmId = did + "#" + keyId;
        var jwk = toJson(pub);
        var didDoc = "{\n" +
                "  \"@context\": [\"https://www.w3.org/ns/did/v1\", \"https://w3id.org/security/suites/jws-2020/v1\"],\n" +
                "  \"id\": \"" + did + "\",\n" +
                "  \"verificationMethod\": [{\n" +
                "    \"id\": \"" + vmId + "\",\n" +
                "    \"type\": \"JsonWebKey2020\",\n" +
                "    \"controller\": \"" + did + "\",\n" +
                "    \"publicKeyJwk\": " + jwk + "\n" +
                "  }],\n" +
                "  \"assertionMethod\": [\"" + vmId + "\"],\n" +
                "  \"authentication\": [\"" + vmId + "\"]\n" +
                "}\n";
        Files.writeString(outDir.resolve(name + ".did.json"), didDoc);
        System.out.println("wrote " + name + ".priv.jwk and " + name + ".did.json for " + did);
    }

    // tiny JSON object serializer for a flat string map (JWK members are all strings here)
    private static String toJson(java.util.Map<String, Object> m) {
        var sb = new StringBuilder("{");
        boolean first = true;
        for (var e : m.entrySet()) {
            if (!first) sb.append(","); first = false;
            sb.append("\"").append(e.getKey()).append("\":\"").append(String.valueOf(e.getValue())).append("\"");
        }
        return sb.append("}").toString();
    }
}
