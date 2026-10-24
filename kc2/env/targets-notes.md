# KC2 targets — provenance notes

- **Tractus-X `edc-runtime-memory:0.13.0` bundled EDC version.** The runtime fat jar
  (`/app/edc-runtime.jar`, sha256 in `targets.csv`) carries **no** `META-INF/maven/org.eclipse.edc/*/pom.properties`
  (checked 2026-10-24: only `.class` entries under `org/eclipse/edc/…`, no EDC pom.properties). So the bundled EDC
  version is **not derivable from the binary**; it is read from the tag's `gradle/libs.versions.toml` (`edc = "0.17.0"`)
  and is recorded as such — UNVERIFIED against the binary (review 11, Q7).
- Vanilla EDC target (0.18.1) is the release coordinate itself; its jar is assembled in a later phase.
