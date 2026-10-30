// Pilot 08 KC2 — the second KC2 target: vanilla Eclipse EDC (control plane + embedded data plane) with
// DCP, assembled from the released Maven Central BOMs pinned in kc2/pins.tsv (controlplane-dcp-bom +
// dataplane-base-bom at 0.18.1). It authenticates against the shared 0.17.0 identity stack (D12).
// The only pilot code is a test-fixture vault seeder (vanilla InMemoryVault has no seeding mechanism;
// Tractus-X ships its own VaultSeedExtension for the same purpose).
//
// role=tck (D14, TCK baseline Option A): the upstream DSP-TCK connector-under-test, reproduced from the
// same release — EDC v0.18.1 `system-tests/tck/dsp-tck-connector-under-test`: controlplane-base-bom minus
// data-plane-signaling(+oauth2), plus org.eclipse.edc:tck-extension (mock identity, scenario seed, guards,
// webhooks) and parsson. No pilot code in this role.
//
// Build:  gradle shadowJar -Pedc=0.18.1 [-Prole=tck]   (inside the pinned gradle container; see kc2/scripts/11_build_vanilla.sh)
plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}
repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.18.1"
val role = (project.findProperty("role") as String?) ?: "single"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"

dependencies {
    when (role) {
        "tck" -> {
            runtimeOnly(edc("controlplane-base-bom")) {
                exclude("org.eclipse.edc", "data-plane-signaling")
                exclude("org.eclipse.edc", "data-plane-signaling-oauth2")
            }
            runtimeOnly(edc("tck-extension"))
            runtimeOnly("org.eclipse.parsson:parsson:1.1.7")   // as upstream (libs.parsson at v0.18.1)
        }
        else -> {
            runtimeOnly(edc("controlplane-dcp-bom"))
            runtimeOnly(edc("dataplane-base-bom"))
            compileOnly(edc("core-spi"))   // vault-seed fixture (classes provided at runtime by the BOMs)
            // INV-6 probe fixture: policy-engine + control-plane policy contexts + participant agent.
            // All already verified via the runtime BOM graph (compileOnly adds no new verified artifact).
            compileOnly(edc("policy-engine-spi"))
            compileOnly(edc("control-plane-spi"))
            compileOnly(edc("participant-spi"))
        }
    }
}
// The tck role carries no pilot source (upstream runtime only).
sourceSets { main { if (role == "tck") { java { setSrcDirs(emptyList<String>()) }; resources { setSrcDirs(emptyList<String>()) } } } }
application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }
tasks.shadowJar {
    mergeServiceFiles()
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set(if (role == "tck") "pilot08kc2-vanilla-tck-all.jar" else "pilot08kc2-vanilla-all.jar")
}
