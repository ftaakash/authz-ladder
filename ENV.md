# ENV — pinned testbed (pilot 08)

Pinned 2026-10-21 at repo commit `3d6629f`. Digests come from Docker Hub registry manifests
(`docker-content-digest` header, multi-arch index digest); sizes are compressed amd64 sizes
from the Docker Hub tags API. Images are always pulled **by digest** (`repo@sha256:…`), never by tag.

## Route actually used: A (prebuilt images) = Tractus-X EDC

Eclipse publishes **no** prebuilt images for vanilla EDC Connector releases (Docker Hub namespaces
`eclipse-edc`, `eclipseedc`, `eclipsedataspacecomponents`: 0 repos; GHCR only has recent MVD
snapshot images tagged by commit SHA). Prebuilt runnable connectors exist only as **Tractus-X EDC**
(`docker.io/tractusx/*`), a distribution that bundles EDC. So the Route A ladder is a Tractus-X
ladder, and each rung's bundled EDC version is read from that tag's `gradle/libs.versions.toml`.

### Primary images: `tractusx/edc-runtime-memory` (control plane + data plane, in-memory stores)

| Rung | Tractus-X tag | Bundled EDC | Digest | Size |
|---|---|---|---|---|
| R1 | 0.7.0 | 0.6.1 | `sha256:c160bf5bfacb1e2858e6417445444994914197d4e5f209ea7021ed38d606e420` | 240 MB |
| R2 | 0.7.1 | 0.6.3 | `sha256:15c8bf83f0dd881bbedb814a487ae1d8cd6c4744245b4ca550a32c1d8d9f2bde` | 240 MB |
| R3 | 0.7.5 | 0.7.2 | `sha256:30c4e23e04de8e505ace1449b9370ffd7806ad84ba7a3285c4e6a8feb3443a88` | 241 MB |
| R4 | 0.7.6 | 0.7.2 (+ `dataset-bugfix`) | `sha256:0dd67dee6be99a5d2e1a7cce02d579791a3398f7c231a07c17bf83fb4b2ae0fa` | 241 MB |
| R5 | 0.8.0 | 0.10.1 | `sha256:38a4b219d2cc770e1d0635bccaffaaa823efb7b20d2ea3471544d7a9047183ac` | 147 MB |

Pull total ≈ 1.1 GB compressed.

### Pinned but not pulled (only if the in-memory runtime proves insufficient)

| Image | Digest | Size |
|---|---|---|
| `tractusx/edc-controlplane-postgresql-hashicorp-vault:0.7.0` | `sha256:c79c8709c6d7e8ae07e87ec9f9ab66699d4937d46e936658c9fd0bffcba75def` | 213 MB |
| `tractusx/edc-controlplane-postgresql-hashicorp-vault:0.7.1` | `sha256:6ef6a72f348f7217a5b0408ce794e03adf4a38c6f1c34f62753115abc5b1c076` | 213 MB |
| `tractusx/edc-controlplane-postgresql-hashicorp-vault:0.7.7` | `sha256:3c176ccf56013ac4eca3db4b9e984ee90f9f718dd0627178d4be509869a1b01d` | 239 MB |
| `tractusx/edc-controlplane-postgresql-hashicorp-vault:0.8.0` | `sha256:e35189cbda373e3cb72744e14c93852294795a9a840b6408ff53ce027d7418be` | 138 MB |
| `tractusx/edc-dataplane-hashicorp-vault:0.7.0` | `sha256:419ea14e9c7dd48e6cf8421c16e22773085ac8f8289ca03ae7ef6ed2ffd46292` | 257 MB |
| `tractusx/edc-dataplane-hashicorp-vault:0.7.1` | `sha256:6f99a9222e03e97a8fa0a338b3d8e2548042b6e4929e75dba2489e21ae9ecb12` | 257 MB |
| `tractusx/edc-dataplane-hashicorp-vault:0.7.7` | `sha256:ffa53dfc1445ed725cc392d933897c5ec4917ecf5aa70ca2cff8ed19f60ce709` | 258 MB |
| `tractusx/edc-dataplane-hashicorp-vault:0.8.0` | `sha256:7690b28e06d28e04c30c3419f824ca1f6a82f8eeeac0333ec2fffadd6277b7fd` | 148 MB |
| `tractusx/edc-runtime-memory:0.7.7` | `sha256:90b94f0235a917ae6f42221ee2468776094b4e70e66c26e328bfb74444c8bad5` | 241 MB |
| `library/postgres:16.4-alpine` | `sha256:5660c2cbfea50c7a9127d17dc4e48543eedd3d7a41a595a2dfa572471e37e64c` | — |
| `hashicorp/vault:1.17.6` | `sha256:74a4ab138ab5d64725e89cd9a9c73f7040c7fe49e98b71697b275ca9a69919df` | — |

