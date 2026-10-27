// Pilot 08 KC2 — the second KC2 target: vanilla Eclipse EDC (control plane + embedded data plane) with
// DCP, assembled from the released Maven Central BOMs pinned in kc2/pins.tsv (controlplane-dcp-bom +
// dataplane-base-bom at 0.18.1). It authenticates against the shared 0.17.0 identity stack (D12).
// The only pilot code is a test-fixture vault seeder (vanilla InMemoryVault has no seeding mechanism;
// Tractus-X ships its own VaultSeedExtension for the same purpose).
//
// Build:  gradle shadowJar -Pedc=0.18.1   (inside the pinned gradle container; see kc2/scripts/11_build_vanilla.sh)
plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}
repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.18.1"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"

dependencies {
    runtimeOnly(edc("controlplane-dcp-bom"))
    runtimeOnly(edc("dataplane-base-bom"))
    compileOnly(edc("core-spi"))   // vault-seed fixture (classes provided at runtime by the BOMs)
}
application { mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime") }
tasks.shadowJar {
    mergeServiceFiles()
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-vanilla-all.jar")
}
