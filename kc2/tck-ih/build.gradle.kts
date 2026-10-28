// Pilot 08 KC2 (U5, DCP-TCK baseline on the identity stack) — a DCP-TCK IdentityHub runtime reproducing
// upstream's eclipse-edc/IdentityHub v0.17.0 e2e-tests/tck-tests/presentation (DcpPresentationFlowWithDockerTest).
// Upstream boots identityhub-bom in-process and registerServiceMock's two services (ScopeToCriterionTransformer =
// TckTransformer, RevocationServiceRegistry = Mockito mock), then seeds a holder participant + HolderCredentialRequest
// and runs eclipsedataspacetck/dcp-tck-runtime (test package …verification.presentation.cs).
//
// This launcher = identityhub-bom (0.17.0, the KC2 identity-stack version, D12) + a fixture extension that re-creates
// the TckTransformer and the holder seeding as real @Providers / a boot step. DEVIATION (stated): the
// RevocationServiceRegistry is NOT mocked — the real one is kept (no deterministic override handle, and mocking it
// would need test-framework code at runtime). Any TCK failure that traces to revocation checking is therefore marked
// against this deviation, not the connector.
plugins { application; id("com.gradleup.shadow") version "8.3.5" }
repositories { mavenCentral() }
val edc = "0.17.0"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"
dependencies {
    runtimeOnly(edc("identityhub-bom"))
    runtimeOnly(edc("aes-encryption"))
    compileOnly(edc("core-spi"))
    compileOnly(edc("participant-context-spi"))
    compileOnly(edc("verifiable-credential-spi"))
    compileOnly(edc("verifiable-credentials-spi"))
    compileOnly(edc("holder-credential-request-spi"))
    compileOnly(edc("identity-hub-spi"))
    compileOnly(edc("identity-did-spi"))
    compileOnly("com.nimbusds:nimbus-jose-jwt:10.8")
}
application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }
tasks.shadowJar {
    mergeServiceFiles(); isPreserveFileTimestamps = false; isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-tck-ih-all.jar")
}