## Host toolchain

| Tool | Version | Note |
|---|---|---|
| Docker / Compose | 29.8.2 / v5.5.1 | |
| JDK | Temurin 21.0.9+10 LTS | not needed for Route A (images carry their own JRE) |
| Git | 2.53.0.windows.1 | |
| curl | 8.18.0 | |
| jq | 1.7.1 | installed at `C:/Users/Administrator/tools/jq/jq.exe`; sha256 `7451fbbf37feffb9bf262bd97c54f0da558c63f0748e64152dd87b0a07b6d6ab` matches upstream `sha256sum.txt`; harness = bash + curl + jq (user-approved 2026-10-21) |
| Python | not installed | not used |

## KC1 vanilla-EDC build (D5) — downloads log

KC1's SUT is a vanilla Eclipse EDC + `iam-mock` connector, assembled from released Maven Central
jars at each ladder tag (not a git source build — see D5/D6). The launcher sources are tracked in
`testbed/launcher/`; the build runs inside a pinned gradle container because the host JVM reports no
loopback interface (so host-side gradle fails its daemon handshake). Build has egress; runtime stays internal.

| Download | Source | Digest / version | Size | Date |
|---|---|---|---|---|
| gradle build image `gradle:8.10-jdk21` | `docker.io/library/gradle` | `sha256:963d59f7f22767da4efbcf46b661361b61af5fb88b0309da1071c4234c647eba` | 1182 MB | 2026-10-21 |
| Gradle 8.10 distribution | services.gradle.org | bundled in the gradle image | — | 2026-10-21 |
| shadow plugin `com.gradleup.shadow:8.3.5` | Gradle Plugin Portal | 8.3.5 | small | 2026-10-21 (source approved by user, D6 / SCOPE standing approvals) |
| EDC module jars (per `env/maven-modules.csv`) | Maven Central (`repo1.maven.org`) | at tags 0.6.2/0.6.3/0.9.0/0.9.1 | ~0.3–0.8 GB | 2026-10-21 |
| `eclipse-edc/Connector` clone @ v0.6.2 | github.com | tag v0.6.2 = `f58c71ab1d5638fb1d226b592aca202a829e7761` (recipe reference, not under test) | shallow | 2026-10-21 |
| `eclipse-edc/Connector` clone @ v0.9.1 | github.com | tag v0.9.1 = `1bd6e683e6304f7e34e0d161cd750424dc2d4dae` (recipe reference, not under test) | shallow | 2026-10-21 |
| `eclipse-edc/Samples` clone (pinned) | github.com | `199eda08057963126f2119a75893439821fe04bb` (recipe reference only; **not** referenced by the launcher build — SUT is assembled from Maven Central jars) | shallow | 2026-10-21 |

Fat jar per version: `testbed/launcher/build/libs/pilot08-edc-launcher-all.jar`; per-version sha256 recorded in `env/vanilla-jars.csv` (append-only, keyed by version+sha+commit).

### Dependency verification (D1 / D8)

