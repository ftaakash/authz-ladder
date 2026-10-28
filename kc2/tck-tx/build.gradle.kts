// Pilot 08 KC2 (D14, TCK baseline Option A) — Tractus-X 0.13.0 DSP-TCK connector-under-test, reproduced
// standalone. Upstream (tractusx-edc 0.13.0 edc-tests/e2e/dsp-tck-tests/EdcCompatibilityPostgresTest) runs
// the TCK against an in-process runtime + org.eclipse.edc:tck-extension (at the bundled EDC, 0.17.0) and
// injects four test-only stand-ins via registerServiceMock. This builds a THIN add-on jar = tck-extension
// (non-transitive; its dependencies are already inside the release binary) + a fixture extension re-creating
// those stand-ins. It is run on the classpath next to the release image's own /app/edc-runtime.jar.
plugins { id("com.gradleup.shadow") version "8.3.5"; `java-library` }
repositories { mavenCentral() }
val edc = "0.17.0"; val tx = "0.13.0"
dependencies {
    implementation("org.eclipse.edc:tck-extension:$edc") { isTransitive = false }   // bundled into the thin jar
    compileOnly("org.eclipse.edc:core-spi:$edc")
    compileOnly("org.eclipse.edc:policy-spi:$edc")
    compileOnly("org.eclipse.edc:protocol-spi:$edc")
    compileOnly("org.eclipse.edc:control-plane-core:$edc")
    compileOnly("org.eclipse.tractusx.edc:bdrs-client-spi:$tx")
    compileOnly("org.eclipse.tractusx.edc:bpns-evaluation-spi:$tx")
}
tasks.shadowJar {
    configurations = listOf(project.configurations.runtimeClasspath.get())
    mergeServiceFiles()
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
    archiveFileName.set("pilot08kc2-tck-tx-addon.jar")
}
