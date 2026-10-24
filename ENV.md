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

## KC2 targets — current releases (pinned 2026-10-24)

KC2 tests the **latest stable** release of each line (GitHub releases API, 2026-10-24; pre-releases
such as EDC `v1.0.0-RC5` and `0.14.0-SNAPSHOT` images excluded). Pins: `kc2/pins.tsv`; pull + jar
evidence: `kc2/scripts/00_pull_targets.sh` → `kc2/env/targets.csv`. KC2 runs on its own networks and
containers (prefix `pilot08k2-`), separate from `pilot08_dsp` and `pilot08v`.

| Target | Version | Bundled EDC | Pin | Source commit |
|---|---|---|---|---|
| Tractus-X EDC `tractusx/edc-runtime-memory` | 0.13.0 (2026-08-27) | 0.17.0 (from tag `gradle/libs.versions.toml`; not re-verified in the binary) | `sha256:bc54335da7b30985154d8d9285a1646e022c97a3cdea6eb1f81b9defaff26ec4` (index digest; amd64 167 MB) | tag `0.13.0` = `964d33d7ed942369f624aacbc45037a1f79fc7be` |
| Vanilla Eclipse EDC (Maven Central) | 0.18.1 (2026-09-25) | 0.18.1 | BOMs `controlplane-dcp-bom` pom sha1 `0cff29e5…`, `dataplane-base-bom` pom sha1 `9afd6ad1…` (full in `kc2/pins.tsv`); fat-jar sha256 recorded when assembled | tag `v0.18.1` = `3a22ff4aa90213a564309b5a05851e6d7f27f9ff` |

Notes:
- The latest Tractus-X release bundles EDC **0.17.0**, one minor behind vanilla 0.18.1, so the two targets are not the same EDC code.
- Both repos carry DSP TCK test modules at these tags (Tractus-X `edc-tests/e2e/dsp-tck-tests`, dsp-tck 1.0.0; EDC `system-tests/tck`). That the **released builds pass the DSP TCK** is taken from upstream CI and is **UNVERIFIED** locally.
- Tractus-X 0.13.0 jar (`/app/edc-runtime.jar`, sha256 in `kc2/env/targets.csv`): no `iam-mock`; DCP via `org/eclipse/edc/iam/decentralizedclaims` (90 entries), a remote STS (`RemoteSecureTokenService`) and the Tractus-X DIV STS (`DivSecureTokenService`, successor of the DIM STS), BDRS client (`BdrsClientImpl`), `MembershipCredential` constraint. So KC2 needs the local identity stack (option A).

| Download | Source | Digest / version | Size | Date |
|---|---|---|---|---|
| `tractusx/edc-runtime-memory:0.13.0` (local tag `pilot08k2/edc-runtime-memory:0.13.0`) | `docker.io/tractusx` | `sha256:bc54335d…26ec4` | 167 MB | 2026-10-24 |

### KC2 identity stack — versions & compatibility (phase 2)

Assembled per D11. Jars/scripts tracked under `kc2/`; jar sha256 in `kc2/env/identity-jars.csv`
(clean commit `77b124e`), dependency verification in `kc2/env/gradle-verification.csv` (568 artifacts,
sha1 cross-checked against Maven Central 568/568, 0 mismatch, strict builds + tamper control).

| Component | Version | Bundled EDC | vs. Tractus-X 0.13.0 connector (EDC 0.17.0) |
|---|---|---|---|
| IdentityHub (`identityhub-bom`) | 0.17.0 | 0.17.0 | **exact match** |
| IssuerService (`issuerservice-bom`) | 0.17.0 | 0.17.0 | **exact match** |
| BDRS (`tractusx/bdrs-server-memory`) | 0.6.0 | 0.16.0 | one EDC minor behind — DID resolution + membership-VP exchange only; compatibility to be shown by the smoke, UNVERIFIED |

**Compatibility observations (to confirm at the handshake phase):**
- The identity stack matches the **Tractus-X 0.13.0** target's bundled EDC exactly (0.17.0). Good for that target.
- The **vanilla EDC 0.18.1** target is one minor **ahead** of the 0.17.0 identity stack. The DCP wire protocol (presentation/STS) is versioned by the DCP spec, not the EDC build, so 0.17.0↔0.18.1 may interoperate — but this is **UNVERIFIED**; if the smoke fails, a second identity stack pinned at 0.18.1 is the fallback (one-line change to `-Pedc`).
- IdentityHub has **no superuser/first-participant bootstrap** in the BOM (checked in source + the built jar): a `did:web` document only resolves once a participant context + keypair is created via the identity API. So demonstrating did:web resolution requires minimal participant seeding — see the phase-2 checkpoint note.

### KC2 phase-2 milestone — identity bring-up and did:web resolution

`kc2/scripts/30_up_identity.sh` brings up two IdentityHubs (provider-ih, consumer-ih), one IssuerService
and one BDRS on the internal network, and records `kc2/env/identity-smoke.csv`. Read the CSV as **two
groups**, not a single "cross-resolution" tally:
- **readiness (4):** provider-ih and consumer-ih each seeded + ready, issuer booted, BDRS booted.
- **crossres (8):** the two DID documents are **served on the internal network and resolved host-to-host
  between the IdentityHubs** — `curl` exec'd *inside* consumer-ih fetches the provider DID (200) and
  *inside* provider-ih fetches the consumer DID (200); each document's `id` equals its configured DID,
  carries an **Ed25519** public key, and contains **no private-key member** (`publicKeyJwk.d` absent).

This is did:web document resolution between the services over the isolated network; it is **not** a DCP
token exchange or catalogue request (those are the deferred handshake). Every row carries the IdentityHub
jar sha256 and a clean commit; the script refuses to run a jar not recorded at a clean commit.

### KC2 testbed network

`pilot08k2_dsp` is `internal: true`. Isolation in `kc2/env/net-isolation.csv` has a `services_up` column:
the `identity-stack` rows are measured with all four identity services up (not just the peer), and add an
egress probe **exec'd from inside an IdentityHub container** (IP `1.1.1.1` and DNS both BLOCKED) with the
in-net peer reachable from that same container as the positive control; internal flag true; 0 host ports.
Container/network prefix `pilot08k2-` / `pilot08k2_`, separate from `pilot08_dsp` and `pilot08v`.
