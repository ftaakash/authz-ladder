// Pilot 08 KC2 — assembles two Eclipse identity runtimes as fat jars from released
// Maven Central BOMs (local testbed only). One jar runs an IdentityHub (embedded STS +
// credential/presentation service + did:web publisher + identity API for seeding); the
// other runs an IssuerService (trusted issuer that issues MembershipCredentials).
// Version pinned to the Tractus-X 0.13.0 connector's bundled EDC (0.17.0). See D10.
//
// Build:  gradle shadowJar -Prole=identityhub   (or -Prole=issuer), inside the pinned
//         gradle container (scripts mirror KC1's 30_build_vanilla.sh).
plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}
repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.17.0"
val role = (project.findProperty("role") as String?) ?: "identityhub"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"

dependencies {
    when (role) {
        "identityhub" -> runtimeOnly(edc("identityhub-bom"))
        "issuer"      -> runtimeOnly(edc("issuerservice-bom"))
        else -> throw GradleException("unknown role=$role (identityhub|issuer)")
    }
}
application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }
tasks.shadowJar {
    mergeServiceFiles()
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-${role}-all.jar")
}
