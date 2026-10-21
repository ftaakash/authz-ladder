// Pilot 08 — minimal vanilla-EDC connector launcher with iam-mock (local testbed only).
// One runtime per participant (control plane + embedded data plane), mirroring the
// Tractus-X edc-runtime-memory topology but on vanilla Eclipse EDC at a pinned tag.
// Module set taken from the tag's own system-tests/e2e-transfer-test runtimes
// (control-plane + data-plane), plus transfer-data-plane so the CVE-2024-8642
// consumer-pull path is present on the 0.6.x rungs.
//
// Build:  ./gradlew shadowJar -Pedc=0.6.2
// Run:    java -Dedc.fs.config=config.properties -jar build/libs/pilot08-edc-launcher-all.jar

plugins {
    application
    id("com.gradleup.shadow") version "8.3.5"
}

repositories { mavenCentral() }

val edc = (project.findProperty("edc") as String?) ?: "0.6.2"
val isV06 = edc.startsWith("0.6")

fun edc(name: String) = "org.eclipse.edc:$name:$edc"

dependencies {
    // boot + control plane + DSP + management + iam-mock (from e2e control-plane recipe)
    runtimeOnly(edc("boot"))
    runtimeOnly(edc("connector-core"))   // base dependencies (required by BaseRuntime)
    runtimeOnly(edc("token-core"))
    runtimeOnly(edc("control-plane-core"))
    runtimeOnly(edc("dsp"))
    runtimeOnly(edc("http"))
    runtimeOnly(edc("iam-mock"))
    runtimeOnly(edc("api-observability"))
    runtimeOnly(edc("control-plane-api"))
    runtimeOnly(edc("management-api"))
    runtimeOnly(edc("management-api-configuration"))
    runtimeOnly(edc("configuration-filesystem"))
    runtimeOnly(edc("data-plane-selector-core"))
    runtimeOnly(edc("data-plane-selector-api"))
    runtimeOnly(edc("policy-monitor-core"))

    // embedded data plane (from e2e data-plane recipe)
    runtimeOnly(edc("data-plane-core"))
    runtimeOnly(edc("data-plane-http"))
    runtimeOnly(edc("data-plane-http-oauth2"))        // CVE-2024-4536 OAuth2 data-sink path
    runtimeOnly(edc("control-plane-api-client"))
    runtimeOnly(edc("data-plane-signaling-api"))
    runtimeOnly(edc("data-plane-control-api"))

    // CVE-2024-8642 lives here (consumer-pull token validation); present only on 0.6.x
    if (isV06) runtimeOnly(edc("transfer-data-plane"))
}

application {
    mainClass.set("org.eclipse.edc.boot.system.runtime.BaseRuntime")
}

// EDC discovers extensions via Java ServiceLoader. Shadow must MERGE the
// META-INF/services/*ServiceExtension files from every module, or only one
// survives and boot fails with "No base dependencies ... connector-core".
tasks.shadowJar {
    mergeServiceFiles()
}
