// Pilot 08 — minimal vanilla-EDC connector launcher with iam-mock (local testbed only).
// One runtime per participant (control plane + embedded data plane). Each version's module
// set is taken from that tag's own system-tests/e2e-transfer-test runtimes (control-plane +
// data-plane), verified present on Maven Central in env/maven-modules.csv. The 0.6.x and
// 0.9.x module sets differ (0.9.x replaces the classic transfer/data-plane-control modules
// with Dataplane Signaling, EDR and data-plane-iam).
//
// Build:  gradle shadowJar -Pedc=<version>   (run inside the pinned gradle container, see scripts/30_build_vanilla.sh)

plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}

repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.6.2"
val isV06 = edc.startsWith("0.6")

fun edc(name: String) = "org.eclipse.edc:$name:$edc"

dependencies {
    // base + control plane + DSP + management + iam-mock (common to both lines)
    runtimeOnly(edc("boot"))
    runtimeOnly(edc("connector-core"))
    runtimeOnly(edc("token-core"))
    runtimeOnly(edc("control-plane-core"))
    runtimeOnly(edc("dsp"))
    runtimeOnly(edc("http"))
    runtimeOnly(edc("iam-mock"))
    runtimeOnly(edc("api-observability"))
    runtimeOnly(edc("configuration-filesystem"))
    runtimeOnly(edc("control-plane-api"))
    runtimeOnly(edc("control-plane-api-client"))
    runtimeOnly(edc("management-api"))
    runtimeOnly(edc("management-api-configuration"))
    runtimeOnly(edc("data-plane-selector-core"))
    runtimeOnly(edc("data-plane-selector-api"))
    runtimeOnly(edc("provision-http"))
    runtimeOnly(edc("transfer-pull-http-dynamic-receiver"))
    runtimeOnly(edc("policy-monitor-core"))
    runtimeOnly(edc("data-plane-core"))
    runtimeOnly(edc("data-plane-http"))
    runtimeOnly(edc("data-plane-http-oauth2"))        // CVE-2024-4536 OAuth2 data-sink path
    runtimeOnly(edc("data-plane-signaling-api"))

    if (isV06) {
        // classic transfer + data-plane control (removed at 0.9.x)
        runtimeOnly(edc("data-plane-control-api"))
        runtimeOnly(edc("transfer-data-plane"))       // CVE-2024-8642 lives here (0.6.x only; affected-side evidence)
    } else {
        // 0.9.x: Dataplane Signaling + EDR + data-plane IAM, control-api split out
        runtimeOnly(edc("control-api-configuration"))
        runtimeOnly(edc("edr-store-core"))
        runtimeOnly(edc("edr-cache-api"))
        runtimeOnly(edc("edr-store-receiver"))
        runtimeOnly(edc("callback-event-dispatcher"))
        runtimeOnly(edc("callback-http-dispatcher"))
        runtimeOnly(edc("transfer-data-plane-signaling"))
        runtimeOnly(edc("data-plane-selector-control-api"))
        runtimeOnly(edc("data-plane-self-registration"))
        runtimeOnly(edc("data-plane-iam"))
        runtimeOnly(edc("data-plane-public-api-v2"))
    }
}

application {
    mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime")
}

// EDC discovers extensions via Java ServiceLoader. Shadow must MERGE the
// META-INF/services/*ServiceExtension files from every module, or only one
// survives and boot fails with "No base dependencies ... connector-core".
// Reproducible flags so a rebuild of the same version hashes identically.
tasks.shadowJar {
    mergeServiceFiles()
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}
