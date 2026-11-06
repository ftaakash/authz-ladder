// Pilot 08 KC2 — Tractus-X labelled MUTATION add-on (local testbed only). A THIN jar placed on the release
// connector's classpath ONLY in a mutation cell (docker run ... --entrypoint java ... -cp
// /app/edc-runtime.jar:/work/addon.jar org.eclipse.edc.boot.system.runtime.BaseRuntime), NEVER on a
// current-release (verdict) run. It hosts the INVARIANTS amendment-A2 mutation(s): a labelled, test-only
// break of one specific authorization check, encoding the spec-rule negation and revealing no finding.
// Each mutation is gated by a default-off system property, so the same jar is INERT unless a cell turns its
// mutation on explicitly (mirrors the vanilla fixture's toggle). Compiled against the EDC SPI that Tractus-X
// 0.13.0 bundles (0.17.0); every SPI class is provided at runtime by /app/edc-runtime.jar, and all deps are
// compileOnly, so shadowJar bundles nothing — the jar is just pilot classes + META-INF/services.
// Build:  gradle shadowJar -Pedc=0.17.0   (inside the pinned gradle container; see kc2/scripts/11_build_vanilla.sh ROLE=addon-tx)
plugins { id("com.gradleup.shadow") version "8.3.5"; `java-library` }
repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.17.0"
fun edc(m: String) = "org.eclipse.edc:$m:$edc"

dependencies {
    // All compileOnly: the classes are provided at runtime by the release edc-runtime.jar on the classpath
    // (same module names the vanilla INV-6 fixture compiles against).
    compileOnly(edc("core-spi"))
    compileOnly(edc("policy-engine-spi"))
    compileOnly(edc("control-plane-spi"))
    compileOnly(edc("participant-spi"))
    // INV-4 mutation delegates to the release's own ContractValidationServiceImpl (+ PolicyEquality); these
    // live in the control-plane-contract core module, provided at runtime by /app/edc-runtime.jar.
    compileOnly(edc("control-plane-contract"))
    // INV-4 consumer fixture wraps the release's own InMemoryContractNegotiationStore (control-plane-core),
    // whose superclass InMemoryStatefulEntityStore lives in store-lib.
    compileOnly(edc("control-plane-core"))
    compileOnly(edc("store-lib"))
}

tasks.shadowJar {
    configurations = listOf(project.configurations.runtimeClasspath.get())
    mergeServiceFiles()
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-tractusx-addon.jar")
}