Gradle dependency verification is enabled: `testbed/launcher/gradle/verification-metadata.xml`
(tracked) pins **sha1+sha256** for every resolved dependency (1416 artifacts across the four
rungs + the shadow plugin). Builds via `scripts/30_build_vanilla.sh` are strict — a changed or
missing artifact fails the build. This is **not** trust-on-first-use: `scripts/32_gradle_verify.sh`
cross-checks every recorded sha1 against the **publisher's own `.sha1`** and enforces + tamper-tests:

| check | result |
|---|---|
| artifacts recorded (sha1+sha256) | 1416 |
| sha1 cross-checked against publisher | 1416 / 1416, **0 mismatch, 0 missing** |
| strict rebuild (no `--write`) all 4 rungs | pass |
| negative control (flip one sha256 in a copy → build must fail) | detected |

Cross-check sources (fetched `.sha1` only, inside the build container): `repo1.maven.org`
(Eclipse EDC artifacts) and `plugins.gradle.org/m2` (the shadow plugin + its marker pom — the
Plugin Portal hosts a different marker pom than Central at the same coordinates, so each artifact
is accepted iff its recorded sha1 matches the source Gradle actually resolved it from). ~1416–2832
`.sha1` fetches, 2026-10-23. Evidence: `env/gradle-verification.csv`.

**Checksum-only.** PGP signature verification is intentionally skipped: it needs keyserver
downloads, a new (un-approved) source. SCOPE's "dependencies checksum-verified" is satisfied by
the sha1+sha256 pinning cross-checked against the publishers above.

## Network

The testbed runs on a dedicated **internal** Docker network (`dsp`, `internal: true`): no gateway
to the host or internet, so Docker publishes **no** container ports to the host. Egress is blocked
and verified in `env/net-isolation.csv` (IP and DNS probes BLOCKED). The harness runs from a driver
container joined to the network and reaches connectors by service name; nothing is exposed off-box.

### Driver image

| Image | Source | Digest | Size | Date |
|---|---|---|---|---|
| `pilot08/curl:8.11.1` (local retag of `curlimages/curl:8.11.1`) | `docker.io/curlimages/curl` | `sha256:c1fe1679c34d9784c1b0d1e5f62ac0a79fca01fb6377cdd33e90473c6f9f9a69` | 32 MB | 2026-10-21 |

Pulled by digest and retagged by `scripts/02_pull_driver.sh` (same pattern as the rung pulls).

## Pull verification (2026-10-21)

All five primary images pulled by digest; `docker image inspect` RepoDigests match the pinned digests
(log: `results/logs/pull.log`). Local tags `pilot08/edc-runtime-memory:<tx-tag>`. Uncompressed sizes:
638 / 638 / 640 / 641 / 436 MB. Runtime jar: `/app/edc-controlplane.jar` (0.7.x), `/app/edc-runtime.jar` (0.8.0).

Class-level check of each runtime jar (`jar tf`). Reproduce with `scripts/00_pull_images.sh` then
`scripts/01_verify_images.sh`; the authoritative copy is `env/image-check.csv` (commit `2cdd4ee`):

| Rung | classes | `DatasetResolverImpl` | `DatasetFixExtension` | `ConsumerPullTransferTokenValidation*` | dpf-oauth2 classes |
|---|---|---|---|---|---|
| 0.7.0 | 57823 | 1 | 0 | 0 | 6 |
| 0.7.1 | 57725 | 1 | 0 | 0 | 6 |
| 0.7.5 | 58258 | 1 | 0 | 0 | 6 |
| 0.7.6 | 58258 | 1 | 1 | 0 | 6 |
| 0.8.0 | 37719 | 1 | 0 | 0 | 6 |

The fat jars carry no `META-INF/maven/org.eclipse.edc/*/pom.properties`, so the bundled EDC version is taken
from each tag's `gradle/libs.versions.toml` (not re-verified from the binary).
