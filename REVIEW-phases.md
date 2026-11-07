# Phase review — pilot 08 (read-only, 2026-10-21)

Reviewer: side session of the coordinating session. Read-only, apart from writing this file. Docker was not touched and no build was started or stopped. Nothing was downloaded.

**Sources:**
- Files at HEAD `abd5ec7`, plus the gitignored `build/` workspace.
- Commits `21aeb59..abd5ec7`, scoped to `pilots/08-dsp-authfuzz` and `docs/STATE.md`.
- Sibling note `2026-10-21-pilot08-isolation-and-kc1-blocker.md`.

**Transcripts:** I read excerpts by paging back from the end, not every message.
- `pilot-08-cont`: last about 600 of 884 messages.
- `paper-a-pilot`: last 60 messages.
- `paper-a-pilot-dsp-authfu` (fork): reached only through transcript search.

One turn in `paper-a-pilot` and one in `pilot-08-cont` were withheld by a safety classifier, so their content is unknown. Where a user approval could not be found in what I read, this review says "not traceable" rather than "absent".

**Line references** point at HEAD `abd5ec7`. The launcher file is gitignored and was read from the working tree at about 21:00.

Severity: **H** blocks a valid KC1 result or breaks a SCOPE rule. **M** is evidence or documentation drift that a reviewer of the paper would catch. **L** is hygiene.

---

## Phase 1 — Scope and defensive framing

**Done:**
- `SCOPE.md` (`21aeb59`) set the defensive framing.
- `c05f0dd` restored the standing approvals.
- `2506060` aligned the file with D5.

**OK:**
- Local-only, pass/fail-only, and the "Eclipse security process only" disclosure rule are explicit.
- Candidate findings are kept out of git by the root `.gitignore`.
- No exploit payloads exist anywhere. No results CSV exists yet.
- The defensive framing held in every phase reviewed.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 1.1 | `SCOPE.md:27`, `:72`; `DECISIONS.md:9`; `docs/STATE.md:53` | All four say the KC1 SUT is "vanilla EDC **built from source** at pinned tags". The launcher actually being built (`build/launcher/build.gradle.kts:16-46`) fetches **released `org.eclipse.edc:*` jars from Maven Central**. The `connector-062` clone is used only as a recipe reference. This is a change to a user decision (D5). | M | Record a D5 amendment (or D6) in `DECISIONS.md`: "assembled from Eclipse EDC release artifacts (Maven Central) at version X, with iam-mock". Tell the user, because the `SCOPE.md` wording is theirs to change. Pilot sessions do not edit `SCOPE.md`. |
| 1.2 | `SCOPE.md` "Results CSVs record build version, invariant ID, pass/fail, commit hash only" | This is future work, so nothing to fix yet. The -4536 test, however, needs the provider to send a secret to a token endpoint run by the driver. | L | The assertion must record only whether the provider dereferenced the counterparty-named alias (PASS/FAIL). Never log the secret value or the request body to `results/`. |

## Phase 2 — Step 1, bounding the field (KC4)

**Done:** `field-bound.md` checked DSP TCK v1.0.2, AgentRFC 2603.23801 and mcp-statecheck, and concluded that KC4 does not fire. Caveats were added in `f754c48`.

**OK:**
- The verdict follows from the three reads.
- The caveats are honest: the TCK date comes from the repo-tree read, and the mcp-statecheck identity is presumed.
- Frozen claim and kill conditions are unchanged.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 2.1 | `field-bound.md:28-30`, `:40-44` | KC4 is a pilot-long condition ("before the pilot ends"), but the check ran only once. | L | Add a dated re-check of TCK releases and AgentRFC at pilot exit. It is already listed as a watch item; make it an explicit exit step in `PILOT-REPORT.md`. |
| 2.2 | `3d6629f` | This commit created `ideas/08-dsp-authfuzz/kill-test.md`, which is outside `pilots/`. `docs/STATE.md` already records it as "committed kill-test.md without asking". | L | Already acknowledged. No further action. |

## Phase 3 — Step 2, the Tractus-X testbed (pinning, pulls, image checks, D3/D4)

**Done:**
- Five `edc-runtime-memory` rungs pinned by digest (`ENV.md`, `env/pins.tsv`), pulled by script.
- Class-level jar check in `env/image-check.csv`.
- D3 (Tractus-X instead of the MVD) and D4 (accept 2 of 3) recorded.

**OK:**
- The digests in `pins.tsv` and `ENV.md` agree, and no image is pulled by `latest`.
- The class counts in `image-check.csv` match `ENV.md:117-123`.
- D4 is now marked superseded for KC1 (`DECISIONS.md:8`), and its evidence wording is corrected ("UNVERIFIED on the binary").
- The 1.1 GB of pulls was under the 5 GB threshold.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 3.1 | `VERSIONS.md:59-63`, `:106-109` | "Open items before any download" still mentions the MVD mapping. "Route A can exercise 2 of 3 … (user decision; not started)" is stale after D5. The file has no section for the vanilla ladder as actually built. | M | Add a "D5 vanilla ladder (as built)" section. For each version give: modules, -8642 reachability with its evidence file, and predicted cells. Mark the MVD open items "obsolete (D3/D5)". |
| 3.2 | `ENV.md:46`, `:87` | The header still reads "Route actually used: A". JDK is marked "not needed for Route A", but JDK 21 is now on the KC1 critical path. | M | Retitle the header to "KC2 testbed (Tractus-X, deferred)". Add a "KC1 testbed (vanilla EDC)" section covering JDK, Gradle and dependencies (see 6.2). |
| 3.3 | `DECISIONS.md:7` | D3 is marked "By: Claude, forced by D2". The user was told after the fact; I found no explicit approval. | L | Now superseded for KC1 by D5, which was the user's choice. Note "reported to user 2026-10-21" in D3. |

## Phase 4 — Boot, smoke and network isolation on R1

**Done:**
- The network is `internal: true`, and an in-network driver container is used.
- `env/net-isolation.csv` shows 7/7 and `env/boot-smoke.csv` shows 5/5, both re-run on clean commit `dd66831`.

**OK:**
- Isolation is real. The positive control is present (`05_net_check.sh:18`). `compose.yaml` has no `ports:`.
- `20_up.sh` now polls through the driver.

**REVIEW-testbed.md status:**

| Finding | Status | Evidence / gap |
|---|---|---|
| #1 | fixed | `20_up.sh:12-13` |
| #2 | fixed | `compose.yaml:17-19`, `ENV.md:93-98` |
| #3 | fixed | `PILOT-REPORT.md:14-16`, `:100` (D1–D5) |
| #4 | fixed | `45b786a` |
| #5 | fixed | `DECISIONS.md:8` |
| #6 | partial | `env/iam-mock-check.csv` exists, but SHAs are still "to be captured at clone" even though the v0.6.2 clone exists. See 6.4. |
| #7 | fixed | `env/jar-iatp.txt`; the fakebearer row is in `21_smoke.sh:18`; unarchived observations are marked "not archived" |
| #9 | fixed for R1 | Re-run on clean commit `dd66831` |
| #10 | partial | Positive control added. Egress probes still discard stderr (`05_net_check.sh:22,26`). Only the provider is probed; the driver and consumer are not. |
| #12 | partial | Driver digest is in `ENV.md:104` and `02_pull_driver.sh:6`, but `lib.sh:18` still resolves the mutable tag, and the driver is not in `pins.tsv`. |
| #8, #11, #13, #16, #18 | open | Not claimed as fixed. |

`d4ceab4` labels the iam-mock evidence "#3". In `REVIEW-testbed.md` that item is #6, and #3 is the report index. Both are now covered, but the commit label is wrong.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 4.1 | `testbed/compose.yaml:1-45`, `env/*.csv` | Compose, smoke and isolation are all Tractus-X-specific and R1-only. The KC1 SUT is now the vanilla launcher with two participants (provider and consumer) plus the driver's token endpoint for -4536. | M | Write a vanilla-SUT compose on the same `internal: true` network. Re-run `05_net_check.sh` per ladder version **from every service** (provider, consumer, driver). Keep stderr in the probes, and finish #10, #11 and #13 while doing so. |
| 4.2 | `scripts/lib.sh:10` | The dirty-tree marker uses `git diff HEAD`, which cannot see untracked or gitignored files. The SUT recipe currently lives in gitignored `build/launcher/` (see 6.3), so results could carry a clean commit stamp while the SUT recipe differed. | M | Fixed by 6.3: move the recipe into tracked files. Also fold `git status --porcelain -- .` into the marker. |

## Phase 5 — KC1 identity blocker and the switch to option B (D5)

**Done:**
- Shown that the DSP API needs a valid DCP token (smoke rows for noauth and fakebearer).
- R1 jar shown to have no mock IAM (`env/jar-iatp.txt`).
- Options A/B/C written up. The user chose B (D5, recorded in `bc861b7` and `0aacf3b`).

**OK:**
- The blocker diagnosis is backed by archived evidence.
- The decision was the user's.
- D5's rationale holds: both CVEs concern what an already-authenticated counterparty can do, so a mocked identity layer does not weaken them.
- The KC1 rule is worded identically in `SCOPE.md:48`, `DECISIONS.md:8` and `PILOT-REPORT.md:106-109`.

**Oracle check, using the OSV data recorded in VERSIONS.md:**

| CVE | Predicted cells (0.6.2 / 0.6.3 / 0.9.0 / 0.9.1) | Verdict |
|---|---|---|
| -4536 | F / P / P / P | Sound. `data-plane-http-oauth2` is in the launcher on every rung, so the PASS must be behavioural. |
| -9202 | F / F / F / P | Sound. Same module set at 0.9.0 and 0.9.1. |
| -8642 | F / F / P / P | Weak (see 6.1). |

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 5.1 | Commits outside `pilots/`: `.gitattributes` (`2cdd4ee`), `.gitignore` (`cd1c339`, `48b3929`), `docs/STATE.md` (`bc861b7`, `2506060`) | `SCOPE.md` "Still ask first" covers commits outside `pilots/`. `bc861b7`'s message says "user-approved". For the others, no approval is traceable in the transcript excerpts I read. `2506060` was probably made by the coordinating session; git cannot tell which session made it. | M | From now on, leave `docs/STATE.md` and root files uncommitted until the user says yes in chat. Ask the user to confirm the earlier five commits after the fact. Do not rewrite history. **Resolved 2026-10-21:** the user approved all five after the fact, on condition the work was correct. Content checked: `.gitattributes` (LF for sh/tsv/csv) and `.gitignore` (candidate findings, `*.log`/`*.tmp`, `testbed/.secrets/`) are correct and protective. The `STATE.md` entries are accurate except "built from source" (1.1); fix that in the next STATE entry, not by rewriting. The approval covers these five commits only. |
| 5.2 | `PILOT-REPORT.md:83` | Option B's cost was stated as "source build". What is now being built is a Maven-artifact launcher. | L | Covered by 1.1. |

## Phase 6 — The vanilla EDC build (in progress)

**State observed at about 21:00:**
- **No build is running.** `tasklist` shows no `java.exe`.
- `build/build-062.log` ends in `FAILURE … Unable to establish loopback connection` (Gradle 8.10 daemon handshake). The transcript shows four failed attempts (sandbox on, sandbox off, IPv4 forced, foreground) and an open question about switching to a containerised build.
- **Built so far:** a custom launcher (`build/launcher/`).
- **Cloned so far:** `eclipse-edc/Connector` at v0.6.2 (`f58c71ab1d56…`, shallow) and `eclipse-edc/Samples` at `main` (`199eda08…`, shallow).
- The Gradle 8.10 distribution has been downloaded.

**OK:**
- Approach B was approved by the user ("go with the 4-version vanilla EDC build").
- `iam-mock` is included.
- `data-plane-http-oauth2` is present for -4536.
- Build egress happens on the host in a build step, not on `pilot08_dsp`.
- Clones are gitignored by `pilots/08-dsp-authfuzz/.gitignore`.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| 6.1 | `build/launcher/build.gradle.kts:45-46` (`if (isV06) runtimeOnly(edc("transfer-data-plane"))`), `VERSIONS.md:37` | **The -8642 flip at 0.6.3→0.9.0 is produced by the launcher, not by the fix.** At 0.9.0 the module is left out (it is not published there), so the test PASSes vacuously: there is no endpoint to probe. A FAIL→PASS flip at exactly 0.9.0 would then show module removal, not token-validity checking. That does not meet the admission rule's purpose (the test measures the CVE). If -8642 counts as "rediscovered" on this basis, KC1's 3-CVE margin is illusory. | **H** | (a) Archive which `transfer-data-plane` versions exist on Maven Central (0.5.0 … 0.9.0), and whether fix commit `04899e9` shipped in any release that still has the module, in `env/maven-modules.csv`. (b) If such a release exists, add it as a non-vacuous patched rung for -8642. (c) If none exists, record -8642 as "FAIL on affected shown; patched PASS vacuous (module removed)". **Ask the user** (new D6) whether a vacuous PASS counts toward ≥2 of 3. Until then, plan for KC1 resting on -4536 and -9202 (no margin). |
| 6.2 | `ENV.md` (missing rows), `build/launcher/gradle/wrapper/gradle-wrapper.properties` | `SCOPE.md` "log each one in ENV.md (name, source, size, digest or commit SHA, date)" is **not met** for: the Gradle 8.10 distribution; plugin `com.gradleup.shadow` 8.3.5 (from the **Gradle Plugin Portal**, which is arguably a new source); the Maven Central dependencies; the Connector v0.6.2 clone (`f58c71ab1d5638fb1d226b592aca202a829e7761`); and the Samples clone (`main` @ `199eda08057963126f2119a75893439821fe04bb`, **unpinned**). Samples is not a project under test, and its recipe was discarded as the wrong era. The wrapper has no `distributionSha256Sum`. | **H** | Add a "KC1 build downloads" table to `ENV.md` with every item above (size, SHA, date). Add `distributionSha256Sum` for gradle-8.10-bin. Ask the user once whether plugins.gradle.org is covered by "Gradle dependencies". Either log Samples as a reference clone pinned to `199eda0` or remove it from the workspace. Log every later clone (0.6.3, 0.9.0, 0.9.1) and any builder image when it happens. |
| 6.3 | `.gitignore` (pilot, `build/`); `?? pilots/08-dsp-authfuzz/.gitignore` | The **SUT recipe** (`build/launcher/build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`, wrapper) sits inside gitignored `build/`. The module set that defines what is under test is therefore not in git and not covered by the dirty marker (4.2). The pilot `.gitignore` itself is untracked. | **H** | Move the launcher sources to tracked `testbed/launcher/` and keep only clones and outputs ignored. Commit the pilot `.gitignore` (pre-approved). Generate Gradle dependency verification (`--write-verification-metadata sha256`) or a lockfile per version. Record per-version shadow-jar sha256 in `env/` so each result row ties to an exact binary. |
| 6.4 | `env/iam-mock-check.csv:2-5` | The evidence is a GitHub tree read with "SHA to be captured at clone". The v0.6.2 SHA is now known (`f58c71a…`) and not recorded. The launcher also consumes Maven artifacts, so the relevant check is "`org.eclipse.edc:iam-mock:<v>` is published", not "the source tree has the folder". | M | Add tag→commit SHA for all four tags (`git ls-remote` against the approved source). Add a Maven-artifact column to `env/maven-modules.csv` (see 6.5). |
| 6.5 | Transcript only; not in `env/` | These claims are not archived: "`transfer-data-plane` is published only at 0.6.2 and 0.6.3"; "all other needed modules exist at all four tags"; "iam-mock needs only `edc.mock.region`". The module list for 0.9.x is assumed to be the same as 0.6.x minus one module, but the 0.9.x control-plane/data-plane split (signalling, `control-plane-api-client`, `data-plane-control-api`) may differ. If a module is missing, a rung fails to boot, which looks like a broken rung rather than a PASS/FAIL. | M | Script the Maven metadata check into `env/maven-modules.csv` (module × version → published yes/no, jar sha256). Derive each rung's module list from it. Run the smoke (health, management 401/200, DSP catalog with an iam-mock token = 200) per version before any CVE assertion. |
| 6.6 | Transcript; `build/build-062.log` | The build is blocked: Gradle cannot open a loopback connection, which looks like the sandbox or Windows. The pilot is considering a containerised build. | M | If building in a container: pin the builder image by digest and log it in `ENV.md`. Run it on a **separate** default network, never on `pilot08_dsp`. Use the same pinned JRE base for the runtime images. Tell the user that the build location changed. Do not leave the sandbox disabled for anything other than the build commands. |
| 6.7 | `PILOT-REPORT.md:16`, `:113` | The status row lists KC1 tests for "-4536, -9202" only. Step 3 says -8642 reachability is open, although the session has since checked it (unarchived). | M | Update once 6.1 and 6.5 are archived. State -8642 as "reachable at 0.6.x; patched end vacuous; D6 pending". |
| 6.8 | `VERSIONS.md:21` vs `:102-104` | Line 21 says the -4536 fix is "feature removal … PASS when the endpoint/feature is absent". Line 102 says the module is present on patched builds, so the PASS must be behavioural. The vanilla launcher includes `data-plane-http-oauth2` on every rung. | L | Reconcile: the module is present and the fix disables the consumer-named secret path, so the assertion checks behaviour (the alias is not dereferenced). Write that once in `VERSIONS.md`. |

---

## Prioritised change list

| P | ID | File | Change |
|---|---|---|---|
| 1 | 6.1 | `build/launcher/build.gradle.kts:45-46`, `VERSIONS.md`, `DECISIONS.md` | -8642's patched PASS is vacuous: the launcher drops the module at 0.9.x. Archive Maven metadata for `transfer-data-plane` 0.5.0–0.9.0 and look for a release that still has the module and the fix. Otherwise record it as vacuous and ask the user (D6) whether it counts toward ≥2 of 3. Until then, plan KC1 on -4536 and -9202 with no margin. |
| 2 | 6.2 | `ENV.md`, wrapper properties | Log the Gradle 8.10 distribution, shadow plugin 8.3.5 (Plugin Portal: ask the user whether it is an approved source), Maven dependencies, the Connector clone `f58c71a`, and the Samples clone `199eda0` (unpinned: pin or remove). Add `distributionSha256Sum`. Log each later clone and builder image. |
| 3 | 6.3 | `build/launcher/` → `testbed/launcher/`; pilot `.gitignore` | Track the SUT recipe. Commit the pilot `.gitignore`. Add Gradle dependency verification. Record per-version jar sha256 in `env/`. |
| 4 | 1.1 | `DECISIONS.md` (D5 amendment or D6); tell the user about `SCOPE.md:27,72` and `STATE.md` | "Built from source" is not what happens. Record "assembled from Maven Central release artifacts" (or actually build from source), and let the user change the `SCOPE.md` wording. |
| 5 | 6.5 | new `env/maven-modules.csv` + script | Archive module × version availability. Derive per-rung module lists from it. Run a per-version smoke before any CVE assertion. |
| 6 | 6.6 | build step, `ENV.md` | If you switch to a container build: pin the builder by digest, use a separate network (never `pilot08_dsp`), log it, and tell the user. |
| 7 | 4.1 / 4.2 | new vanilla compose, `05_net_check.sh`, `lib.sh:10` | Write the vanilla-SUT compose on the internal network. Re-run isolation from provider, consumer and driver per version, keeping stderr. Make the dirty marker include untracked files. |
| 8 | 5.1 | `docs/STATE.md`, root files | Do not commit outside `pilots/` without the user's yes in chat. The five earlier commits were approved after the fact on 2026-10-21 (resolved). |
| 9 | 6.4 | `env/iam-mock-check.csv` | Add the commit SHA for each of the four tags, plus Maven-artifact presence. |
| 10 | 3.1 / 3.2 / 6.7 | `VERSIONS.md`, `ENV.md`, `PILOT-REPORT.md` | Add a "D5 vanilla ladder as built" section. Retitle the Tractus-X content as the KC2 testbed. Update the -8642 status. |
| 11 | L items | various | 1.2 (never log secret values), 2.1 (KC4 re-check at exit), 3.3, 6.8, and REVIEW-testbed #8, #11, #13, #16, #18. |

## Verdict

**Defensive scope held in every phase:** no third-party probing, no exploit output, no candidate findings in git. Isolation on R1 is real and evidenced. Most `REVIEW-testbed.md` findings are fixed. #6, #10 and #12 are partial, and #8, #11, #13, #16 and #18 are open.

**The KC1 path has three structural gaps:**
- The -8642 oracle is vacuous at its patched end, and the vacuity comes from the launcher.
- The build downloads and the SUT recipe are neither logged nor tracked.
- The written decision says "source build", but the work uses Maven artifacts.

**Timeline:** on day 1 of a 3-week timebox, the pilot is **on track**, but the build is currently blocked (Gradle loopback). No CVE assertion exists yet, so KC1 has no result.

---

## Follow-up review (post-5abf5dc), 2026-10-22

Scope: `e8e78a3`, `39b895e`, `c133950` (plus `fdb5c9d`, the user's SCOPE edit for D6), and the uncommitted diff in `scripts/30_build_vanilla.sh`. Read-only. Docker was not touched and nothing was downloaded. iam-mock, policy and vault behaviour was read from the local v0.6.2 source clone (`build/connector-062`, `f58c71a`); line refs point to that tree.

### Q1 — iam-mock and participant identity

- `MockIdentityService.verifyJwtToken` (`extensions/common/iam/iam-mock/.../MockIdentityService.java`) accepts **any** JSON token without checking it. It returns the claims `region` and `client_id` taken from the token itself.
- `ParticipantAgentServiceImpl` takes the participant identity from claim `client_id` (`DEFAULT_IDENTITY_CLAIM_KEY`, `spi/.../ParticipantAgentService.java:27`; overridable with `edc.agent.identity.key`).
- **So counterparties are distinguishable:** a token with `clientId: X` and one with `clientId: Y` yield different `ParticipantAgent` identities. The 0.6.2 runtime can tell them apart. Self-asserted identity is acceptable here, because both CVEs are post-authentication (D5).
- **The gap is on the policy side.** Vanilla 0.6.2 registers no constraint function in the `catalog` scope (`ContractDefinitionResolver.CATALOGING_SCOPE`). The only core function, contract expiry, is bound to `transfer` (`ContractCoreExtension.java:182-186`).
- `ScopeFilter` (`policy-engine-lib/.../ScopeFilter.java:132-138`) **silently drops** any constraint whose left operand is not bound to the scope. An "admit X, deny Y" access policy written with an unregistered operand therefore becomes "admit everyone". The -9202 test would then PASS on every rung (no FAIL at 0.6.2–0.9.0), so it fails admission.

| # | Issue | Sev | Required change |
|---|---|---|---|
| F1 | No catalog-scope constraint function exists, so a policy cannot deny counterparty Y. The -9202 oracle cannot FAIL. | **H** | Add a small, tracked **test-fixture extension** to the launcher, e.g. `testbed/launcher/fixture/`. It registers and binds an `AtomicConstraintFunction` for one left operand (e.g. `pilot08:participant`, eq against `ParticipantAgent.getIdentity()`) in scopes `catalog` and `contract.negotiation`. Build it against each version's SPI (the policy-engine API changed between 0.6 and 0.9), keep identical semantics, and record it in DECISIONS as part of the SUT. Before any CVE assertion, add a smoke row per version: catalog for X lists the dataset; catalog for Y does not. That row proves the deny works before -9202 is measured. |

### Q2 — Module coverage per version

**-9202 (catalogue):**
- The `dsp` module (catalog protocol and `DatasetResolverImpl`) and `control-plane-core` are present at all four versions (`env/maven-modules.csv`).
- Coverage is OK once F1 exists.

**-4536 (OAuth2 data sink):**
- `data-plane-http-oauth2` is present at all four versions.
- At 0.6.x the provider-push flow comes from `transfer-data-plane` (`ProviderPushTransferDataFlowController`), which is present only at 0.6.x.
- At 0.9.x the launcher has **no** signalling transfer path. `data-plane-control-api` is absent there (`maven-modules.csv:21` says `no`).
- Two consequences:
  1. `build.gradle.kts:47` adds `data-plane-control-api` unconditionally, so **the 0.9.0 and 0.9.1 builds will fail to resolve**.
  2. Even after fixing that, a 0.9.x transfer needs the signalling modules (`transfer-data-plane-signaling`, `data-plane-signaling-client`, and self-registration or selector registration). Without them, -4536 at 0.9.x would be a vacuous PASS (no transfer runs).
- The admission flip for -4536 is 0.6.2→0.6.3, where the module set is identical, so the flip itself is sound. The 0.9.x cells only need to stay PASS, but they should be behavioural.
- **Vault:** the default vault is an empty `InMemoryVault` (`boot-lib/.../InMemoryVault.java`; `BootServicesExtension.java:100-110`). 0.6.2 has no secrets management API and no seeding. With no canary secret in the provider vault, the vulnerable build cannot leak anything, and -4536 would PASS at 0.6.2 (a false PASS).
- `provider.properties:16-17` also name `token-signer` and `token-verifier` aliases that do not exist in the empty vault.

| # | Issue | Sev | Required change |
|---|---|---|---|
| F2 | `build.gradle.kts:47` makes `data-plane-control-api` unconditional, but it is not published at 0.9.0/0.9.1. Those builds will fail. | **H** | Derive each version's module list from `env/maven-modules.csv`, with explicit per-line conditions. Add the 0.9.x signalling modules after checking them in `maven-modules.csv`. Then build 0.6.3, 0.9.0 and 0.9.1, and run the per-version smoke. |
| F3 | Without seeding, the provider vault is empty. A -4536 test cannot FAIL at 0.6.2. | **H** | Seed a **canary** secret (random per run, never written to `results/`) into the provider vault at every version. Use either `vault-filesystem` (check it in `maven-modules.csv`) or the fixture extension from F1. The -4536 assertion records only whether the driver's token endpoint received *any* request carrying the canary (FAIL) or not (PASS), never the value. Add the token endpoint to the driver on the internal network. |
| F4 | At 0.9.x there is no transfer path, so -4536 PASS there would be vacuous. | M | Same fix as F2. Record in VERSIONS.md that the 0.9.x -4536 cells are behavioural only once a signalling transfer completes; otherwise mark them `n/a`, not PASS. |

### Q3 — Unauthenticated management API on 0.6.2

- **Local-only and scope rules: not affected.** The provider runs on an `--internal` network with no published ports (`31_run_vanilla.sh:13,15`), so only containers on that network can reach `:8181`.
- **Test validity:** not affected *if* the management API is used only for fixture setup (assets, policies, contract definitions, canary seeding) and every CVE assertion goes through the DSP port `:8282` with a mock token. If an assertion ever reads data through `:8181`, a FAIL means nothing, because the counterparty in the threat model has no management access.
- **Comparability:** the KC2 Tractus-X smoke expects management 401/200. The vanilla SUT should match, so the two testbeds behave the same.

| # | Issue | Sev | Required change |
|---|---|---|---|
| F5 | The management API is open, and nothing enforces that assertions avoid it. | M | Add `auth-tokenbased` (check it in `maven-modules.csv`) with `edc.api.auth.key`, plus management 401/200 smoke rows. In the harness, keep setup calls (management) and assertion calls (DSP only) in separate functions, so no result row can come from `:8181`. |

### Q4 — The uncommitted checksum change (`30_build_vanilla.sh:16-22`)

**Correct:**
- The header is written once.
- Dedupe per version works: `grep -v "^$V,"` keeps the header, so it exits 0 under `pipefail`. The unescaped dots in `$V` are harmless.
- The row format matches the header.
- The jar is copied to a versioned name before hashing.

**Problems:**
- **(a)** `31_run_vanilla.sh:10` runs `pilot08-edc-launcher-all.jar`, the *last built* jar, not `pilot08-edc-$V.jar`. After building 0.9.1, `31_run_vanilla.sh 0.6.2` would test 0.9.1 and label it 0.6.2. **H.**
- **(b)** The CSV has no `commit` column, so a jar is not tied to the launcher recipe. The dirty marker is also not recorded.
- **(c)** Shadow jars embed timestamps, so the sha changes on every rebuild. That is fine as long as runs verify against the CSV, but it is not reproducible.
- **(d)** `env/vanilla-jars.csv` does not exist yet, because 0.6.2 has not been rebuilt with this script.

**Verdict:** safe to commit (pilot file, pre-approved, no secrets) once (b) is added. Fix (a) in the same commit.

| # | Issue | Sev | Required change |
|---|---|---|---|
| F6 | The run script ignores `$V` when choosing the jar. | **H** | In `31_run_vanilla.sh` use `pilot08-edc-$V.jar`. Before boot, verify its sha256 against the `$V` row of `env/vanilla-jars.csv` and abort on mismatch. Write that sha into each smoke/result row, or into a run header. |
| F7 | `vanilla-jars.csv` lacks `commit`. | M | Use header `edc_version,sha256,bytes,commit,date` and append `$COMMIT` (with the dirty marker). Add `tasks.shadowJar { isPreserveFileTimestamps = false; isReproducibleFileOrder = true }` so rebuilds hash identically. Commit together with F6, then rebuild 0.6.2 to create the CSV. |

### Q5 — Status of the earlier prioritised list (as of `c133950`)

| P | Item | Status | Note |
|---|---|---|---|
| 1 | 6.1 -8642 vacuous | **done** | D6, resolved by the user in SCOPE (`fdb5c9d`): -8642 excluded and KC1 rests on -4536 and -9202. Minor: `maven-modules.csv:22` says "last release 0.8.1" but has no 0.7/0.8 columns. Add a `source_url` or the version list as evidence. |
| 2 | 6.2 ENV.md download log | **partial** | Table added (gradle image by digest, 1182 MB; plugin; Maven; clones). Open: the Connector clone row has no SHA (`f58c71a…` is known). The Samples clone is still unpinned at `main` (`199eda0`). The plugin row still says "pending user OK", but SCOPE now approves the Plugin Portal. Clones of 0.6.3/0.9.x are not logged (none were made; SHAs come from `ls-remote`, which is fine). `distributionSha256Sum` is moot because the wrapper is no longer used. |
| 3 | 6.3 recipe tracked; dependency verification; jar sha | **partial** | The recipe is tracked in `testbed/launcher/` and the pilot `.gitignore` is committed. **Gradle dependency verification is absent**, yet `SCOPE.md:27` (the user's text) now says "dependencies checksum-verified", so that claim is currently false. `testbed/launcher/.gitignore:4` ignores `gradle/`, which is exactly where `gradle/verification-metadata.xml` must live, so it would be silently untracked. Jar sha: see Q4. |
| 4 | 1.1 "built from source" | **partial** | Fixed in DECISIONS (D6), SCOPE (user) and ENV. Still stale: `DECISIONS.md:9` (D5 text still says "built from source", acceptable if D6 is read as amending it), the `build.gradle.kts:1-6` header ("at a pinned tag", "transfer-data-plane so -8642 … present"), `PILOT-REPORT.md:83,112-113`, and `docs/STATE.md` (no new entry yet; the D5 entry says "built from source"). |
| 5 | 6.5 maven-modules.csv | **done** | `env/maven-modules.csv` exists. It needs rows for the modules F2, F3 and F5 add (signalling, `vault-filesystem`, `auth-tokenbased`). |
| 6 | 6.6 container build | **done** | Builder pinned by digest and logged. It runs on the default network, not `pilot08_dsp`. The location change is recorded in ENV.md. |
| 7 | 4.1/4.2 vanilla isolation; dirty marker | **open** | `31_run_vanilla.sh:12` creates `pilot08v` but reuses an existing one without checking `Internal=true`. No `05_net_check` equivalent has run on `pilot08v`. `lib.sh:10` still ignores untracked files. `env/vanilla-smoke.csv` is stamped `fdb5c9d-dirty` and must be re-run on a clean commit. |
| 8 | 5.1 commits outside `pilots/` | **done** | Approved after the fact by the user. `fdb5c9d` (SCOPE.md) is inside `pilots/`. |
| 9 | 6.4 iam-mock SHAs | **done** | `env/iam-mock-check.csv` now has per-tag SHAs and Maven presence. |
| 10 | 3.1/3.2/6.7 docs | **open** | VERSIONS.md has no D5/D6 section. ENV.md still says "Route actually used: A" (`ENV.md:7`) and "JDK not needed" (`:48`). The PILOT-REPORT status table (`:14-16`) predates the 0.6.2 boot and D6. |

### Follow-up verdict

**Progress:**
- The 0.6.2 SUT boots on an internal network.
- A mock-token counterparty gets a real `dcat:Catalog`.
- The user resolved D6 cleanly.
- Scope rules held: build egress happens only in the builder container; the runtime network is internal.

**The 0.6.2 testbed is not yet fit for writing the -4536 and -9202 assertions:**
- -9202 needs a catalog-scope deny that actually takes effect (F1).
- -4536 needs a seeded canary secret and a token endpoint (F3).
- Every run must be pinned to the right jar (F6).
- The 0.9.x builds will fail until the module list is made version-conditional (F2).

These are setup gaps, not method failures, so KC1 is still open and on track within the timebox.

---

## Second follow-up (post-26dbb3f), 2026-10-22

Scope: `a15c08d` (version-conditional launcher, build and run fixes), `e96e1a6` (four-rung evidence) and `b2c1f62` (report status). Read-only. Docker was not touched and nothing was downloaded.

**Done:**
- **F2:** per-version module sets. All four rungs build, and 0.9.x gets Signaling, EDR, data-plane-iam and self-registration.
- **F6:** `31_run_vanilla.sh:11` runs `pilot08-edc-$V.jar`, checks its sha256 and carries the sha into every smoke row.
- **F7:** `vanilla-jars.csv` has a `commit` column, and the shadow jar uses the reproducible flags.
- **Part of D3:** a `net_internal` row for `pilot08v`. The smoke was re-run per version on clean commit `a15c08d` (16/16 `ok=yes`, all four rungs).
- **Report:** the PILOT-REPORT status table now names F1, F3 and F5 as gating the CVE tests.

**Evidence chain:** `vanilla-jars.csv` and `vanilla-smoke.csv` agree on all four shas. The jars were built at `a15c08d`, and `e96e1a6` changes only evidence files.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| G1 | `testbed/launcher/build.gradle.kts:4`; `a15c08d` message | Both claim "verified present on Maven Central in `env/maven-modules.csv`". The CSV has 22 rows and **none** of the 11 modules added in this commit: `provision-http`, `transfer-pull-http-dynamic-receiver`, `control-api-configuration`, `edr-store-core`, `edr-cache-api`, `edr-store-receiver`, `callback-event-dispatcher`, `callback-http-dispatcher`, `transfer-data-plane-signaling`, `data-plane-selector-control-api`, `data-plane-self-registration`, `data-plane-iam`, `data-plane-public-api-v2`. The successful build shows they resolved, but the stated evidence does not exist. | M | Regenerate `env/maven-modules.csv` from the launcher's actual dependency list (one row per module × version), with a script so it cannot drift again. Add rows for `vault-filesystem` and `auth-tokenbased` before F3/F5. |
| G2 | `scripts/31_run_vanilla.sh:16` | `[ -n "$want" ] && …` means that when `vanilla-jars.csv` has no row for `$V`, the jar boots **unverified** and no error is raised. | M | Abort when `want` is empty: `[ -n "$want" ] \|\| { echo "no recorded sha for $V"; exit 1; }`, then compare. |
| G3 | `e96e1a6` message | "The clean rebuild reproduced byte-identical shas to the prior build". The prior build's shas are not stored anywhere, so this is "observed in session, not archived". | L | Mark it as not archived in the report, or rebuild one version and add a second `vanilla-jars` row/column as proof. |
| G4 | `31_run_vanilla.sh:18,29` | `net_internal` is recorded as a row, but the provider boots before it is checked, and a `false` value does not stop the run. No egress probe has run on `pilot08v`. | L | Check `Internal=true` before `docker run` and abort if not. Port the IP/DNS egress probes from `05_net_check.sh`, with the positive control, to `pilot08v`. |
| G5 | 0.9.x rungs | The rungs boot, but nothing shows a transfer completes at 0.9.x. `data-plane-iam` also needs signer/verifier key aliases in the vault, which is still empty. -4536 at 0.9.x stays vacuous (F4) until a transfer smoke passes. | M | With F3's vault seeding, seed the data-plane token keys as well. Add a per-version transfer smoke row (HttpData push to the driver completes) before any -4536 cell counts. |

**Still open from the first follow-up** (not touched by these commits):
- **F1 (H):** catalog-scope constraint fixture.
- **F3 (H):** canary vault seeding and the token endpoint.
- **F5 (M):** management-API auth.
- **D1 (M):** Gradle dependency verification. `SCOPE.md:27` still claims "checksum-verified", and `testbed/launcher/.gitignore` still ignores `gradle/`.
- **D2 (M):** ENV.md clone SHA, Samples pin, and the Plugin Portal row.
- **D3 rest (M):** egress probes and the `lib.sh:10` untracked-file marker.
- **D4 (M):** stale wording in `ENV.md:7,48`, VERSIONS (no D5/D6 section), `docs/STATE.md`, and the `maven-modules.csv:22` "0.8.1" claim.

**Verdict:** the four-rung SUT is now real, pinned and evidenced, so the build phase is done. It is still not fit for the CVE assertions. F1 and F3 are the gate: without them, -9202 and -4536 can only PASS. The pilot is on track, and the next work is fixture code, not infrastructure.

---

## Third follow-up (post-bbc7814), 2026-10-22: first CVE result

Scope: `ac70308` (module CSV script, jar-sha guard), `e9518f7` (F1 fixture, F5 management auth), `ca04f9c` (-9202 test), `9c5f512` (-9202 results) and `dd3a579` (report). Read-only. Docker was not touched and nothing was downloaded.

**Done and correct:**
- **G1:** `scripts/03_check_modules.sh` generates `env/maven-modules.csv` for every launcher module plus `vault-filesystem` and `auth-tokenbased`.
- **G2:** `31_run_vanilla.sh:16` aborts when no sha is recorded.
- **F5:** `auth-tokenbased` is in. Management returns 401 without the key and 200 with it on all four rungs, so the smoke is now 24/24 on clean `ca04f9c`.
- **F1:** the fixture is tracked (`testbed/launcher/src/.../Pilot08ParticipantConstraintExtension.java`) and bound in scope `catalog`, the scope where `ContractDefinitionResolver` evaluates access policies. The left operand is the expanded IRI and identity comes from `client_id`, which matches the iam-mock reading in Q1.
- **The -9202 test design is sound:** it seeds a policy that admits only `alice`, requires the precondition (alice sees the dataset in the catalogue, mallory does not), and counts a leak only on HTTP 200 plus a `dcat:Dataset` body, so a 404 that echoes the id does not count.
- Results carry the jar sha and a clean commit. No payloads are stored.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| H1 | `results/cve-2024-9202.csv:2-3`; `PILOT-REPORT.md` status row "DONE, ADMITTED"; `9c5f512` | **The admission claim is premature.** The rule (`SCOPE.md:48`; VERSIONS.md "12-cell pattern … rejected otherwise") requires the flip to happen *exactly* at the fixing version **on the ladder**, so -9202 must read **FAIL / FAIL / FAIL / PASS** at 0.6.2 / 0.6.3 / 0.9.0 / 0.9.1. Only 0.9.0 and 0.9.1 were run. A PASS at 0.6.x, for example because the fixture or the single-dataset path behaves differently there, would reject the test. | **H** | Run `40_test_9202.sh` at 0.6.2 and 0.6.3, and commit all four rows. Change the report row and the commit claim to "provisional (2 of 4 cells)" until then. Mark -9202 "admitted" only if all four cells match. |
| H2 | `scripts/40_test_9202.sh:31-36,41-44` | **There is no positive control on the single-dataset endpoint.** A 404 for mallory at 0.9.1 counts as PASS, but nothing shows that the endpoint returns the dataset to the *admitted* party on that rung. If the path, asset-id resolution or response shape changed at 0.9.1, PASS would be vacuous, the same flaw as -8642 under D6. | **H** | Add `alice_dataset_http` and `alice_dataset_leak`. Require alice = 200 plus `dcat:Dataset` on every rung, otherwise the verdict is `INVALID`. Record both columns. |
| M1 | `40_test_9202.sh:28-30` | `mallory_sees_catalog=no` is derived by grepping for the asset id. If mallory's catalogue request errors (401, 500, timeout), the grep also yields `no`, and the "hidden" precondition holds for the wrong reason. | M | Require mallory's catalogue response to be HTTP 200 with a `dcat:Catalog` body before reading "hidden". Otherwise the verdict is `INVALID`. |
| M2 | `results/cve-2024-9202.csv:1` vs `SCOPE.md` "Results CSVs record build version, invariant ID, pass/fail, and commit hash only" | The results CSV carries observation columns (`alice_sees_catalog`, `mallory_*`, `jar_sha256`). They are harmless (yes/no and HTTP codes, no payloads), but they deviate from the user's written rule. | M | Either move the observations to `env/9202-observations.csv` and keep `results/` to the four SCOPE columns plus `jar_sha256`, or ask the user to widen the SCOPE rule. Do not edit SCOPE.md yourself. |
| M3 | `env/maven-modules.csv:37` (`vault-filesystem` no at 0.9.x) | F3 cannot use `vault-filesystem` uniformly: it is gone at 0.9.x. Mixing seeding mechanisms across rungs would add a confounder to the -4536 ladder. | M | Seed the canary (and, for 0.9.x, the data-plane token keys) from the fixture extension via `Vault.storeSecret` at boot, the same code on every rung. |
| L1 | `03_check_modules.sh:23` | The "published through 0.8.1" note is hard-coded. The metadata it relies on is fetched but not stored. | L | Save the fetched `maven-metadata.xml` for `transfer-data-plane` under `env/`, or derive the note from it. |

**Still open:**
- **F3 (H):** canary seeding plus the token endpoint, and a full OAuth2 push transfer for -4536.
- **G5 (M):** transfer smoke at 0.9.x.
- **D1 (M):** dependency verification. `SCOPE.md:27` still claims it.
- **D2 (M):** ENV clone SHA, Samples pin, Plugin Portal row.
- **D3 (M):** egress probes on `pilot08v`; `Internal` checked before boot; untracked-file dirty marker.
- **D4 (M):** stale wording in ENV, VERSIONS, STATE.

**Verdict:** this is the first real CVE signal. The denied counterparty gets the hidden dataset at 0.9.0 and is blocked at 0.9.1, on pinned jars and a clean commit, and the fixture and test logic are sound. It is **not yet an admitted rediscovery**: two of the four ladder cells and the admitted-party positive control are missing (H1, H2), and both are cheap to add. KC1 also needs -4536, which depends on F3 and a working OAuth2 push transfer, the harder half. The pilot is on track.

---

## Fourth follow-up (post-941c8d6), 2026-10-22

Scope: `efc1fb5`, `907d85e`, `a544693`, `564b4be`. Read-only. Docker was not touched and nothing was downloaded. Management-API paths were checked in the local v0.6.2 source clone.

**Done and correct:**
- **H2:** the admitted party (alice) must fetch the dataset through the single-dataset endpoint, or the verdict is `INVALID`.
- **M1:** both catalogue responses must contain `dcat:Catalog`.
- **M2:** `results/cve-2024-9202.csv` keeps only the SCOPE columns plus `jar_sha256`. The observations are in `env/cve-2024-9202-observations.csv`, joinable on version, commit and sha.
- **H1, handled honestly:** the report now says **PROVISIONAL**, and all four rungs are recorded.
- **Evidence chain:** results, observations, jars and smoke (24/24) all carry clean commit `a544693`, and the jar shas match across all three files.

**Current ladder:** 0.6.2 `INVALID` / 0.6.3 `INVALID` / 0.9.0 `FAIL` / 0.9.1 `PASS`. At 0.9.x, the precondition, the positive control and the flip all hold, so the 0.9.0→0.9.1 transition is a clean, controlled signal.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| J1 | `scripts/40_test_9202.sh:14,20-21` | **Root cause of the 0.6.x `INVALID`, confirmed in source.** v0.6.2 serves `@Path("/v2/policydefinitions")` and `@Path("/v2/contractdefinitions")`; only assets are `/v3`. `mgmt()` hard-codes `/v3/` for every resource, so the policy and contract-definition seeds 404 at 0.6.x (observations show `seed_policy`/`seed_cd = 404`), no access policy exists, and alice cannot see the asset. This is a harness bug, not a SUT difference. | **H** | Make the path per version: `v2` for `policydefinitions` and `contractdefinitions` at 0.6.x, `v3` at 0.9.x. Read the 0.6.3 paths from that tag rather than assuming. Re-run 0.6.2 and 0.6.3. -9202 is admitted only if the ladder reads FAIL/FAIL/FAIL/PASS, as `SCOPE.md:48` and VERSIONS.md require. |
| J2 | `40_test_9202.sh:46-50` | Seeding failure is caught only indirectly (through `alice_sees=no`). An `INVALID` row does not say *why*. | M | Gate the verdict explicitly on `seed_asset`, `seed_policy` and `seed_cd` each being 2xx. Add an `invalid_reason` column to the observations so each `INVALID` explains itself without rereading the codes. |
| J3 | `40_test_9202.sh:6` | The header still says "Admitted only if it flips FAIL->PASS at 0.9.0 -> 0.9.1". That is the old, weaker rule. | L | Reword to "admitted only if 0.6.2/0.6.3/0.9.0/0.9.1 read FAIL/FAIL/FAIL/PASS". |
| J4 | `env/cve-2024-9202-observations.csv:2-3` | The observations show something worth recording: at 0.6.x, with **no** contract definition at all, mallory still gets HTTP 200 with a `dcat:Dataset` from the single-dataset endpoint. That matches the CVE mechanism (no offer filtering on the single-dataset path) and Tractus-X's `dataset-bugfix` (empty `hasPolicy` → 404). | L (note) | Do not count it, because these rows are `INVALID`. Mention it in VERSIONS.md as supporting context once J1 produces valid 0.6.x rows. |

**Still open:**
- **F3 (H):** canary seeding, the token endpoint, and the OAuth2 push transfer for -4536. Seed through the fixture, per M3.
- **G5 (M):** transfer smoke at 0.9.x.
- **D1 (M):** Gradle dependency verification. `SCOPE.md:27` still claims it, and the launcher `.gitignore` still hides `gradle/`.
- **D2 (M):** ENV clone SHA, Samples pin, Plugin Portal row.
- **D3 (M):** egress probes on `pilot08v`; check `Internal` before boot; untracked-file dirty marker.
- **D4 (M):** stale ENV, VERSIONS and STATE wording.
- **L1:** archive the `transfer-data-plane` metadata.

**Verdict:** the -9202 test is now well controlled, and the pilot reports its status honestly as provisional. What stands between it and admission is a one-line harness fix (J1), not a question of method. -4536 (F3) is the critical path for KC1. The pilot is on track.

---

## Review 5 (post-ffa967e), 2026-10-22

Scope: `1a73e3f`, `2605adc`, `60171df`, `452a7e1`, plus the uncommitted work: `scripts/41_test_4536.sh`, `results/cve-2024-4536.csv`, `env/cve-2024-4536-observations.csv`, the canary seeding in `Pilot08ParticipantConstraintExtension.java`, and the `env/vanilla-jars.csv` and `env/vanilla-smoke.csv` diffs. I also read the pilot session's last 30 transcript messages. Read-only: Docker was not touched, nothing was downloaded, and nothing was pushed. Public-mirror check: `gh api repos/ftaakash/authz-ladder/commits`, read-only.

**Done and correct:**
- **-9202 admission holds as committed.** `results/cve-2024-9202.csv` at clean `ffa967e` reads FAIL/FAIL/FAIL/PASS. The observations show seeds 200 on every rung, alice sees the asset and fetches the dataset (positive control) on all four rungs, mallory is hidden in the catalogue, and the flip comes from the single-dataset endpoint (200 → 404 at 0.9.1). The jar shas match the committed `vanilla-jars.csv`. See C5 for the caveat about the uncommitted diff.
- **M3 (uniform seeding):** the canary goes in through `Vault.storeSecret` in the fixture at boot, with the same code on every rung. The script gates the verdict on the `seeded canary secret` log line.
- **Canary hygiene, mostly right:** the value is random per run (`41_test_4536.sh:24`). Only yes/no lands in `results/` and `env/`, the console summary does not print it, and the receiver's `/cap.txt` disappears with the container.
- **Token endpoint:** `receiver:9300` is an alias on `pilot08v`. The DNS failure seen in session shows the provider could not resolve anything off-net.
- **Results layout (M2):** `results/cve-2024-4536.csv` has edc_version, invariant, verdict, jar_sha256 and commit. The observations are in `env/`.
- **Publishing:** `90_publish.sh` does a normal `git push` only, with `--ff-only` pull and `am --abort` on failure. All 20 commits on `ftaakash/authz-ladder` carry no Co-Authored-By line.
- **Source vector rejected for the right underlying reason:** the session showed the OAuth2 *source* path leaks on both 0.6.2 and 0.6.3, then confirmed in source that 0.6.3 drops only the sink decorator.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| C1 | `scripts/41_test_4536.sh:48-50,61-62` | **The verdict signals come from the provider log, and the session showed they give false positives.** A log line containing the trigger payload already holds `receiver:9300` and `http://receiver:9300/token`, so `leak_attempt` and `df_processed` can come from an echo of the payload rather than a real request. The pilot hit exactly this ("almost certainly a false positive"). The 0.6.3 **PASS** rests only on `df_processed=yes`, which comes from that grep. Nothing shows a transfer actually ran, so PASS is unproven, the D6 vacuous-PASS problem again. | **H** | Take the evidence from the receiver, not the provider log. Have the receiver log each request line (method + path) to `/cap.txt`. PASS needs a positive control: the receiver saw `GET /data` (source read) **and** a `POST`/`PUT` to `/sink` (sink write) on that rung. FAIL needs a receiver-observed `POST /token` (`token_post`) and/or the canary value in its body (`leak_value`). Keep the provider-log greps only as observation columns. Anything else is `INVALID`. Add `src_get`, `sink_write` and `token_post` columns to the observations. |
| C2 | `env/cve-2024-4536-observations.csv:2`; `results/cve-2024-4536.csv:2-3` | **The current rows are stale and contradict each other.** 0.6.2 records `leak_value=yes` but `INVALID`, so it was written by an older verdict logic; the current script would say FAIL. Both rows are stamped `452a7e1-dirty`, and the 0.6.x jars were built at `60171df-dirty`, from the uncommitted fixture. | **H** | Do not cite these rows. Commit the fixture and `41_test_4536.sh` first. Rebuild **all four** jars at that clean commit, then re-run every rung. |
| C3 | `41_test_4536.sh:43,53`; `vanilla-jars.csv` (0.9.x rows at `a544693`) | **The 0.9.x rungs cannot run as written.** (a) The 0.9.x jars predate the canary seeding and were never rebuilt. (b) The trigger is `POST /control/transfer` with the legacy `dataspaceconnector:dataflowrequest` body. That endpoint is `data-plane-control-api` (`build/connector-062/.../DataPlaneControlApiController.java:38`) and does not exist at 0.9.1, where only `@Path("/v1/dataflows")` is served (`DataPlaneSignalingApiController`). The signaling API **is** present at 0.6.2 as well, but the launcher does not include it there. (c) G5 is still open: no transfer smoke at 0.9.x, and the `data-plane-iam` keys are unseeded. | **H** | Use one trigger mechanism on every rung: either the DSP path (C4) or the signaling API `/v1/dataflows` with a `DataFlowStartMessage`, adding `data-plane-signaling` to the 0.6.x module set (check `maven-modules.csv` first). Seed the 0.9.x data-plane token keys through the same fixture. The C1 positive control then doubles as the G5 transfer smoke. |
| C4 | `41_test_4536.sh:5-8,39-43`; `PILOT-REPORT.md` §2; D5 | **Threat-model boundary.** The test posts straight to the provider's data-plane control API, so the harness controls *both* addresses. A real counterparty controls only the destination, through a DSP transfer request. The source-vector leak at 0.6.3 (seen in session, not archived) is the proof that this harness can inject inputs a counterparty cannot. Also, the vector was switched from source to sink *after* the source run gave no flip. The justification (the counterparty controls the destination; the advisory names the sink) is correct, but it is written down nowhere, so it reads as fitting the vector to the oracle. D5 rejected testing below the DSP boundary (option C), and the report still says -4536 is "negotiated over DSP". | **H (user decision)** | Write the rationale before re-running: the destination is the counterparty-controlled input (advisory GHSA-2x52-8f29-7cjr), and the source is provider-defined by the asset. Archive the source-vector observation in `env/` as "not a finding: source address is provider-controlled". Then **the user decides (D7)**: (a) drive -4536 through DSP, with an iam-mock consumer connector negotiating and requesting a transfer whose `dataDestination` carries the OAuth2 properties; or (b) accept a data-plane-level oracle and narrow the paper claim to that. Recommendation: (a), because it matches D5 and §2. Until D7 is recorded, -4536 is not admissible either way. |
| C5 | `env/vanilla-jars.csv`, `env/vanilla-smoke.csv` (uncommitted diff) | **Committing this diff breaks the -9202 evidence chain.** It *replaces* the 0.6.x rows for shas `82c1dd6d…`/`ef253e7d…`, the jars `results/cve-2024-9202.csv` cites, and the jars on disk have been overwritten. After that commit, the 0.6.x half of the -9202 admission traces to nothing. | **H** | Make `vanilla-jars.csv` append-only, keyed by (version, sha, build commit), and keep the old rows and smoke rows. Then, since all four jars are rebuilt for C2/C3 anyway, **re-run -9202 on the final jar set** so KC1 is decided on one jar set at one clean commit. |
| C6 | `VERSIONS.md:12` vs D6 | **Removal-as-fix, inconsistently treated.** VERSIONS says -4536's PASS holds "vacuously … must PASS when the feature is absent". D6 refused exactly that for -8642. The cases differ: at 0.6.3 the OAuth2 extension is still loaded (source decorator) and only the sink path is gone, so with the C1 positive control (the sink write happens with the same OAuth2 destination properties and no token request) the PASS measures behaviour rather than absence. That reasoning is not recorded anywhere. | **M (user decision)** | Ask the user to record, as part of D7, whether a PASS with a positive control counts at a removal fix. Fix the `VERSIONS.md:12` wording to match. Without the positive control, the answer under D6 is no, and KC1 fails. |
| C7 | `41_test_4536.sh:29-30,45` | The receiver is flaky. `Content-Length: 44`, but the body `{"access_token":"x","token_type":"Bearer"}` is 42 bytes, so clients wait for 2 bytes that never come. A single serial `nc -l` with a 12 s timeout per connection, combined with a fixed `sleep 10`, can drop the source, sink or token request depending on timing, and a dropped request turns into a false INVALID or PASS. | M | Fix the length, or compute it, and add `Connection: close`. Use a responder that handles concurrent connections (for example `busybox httpd` with a CGI script). Replace `sleep 10` with polling `/cap.txt` until the expected requests arrive or a timeout hits, and record which ones arrived. |
| C8 | `41_test_4536.sh:20,27`; `lib.sh:10` | Isolation and provenance. (a) If `pilot08v` already exists, it is never checked for `Internal=true` before the provider boots (D3). (b) The dirty marker still ignores untracked files: `41_test_4536.sh` is untracked, and only the modified Java file made these runs `-dirty`. | M | (a) Abort unless `docker network inspect pilot08v` reports `Internal=true`, and record it. (b) Add `git ls-files --others --exclude-standard -- . ':(exclude)env' ':(exclude)results'` to the marker. |
| C9 | `41_test_4536.sh:27`; container lifecycle | The canary is passed as `-D…` on the provider command line, so it stays visible in `docker inspect` until the next run removes the container. There is also no check that the canary never reaches the provider log. | M | `docker rm -f pilot08v-provider` at the end (trap on EXIT). Add an observation `canary_in_provider_log` (yes/no from `grep -cF`, value never printed). `yes` → `INVALID` plus a hygiene alert. |
| C10 | `scripts/90_publish.sh:30-32` | **The scope guard checks only file paths.** A candidate finding can still reach the public mirror through a results/observation row, `PILOT-REPORT.md` text or a commit message. KC2 makes this real: on current EDC/Tractus-X, any FAIL row *is* an undisclosed finding. The guard also misses variants like `candidate_findings.md`. | M | Before KC2: refuse when any patch adds a `FAIL` row for a version outside the KC1 ladder (0.6.2/0.6.3/0.9.0/0.9.1), or when a patch or commit message matches `candidate|undisclosed|new violation`, case-insensitive. Make the publish print the commit list and require an explicit `--yes`. Do not run the script as part of this fix. |
| C11 | `PILOT-REPORT.md` status table, §2, evidence index | The report is stale. It says "Status at 2026-10-21", F3 "NOT STARTED", -4536 "NOT STARTED" and "negotiated over DSP". The evidence index lists D1–D5 and omits `vanilla-jars.csv`, `vanilla-smoke.csv`, `cve-2024-9202*.csv` and `maven-modules.csv`. Session-only facts (the source-vector leak at both rungs, the 400 body "Cannot authenticate through OAuth2") are not archived. | M | Update the table to: -4536 **IN PROGRESS, no admissible cells**. Complete the evidence index. Mark session-only facts "not archived", or archive them in `env/` as yes/no columns. |
| C12 | public mirror history | Earlier commits (`dd16a89`, `f2775fa`: "-9202 rediscovered/admitted") are public from before H1 forced the downgrade to provisional. They cannot be rewritten (no force-push). | L | Note in the report that those early admission messages were superseded by `1a73e3f`. No history change. |

**Earlier open items:**
- **F3:** partly done (seeding and receiver). The OAuth2 push transfer is only proven at 0.6.x through the control API (C1–C4).
- **G5:** open, now part of C3.
- **D1 (dependency verification):** open. `SCOPE.md:27` still says "checksum-verified". There is no `gradle/verification-metadata.xml`, and `testbed/launcher/.gitignore` still ignores `gradle/`. Either add verification or tell the user the SCOPE wording is false. The pilot must not edit SCOPE.md.
- **D2 (ENV):** partial. `ENV.md:65` still reads "pending user OK" for the Plugin Portal although D6 approved it. `ENV.md:68` (Samples) is unpinned. `ENV.md:67` gives a tag but no commit SHA, and the `connector-091` clone has no row.
- **D3 (isolation and dirty marker):** open. See C8. No egress probe has run on `pilot08v`.
- **D4 (wording):** partial. ENV §KC1 is fixed. `docs/STATE.md:53` still says "built from source". VERSIONS.md still has no D5/D6 section and keeps the MVD/Tractus-X reachability notes (`:53`, `:71-99`) without a superseded marker.
- **L1:** open.

**Verdict:**
- **-9202:** remains admitted on its committed evidence. Protect that evidence (C5) and re-run it on the final jar set.
- **-4536:** the mechanism is real. At 0.6.2 the provider dereferenced a consumer-named vault alias and sent the value to a consumer-chosen URL; at 0.6.3 the sink path is gone. But there is **no admissible cell yet**. The rows are stale and dirty (C2), PASS has no positive control (C1), 0.9.x cannot run (C3), and the boundary and removal questions need a user decision (C4, C6).
- **On track:** yes. It is fixable within the timebox: about one rebuild plus four reruns once C1–C3 land, plus a consumer connector if D7 = (a).
- **Kill condition 1 cannot be decided yet.** It needs the user's D7 (C4 + C6), then a clean four-cell -4536 ladder and a -9202 re-run on the same jar set.

---

## Review 6 (post-15ae379), 2026-10-23

Scope: `3fe9676` (F3 fixture, D7, source-vector note, `41_test_4536.sh`), `063723e` (consumer config), the untracked `scripts/42_test_4536_dsp.sh`, and the pilot transcript up to its failed exit-4 run. Read-only: Docker was not touched, nothing was downloaded, nothing was pushed. Management paths were checked in the local v0.6.2 and v0.9.1 source clones.

**Done and correct:**
- **D7 is a real user decision.** The pilot asked through AskUserQuestion; the user chose (a) a DSP-driven test and (b) that a removal-fix PASS counts when there is a positive control. Both are recorded in `DECISIONS.md`.
- **C5:** `vanilla-jars.csv` and `vanilla-smoke.csv` were restored, so the -9202 evidence chain is intact again.
- **C4 rationale:** archived in `env/cve-2024-4536-source-vector-note.md`.
- **The fixture is committed.**
- **`42_test_4536_dsp.sh` follows the right design:**
  - an iam-mock consumer sends a counterparty-controlled `dataDestination` over DSP;
  - PASS requires a receiver-seen sink write (positive control);
  - it aborts if `pilot08v` is not internal;
  - the receiver has `Content-Length: 42` plus `Connection: close`;
  - containers are removed at the end of a normal run.
- **The stale -4536 rows are gone.** `results/` holds only -9202.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| K1 | `42_test_4536_dsp.sh:50` (`cm catalogrequest`) | **Wrong catalog path on every rung.** v0.6.2 serves `@Path("/v2/catalog")` + `@Path("/request")`, and v0.9.1 serves `/v3/catalog/request`. `/management/vN/catalogrequest` returns 404, so the offer is empty. Under `set -euo pipefail` (from `lib.sh`), the `grep` pipeline in the `offer=$(…)` assignment then fails and kills the script with no row and no reason written. This is the most likely cause of the exit-4 run. | **H** | Use `catalog/request`. Make every probe assignment non-fatal (`|| true`), so that each failure becomes an `INVALID` row with a reason (`no-offer`, `no-agreement`, `no-transfer-id`). Never exit silently. |
| K2 | `42:73-79`; disk vs `env/vanilla-jars.csv` | **The jar sha is read from the CSV, not from the jar that runs.** The 0.6.x jars on disk are `78d1cb99…`/`ee1f4220…`, built at `60171df-dirty`, but the CSV says `82c1dd6d…`/`ef253e7d…`, so every 0.6.x row would cite the wrong jar. The 0.9.x jars predate the canary seeding, so they will always give `canary-not-seeded`. | **H** | Rebuild all four jars at a clean commit that contains the fixture. **Append** rows to `vanilla-jars.csv` (keep the -9202 rows). In 42, compute `sha256sum` of the jar actually copied into the run directory, and abort unless that (version, sha) pair is recorded (the same guard as G2 in `31_run_vanilla.sh:16`). |
| K3 | `42:72` | **Provenance marker.** 42 recomputes `COMMIT` itself and, like `lib.sh:10`, ignores untracked files. 42 is untracked right now, so a run today would be stamped clean `063723e`, a commit that does not contain the script that produced the row. | **H** | Delete the local recomputation and use `lib.sh`'s `COMMIT`. Fix `lib.sh:10` to treat untracked files as dirty (C8b). Commit 42 before any run whose rows are kept. |
| K4 | `42:69` (`leak_attempt` from the provider log) | C1 is only half done. FAIL still accepts a provider-log grep for `http://receiver:9300/token`. A provider that logs the incoming TransferRequest or DSP message body (which contains the tokenUrl) would produce a false FAIL on 0.6.3 and break the flip. | **H** | FAIL = receiver-seen `POST /token` (`token_post`) and/or the canary in the receiver capture (`leak_value`). Keep the log grep as an observation column only. Also record `src_get` (receiver saw `GET /data`). |
| K5 | `42:45-47` (`pm … >/dev/null`), `42:52-54` | **Seeding and DSP steps are not gated on their HTTP codes,** the J2 lesson from -9202. A 4xx on the asset, policy or contract definition turns into "no agreement" with no explanation. The offer is pulled out with a fragile regex and falls back to the literal `offer`. | M | Capture `-w '%{http_code}'` for seed_asset, seed_policy and seed_cd, and for catalog, negotiation and transfer. Gate the verdict on 2xx and record the codes in observations. Parse the offer with `jq` (`"$JQ"` from `lib.sh`): the `odrl:hasPolicy` `@id` of the dataset whose `@id` is `asset-4536`. |
| K6 | `42:62` (`sleep 12`), receiver `42:28-29` | Fixed waits. The transfer is asynchronous (negotiation already polls, the transfer does not), and the serial `nc` handles one connection at a time. | M | Poll `GET transferprocesses/{id}` until COMPLETED/TERMINATED (record the final state), then poll `/cap.txt` for the expected requests, with a timeout. Record `transfer_state`. |
| K7 | 0.9.x rungs; `provider.properties:16-17` | G5 is still open. The provider and consumer configs name `token-signer`/`token-verifier` aliases, but nothing seeds those keys. At 0.9.x, `data-plane-iam` and self-registration may need them, so the 0.9.x cells may come out `INVALID` (no sink write) for setup reasons. | M | Seed the key pair through the fixture (same code on every rung), the same way as the canary. Treat the positive control as the 0.9.x transfer smoke. |
| K8 | `42` error paths | Canary hygiene. Containers are removed only on the success path. On any `set -e` exit, the provider keeps the canary in `docker inspect`. There is still no `canary_in_provider_log` check (C9). | M | `trap 'docker rm -f pilot08v-provider pilot08v-consumer pilot08v-receiver >/dev/null 2>&1' EXIT`. Add `canary_in_provider_log` (yes/no, never printed); `yes` → `INVALID`. |
| K9 | `41_test_4536.sh` (committed) | The retired probe still writes to `results/cve-2024-4536.csv` and still says "Leak signal (reliable, from provider logs)". Running it would overwrite admissible rows. | M | Retarget its output to `env/cve-2024-4536-dataplane-probe.csv` (never `results/`). Add a header line: "NOT admissible (D7). Superseded by 42_test_4536_dsp.sh." |
| K10 | `VERSIONS.md:12` | Still says the patched PASS holds "vacuously … when the feature is **absent**", which contradicts D7(b): the PASS counts *because* the sink write still happens. | M | Reword it to D7(b): a removal fix whose PASS requires the positive control (sink write ran, no token POST, no canary). |
| K11 | `PILOT-REPORT.md:17,19,20,60` | Still stale: F3 and -4536 are "NOT STARTED", and there is no D7. C11/C12 are not done. | M | Update after the first clean ladder, or now with "IN PROGRESS, no admissible cells". Add D7 and the env note to the evidence index. |
| K12 | carried over | C10 (publish guard content check), D1 (SCOPE "checksum-verified"), D2 (ENV rows), D3 (egress probes on `pilot08v`), D4 (STATE.md, VERSIONS D5–D7 section) are untouched. | M | As in Review 5. C10 must land before KC2 starts. |

**Run procedure (applies to every admissible run from now on):**
1. Commit every script, fixture and config the run uses. `git status` must show nothing outside `env/` and `results/`. The run fails if `COMMIT` ends in `-dirty`.
2. Build the jars only from that clean commit. Append the (version, sha, commit) rows. Each test checks the sha of the jar it actually runs against those rows.
3. Run all four rungs **in one batch**, one rung per background job, from the same commit and the same jar set. Never mix rows from different commits or jar sets in one ladder.
4. Every step records its HTTP code, and every failure becomes `INVALID` with a reason. A script must never exit without writing its row.
5. Verdicts come only from receiver-side or API-response evidence. Log greps are observations.
6. After the batch: commit `results/` and `env/` together in one evidence commit whose message quotes the ladder. Do not claim admission in the message unless all four cells match the predicted pattern **and** every PASS has its positive control.
7. Then re-run `40_test_9202.sh` on the same jar set (C5 follow-up), so that KC1 is decided on one jar set and one commit.
8. Do not run `90_publish.sh` while anything is uncommitted or dirty. Publishing stays the user's call per phase.
9. If something fails, diagnose from the captured codes and observations before changing the test, and write down why each change is made **before** re-running. Do not change the vector or oracle after seeing a result without recording the reason in `DECISIONS.md` (as was done for D7).

**Verdict:**
- **Direction:** correct. The DSP-driven design matches D5/D7, and the user decided D7 properly.
- **Readiness:** 42 does not yet run end to end. The catalog path is wrong (K1), the jar sha is untraced (K2), the provenance stamp would be false (K3), and FAIL can still come from a log echo (K4). All four are small fixes.
- **KC1:** cannot be decided yet. It needs a clean four-cell -4536 ladder that passes the procedure above, plus a -9202 re-run on the same jars.
- **Timebox:** on track. The 0.9.x key seeding (K7) is the main remaining risk.

---

## Review 7 (post-2388a19), completed 2026-10-24

Scope: `1634216`, `d305006`, `8306336`, `e62e056`, `1110855`, plus the uncommitted `scripts/42_test_4536_dsp.sh` (negotiation now waits for FINALIZED, adds errorDetail and agreement diagnostics) and `env/vanilla-jars.csv` (8 more duplicate rows). The public mirror's latest 12 commits were checked read-only. 0.6.2 and 0.9.1 behaviour was read from the source clones in `build/connector-062` and `build/connector-091`. Read-only: no Docker, no downloads, no pushes.

**Done and correct:**
- **Review 6 items closed:** K1 (`catalog/request`), K3 (`lib.sh` dirty marker counts untracked files), K4 (verdict from the receiver; the log grep is an observation), K5 (HTTP codes plus jq offer parsing), K8 (EXIT trap, `canary_in_log`), K9 (41 writes to `env/` only).
- **D8 dependency verification is sound.**
  - 1416 artifacts are pinned with sha1 and sha256.
  - Every sha1 matched a publisher `.sha1` (0 mismatches, 0 missing).
  - Strict builds pass on all four rungs.
  - The tamper control was detected.
  - The jar shas reproduce byte-identically across clean rebuilds.
  - SCOPE's "checksum-verified" now holds. It is checksum-only with no PGP, and ENV says so.
- **Canary scan:** 0 files under the Claude task-output directories on this host contain a `pilot08-canary-<32 hex>` value. Only the pattern was counted; no value was printed.
- **Public mirror:** none of the latest 12 commits carries a Co-Authored-By line.

**Correction to the abbreviated L1:** data-plane registration is **not** the root cause at 0.6.2. `ProviderPushTransferDataFlowController` (0.6.2) uses the **embedded** data-plane client (`DataPlaneClientExtension.java:54-57`, used whenever a `DataPlaneManager` is in the runtime), and `RandomSelectionStrategy` returns null on an empty list, so a push starts without a registered instance. The error is raised in `TransferProcessManagerImpl.processInitial` (`:186-191`), which runs on **both** sides and terminates the process when `policyArchive.findPolicyForContract(contractId)` is null. The pilot's earlier run sent the transfer while the consumer negotiation was still `REQUESTED`, before the agreement and its policy were stored. The uncommitted wait-for-FINALIZED change addresses exactly this. Registration remains useful for a different reason: without it the catalog advertises no `HttpData-PUSH` distribution, so 0.6.x and 0.9.x would not see symmetric offers.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| L1 | `42:73-80` (uncommitted) | The transfer started before the agreement existed (see correction). The fix is uncommitted, and the fixed `sleep 3` is not a gate. | **H** | Gate the transfer on all three: consumer negotiation `state == FINALIZED`, `contractAgreementId` non-empty, and the provider's `GET /management/$PV/contractagreements/{id}` = 200. Poll each with a timeout and drop the sleep. Record `neg_state` and `agreement_on_provider` in observations. Otherwise → `INVALID(no-agreement-on-provider)`. |
| L2 | `42:22-25,40-43` vs `:63,98-104` | **The canary `set +x` guards are incomplete.** Unguarded expansions: `cap="$(…)"` (holds `client_secret=<canary>` at 0.6.2), every `printf '%s' "$cap"`, both `grep -qF "$CANARY"`, and the `docker logs … | tail -3` diagnostic printed to stdout. | **H** | At the top of 42: `case $- in *x*) echo "refusing to run under -x"; exit 1;; esac`, then remove the per-line guards. Send every diagnostic line to stdout only through `redact() { sed "s/$CANARY/<redacted>/g"; }`. Note the PID-548 trace incident in `ENV.md` (no value): "task outputs scanned 2026-10-24: 0 files contain a canary-pattern value". |
| L3 | `42` rung parity | **Exact per-rung flow (verified in source).** Management API versions: 0.6.x = `v3/assets`, and `v2` for policydefinitions, contractdefinitions, `catalog/request`, contractnegotiations, contractagreements, transferprocesses and dataplanes. 0.9.x = `v3` for all of these (v2 also still served). `transferType` = `HttpData-PUSH` on both lines. At 0.9.x it is parsed by `DataPlaneSignalingFlowController.canHandle` (`:72-73`) and needs a selected data plane (`select(...)`, `:88`, FATAL if none). `data-plane-self-registration` provides that, registering `allowedTransferTypes` including `HttpData-PUSH` from the HttpData sink (`DataplaneSelfRegistrationExtension.java:81-90`). The client is embedded on both lines (`DataPlaneSignalingClientExtension.java:63`), so the registered URL is not dialled. | M | At 0.6.x, before the catalog step, register the provider data plane for offer symmetry: `POST /management/v2/dataplanes` with `{"@context":{"edc":"https://w3id.org/edc/v0.0.1/ns/"},"@id":"dp-provider","edc:url":"http://provider:8383/control/transfer","edc:allowedSourceTypes":["HttpData"],"edc:allowedDestTypes":["HttpData"],"edc:allowedTransferTypes":["HttpData-PUSH"]}` (shape from `system-tests/e2e-transfer-test/.../TransferEndToEndParticipant.java:88-103`). Gate on 200 and record `dp_reg`. At 0.9.x, do not register manually. Instead record `GET /management/v3/dataplanes` = 200 with an instance whose `allowedTransferTypes` contains `HttpData-PUSH` (`dp_reg=self`). Record each rung's catalog `dct:format` list as `push_offered=yes/no`. Set `edc.hostname=provider`/`consumer` in both properties files so callbacks and self-registration do not default to `localhost`. |
| L4 | K7 (Review 6) | **Downgraded.** At 0.9.x `data-plane-iam`'s token keys (`DataPlaneIamDefaultServicesExtension.java:38-41,63-71`) back the access-token service used for **PULL** EDRs. A PUSH flow does not mint tokens, and the aliases are configured, so boot does not fail. | L | Do not seed keys unless a 0.9.x PUSH start fails with a key-resolution error. If one does, seed through the fixture on every rung and record why. |
| L5 | `env/vanilla-jars.csv` (uncommitted) | Every rebuild appends 4 identical rows, one set at `d305006-dirty`, and the sha guard (`42:24`) accepts a sha recorded only at a dirty commit. | M | Do not append a (version, sha) pair that is already recorded at a clean commit. Make the guard require a clean-commit row (`grep -E "^$V,$sha,[0-9a-f]{7},"`). Discard the 8 uncommitted duplicate rows. |
| L6 | `scripts/32_gradle_verify.sh:41-46` | The cross-check accepts a match against **either** Maven Central **or** the Plugin Portal for every artifact. The one legitimate Portal case is the shadow plugin, whose marker pom differs between the two. Accepting both for everything weakens the check for ordinary Maven Central dependencies. | M | Accept the Portal only for `com.gradleup.shadow*` (plugin marker and plugin artifacts). Everything else must match Maven Central. Re-run the cross-check only (no rebuild) and update `env/gradle-verification.csv`. |
| L7 | `VERSIONS.md:12,28,84`; `PILOT-REPORT.md:17,19,20,60` | K10/K11 not done. VERSIONS still says -4536 PASSes "vacuously … when the feature is absent", contradicting D7(b). The report still has F3/-4536 "NOT STARTED", says "negotiated over DSP" with no D7, and has no D8 or evidence-index entries. | M | VERSIONS: replace `:12` with the D7(b) wording (PASS counts only with the positive control) and keep `:28/:84` for -8642. Report: F3 DONE, -4536 "IN PROGRESS (DSP-driven, D7), no admissible cells", KC1 PENDING. Index: D7, D8, `gradle-verification.csv`, the source-vector note, `cve-2024-4536-dataplane-probe.csv`. |
| L8 | `scripts/90_publish.sh:30-32` | C10 is not done: the guard checks paths only. | M | Before KC2 starts: refuse a patch that adds a `FAIL` row for a version outside 0.6.2/0.6.3/0.9.0/0.9.1, or whose diff or commit message matches `candidate|undisclosed|new violation` (case-insensitive). Print the commit list and require `--yes`. |
| L9 | `ENV.md:65,67,68`; `docs/STATE.md:53`; VERSIONS | D2/D4 docs are still open. ENV:65 says the Plugin Portal is "pending user OK" (approved in D6). ENV:68 has the Samples clone unpinned. ENV:67 and the 091 clone have no commit SHA. STATE:53 says "built from source". VERSIONS has no D5–D8 section. | L | Fix the wording, add the clone SHAs (`git -C build/connector-0xx rev-parse HEAD`), and pin or remove Samples. |

**Per-cell oracle for the -4536 ladder.** Every cell needs: seeded=yes, all seeds 2xx, catalog 200, an offer, neg_state=FINALIZED, agreement_on_provider=200, a transfer id, src_get=yes, canary_in_log=no. A failure in any of these makes the cell `INVALID(<reason>)`.

| Rung | Expected verdict | transfer_state | src_get | token_post | canary_value | sink_write | Why |
|---|---|---|---|---|---|---|---|
| 0.6.2 | **FAIL** | any (TERMINATED is fine) | yes | **yes** | **yes** (expected; token_post alone suffices) | any | The sink OAuth2 decorator resolves the consumer-named alias from the provider vault and POSTs it to the consumer tokenUrl. |
| 0.6.3 | **PASS** | STARTED/COMPLETED | yes | **no** | **no** | **yes** (positive control) | Sink decorator removed (fix `a4e6018`). The same OAuth2 destination is written without a token request. |
| 0.9.0 | **PASS** | STARTED/COMPLETED | yes | **no** | **no** | **yes** | The sink path is still absent. Signaling plus self-registered data plane. |
| 0.9.1 | **PASS** | STARTED/COMPLETED | yes | **no** | **no** | **yes** | As 0.9.0. |

A PASS cell without `sink_write=yes` is `INVALID`, never PASS (D6/D7b). If 0.6.2 shows `src_get=yes` but no `token_post`, the cell is a genuine non-reproduction, not INVALID: record it and stop, because KC1 would then fail.

**Run procedure (one batch, one clean commit):**
1. **Prepare.** Land L1–L3 (and L5/L6) in `42`, the properties files and `32`. Commit them, and confirm `COMMIT` has no `-dirty`.
2. **Jars.** Confirm the four jar shas are recorded at a clean commit. Do not rebuild: the sources are unchanged and builds reproduce. The test checks the sha of the jar it runs.
3. **-4536 ladder.** Run `42` for 0.6.2, 0.6.3, 0.9.0 and 0.9.1 in one batch (sequential, since they share `pilot08v` container names). Do not edit anything mid-batch. If any cell is INVALID, fix the cause, commit, and re-run **all four**.
4. **-9202 re-run.** Run `40_test_9202.sh` on the same four jars from the same commit. It must reproduce FAIL/FAIL/FAIL/PASS with its positive controls.
5. **Evidence commit.** One commit containing `results/cve-2024-4536.csv`, `results/cve-2024-9202.csv` and both observation files, with the two ladders in the message. Say "KC1 PASSED" only if -4536 reads FAIL/PASS/PASS/PASS per the oracle above **and** -9202 reproduces. Otherwise state which condition failed. Under SCOPE, a KC1 failure means stopping the DSP half and reporting.
6. **Report.** Update `PILOT-REPORT.md` (status, KC1 verdict, evidence index) and VERSIONS (L7) in a separate commit. Every number must trace to those CSVs.
7. **Publish.** Publishing is the user's call. Run `90_publish.sh` only on a clean tree after the user says so, and land L8 before any KC2 work.

**Verdict:**
- **Closed:** the Review 6 harness fixes and D8 are done, and D8 is sound.
- **Remaining for -4536:** gate the transfer on a provider-confirmed agreement (L1), make the canary trace-proof (L2), and run the exact per-rung flow (L3). These are concrete fixes, not method risk.
- **Open user decision:** none.
- **KC1:** still undecided. It is decided by the batch in steps 3–5.

---

## Review 8 (post-a69b8fd), 2026-10-24

Scope: `5c8f261`, `f7ab769`, `b38f9a9`, `659c835`, `c11d50a`, plus the uncommitted `results/cve-2024-4536.csv` and `env/cve-2024-4536-observations.csv`, and the pilot transcript up to its session-limit stop. Read-only: no Docker, no downloads, no pushes.

**-4536 ladder (uncommitted, clean `c11d50a`, recorded jars):** 0.6.2 **FAIL** / 0.6.3 **PASS** / 0.9.0 **PASS** / 0.9.1 **PASS**. It matches the Review 7 per-cell oracle on every cell:
- **Every cell:** seeds 200, `dp_reg` yes (0.6.x) / self (0.9.x), catalog 200, `push_offered` yes, `neg_state` FINALIZED, `agreement_on_provider` yes, `src_get` yes, `canary_in_log` no.
- **0.6.2:** `token_post` = yes, `canary_value` = yes, `sink_write` = yes, COMPLETED. The vulnerable path does not abort after the token call; it completes the authenticated sink write.
- **0.6.3 / 0.9.x:** `sink_write` = yes (positive control), `token_post` = no, `canary_value` = no.
- **Jar shas:** match clean-commit rows in `vanilla-jars.csv`.
- **Result:** the flip happens exactly at 0.6.3, and every PASS has its positive control. **Subject to H1–H2 below, -4536 meets the admission rule.**

**Done and correct:**
- **L1:** the transfer is gated on a provider-archived agreement.
- **L2:** the script refuses `-x`, and `redact()` is applied to every diagnostic.
- **L3:** per-rung data-plane registration, `push_offered`, and `edc.hostname`.
- **L5:** the guard in `42` accepts only a sha recorded at a clean commit.
- **L6:** the Portal is accepted only for shadow artifacts.
- **L7:** VERSIONS has the D7(b) wording and a D5–D8 section.
- **L9:** ENV clone SHAs, Samples pinned.
- **Receiver:** the concurrent JDK `HttpServer` (`testbed/receiver/Receiver.java`) fixed the dropped sink write. That was a real harness defect, and the positive control was **not** relaxed.
- **Canary hygiene:** the pilot re-scanned task outputs and found them clean.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| H1 | `scripts/31_run_vanilla.sh:14-17` | **The -9202 "boot failed" is a sha-guard bug, not a resource wall.** `vanilla-jars.csv` is now append-only (13 rows, several per version), so `want="$(grep "^$V," … \| cut -d, -f2)"` returns **multiple lines**. `[ "$want" != "$got" ]` is then always true, and 31 exits "sha256 mismatch". `40_test_9202.sh:17` swallows that output (`>/dev/null 2>&1`) and prints "boot failed". The pilot's resource-exhaustion explanation is wrong, and running the ladders separately will **not** fix it. | **H** | Replace lines 14-17 with the same presence check as 42: `got=$(sha256sum "$jar" \| cut -d' ' -f1)`, then `grep -qE "^$V,$got,[0-9]+,[0-9a-f]{7}," env/vanilla-jars.csv \|\| { echo "jar sha $got for $V not recorded at a clean commit"; exit 1; }`. Make `40_test_9202.sh:16` use the same clean-commit regex. Stop `40:17` discarding 31's output: `… 2>&1 \| tail -5` on failure. `41_test_4536.sh:24` has the same multi-row bug; fix it as well, or mark 41 retired. |
| H2 | `results/`, `env/` (uncommitted) | The -4536 evidence is still uncommitted, and **-9202 has not been re-run on this jar set**. `results/cve-2024-9202.csv` cites the old jars (`82c1…`, `ef25…`, `2b93…`, `2066…`), and none of those jars exist on disk any more. KC1 must be decided on one jar set. | **H** | After H1, and with HEAD still at `c11d50a` (the untracked evidence files are excluded from the dirty marker, so the stamp stays clean), run `40_test_9202.sh` for 0.6.2, 0.6.3, 0.9.0 and 0.9.1 sequentially. It must reproduce FAIL/FAIL/FAIL/PASS with seeds 2xx, alice's positive control and mallory hidden. Then make **one** evidence commit with both results CSVs and both observation files, quoting both ladders. Write "KC1 PASSED (2 of 3; -8642 not counted per D6)" only if both ladders hold. If -9202 does not reproduce, report that and do not claim KC1. |
| M1 | `scripts/90_publish.sh` (L8) | The content guard scans only `results/` and `env/` hunks. It skips commit messages and docs, so a candidate finding written into `PILOT-REPORT.md`, `VERSIONS.md`, a review file or a commit message would still publish. KC2 makes this real. | M | Also scan every changed `*.md` hunk and each commit message (the patch header up to the first `diff --git`). Exclude only lines in `90_publish.sh` itself, which is what triggers self-matches. Document that `--yes` is the user's call per publish. |
| M2 | `PILOT-REPORT.md:17-20,56-60` | The report is still stale (K11/L7 report part): F3 and -4536 "NOT STARTED", KC1 "-4536 not started", §2 framed as Tractus-X, no D7/D8. | M | Do this after the evidence commit, in a separate report commit. Status: F3 DONE. -4536 ADMITTED with its ladder, commit and the observation columns that make up the oracle. -9202 re-confirmed on the new jar set. KC1 verdict with D6 noted. Evidence index: both results/observation CSVs, `gradle-verification.csv`, the source-vector note, `Receiver.java`, D7/D8. Every number must trace to a CSV. |
| L1 | `results/cve-2024-4536.csv` invariant label | `vault-scoping[CVE-2024-4536]` uses brackets, while -9202 uses `catalogue-visibility(CVE-2024-9202)`. | L | Use one style before the evidence commit (parentheses, as committed for -9202). |
| L2 | `42:122` | A residual `sleep 6` comes after the poll loop. It is harmless (the poll already gates on the sink write), but it is not a gate. | L | Keep it or drop it, and note it as settle time. No re-run needed for this alone. |

**What to do next, in order:**
1. **Fix H1** in 31/40 (and 41). Commit on a clean tree. This makes HEAD a new commit; that is fine because only scripts not used by 42 change. Re-run the -4536 ladder from the new HEAD too, so both ladders cite one commit. It is cheap and avoids a mixed-commit KC1.
2. **Run** -4536 (×4), then -9202 (×4), sequentially, from that one clean commit, on the same four jars.
3. **Make one evidence commit** with the ladders in the message, and claim KC1 only per H2.
4. **Make the report commit** (M2) and fix the label (L1).
5. **Fix M1** before any KC2 work.
6. **Publishing is the user's call** after steps 3–4. Run `90_publish.sh` only on a clean tree and only when the user asks.

**Verdict:**
- **-4536:** the mechanism and oracle are now sound, and the ladder reads FAIL/PASS/PASS/PASS with every control in place. That is a clean rediscovery on its own evidence.
- **KC1 is not yet decidable.** The -9202 re-run on the same jar set is blocked by a one-line sha-guard bug (H1), not by resources.
- **Timeline:** once H1 is fixed, KC1 can be decided in the next batch.

---

## Review 9 (post-d1eb49b), 2026-10-24: hung KC1 batch

Scope: `4df5f58` (H1 sha-guard fix, wider publish guard), `08ac056` (D9: manual per-phase push, publish script retired), the pilot's batch runner `run_both.sh` (in the pilot's scratchpad, untracked), its output, and the live process table. Read-only: I did not touch Docker or kill any process.

**Done and correct:**
- **H1 fixed:** the clean-commit sha guard is now in 31 and 40.
- **D9 recorded and pushed by hand:** authz-ladder `8198bc9..3d384ff`. Every commit has author and committer ftaakash and no Co-Authored-By trailer. The "Co-Authored-By" in `08ac056`'s body is prose describing the rule, not a trailer.
- **0.6.2 cell:** written at 18:28 and correct (FAIL: token_post and canary yes, sink write yes, FINALIZED, agreement on provider).

**What happened:**
- Docker's engine pipe was down when the batch started ("failed to connect to the docker API … dockerDesktopLinuxEngine").
- `lib.sh:require_docker` launched `Docker Desktop.exe … &` **from inside `42_test_4536_dsp.sh`**. Under Git Bash/MSYS, the script process (PID 574) cannot exit while that native child (PID 576) lives.
- So 0.6.2 finished and wrote its row, but PID 574 never terminated. `run_both.sh` pipes each test into `| tail -2`, which waits for EOF and has blocked since 18:28. The 0.6.3–0.9.1 and -9202 cells never ran.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| N1 | `scripts/lib.sh` `require_docker` | **A test script must never start Docker.** Starting Docker Desktop as a background child ties the test process's lifetime to Docker Desktop (MSYS keeps the parent alive). Any caller that pipes or waits on the test then hangs. This is also the likely cause of the earlier unexplained exit-4 and hangs after "engine auto-start via lib.sh". | **H** | `require_docker` should only check: `docker info >/dev/null 2>&1 \|\| { echo "docker engine not available, start Docker Desktop and re-run" >&2; exit 3; }`. Remove the auto-start. Start Docker once, outside any test, before a batch. If it must be scripted, detach it fully, e.g. `powershell -NoProfile -Command "Start-Process -FilePath '<Docker Desktop.exe>'"`, then wait for `docker info`. |
| N2 | `run_both.sh` (pilot scratchpad) | **The runner deletes committed evidence.** `rm -f results/cve-2024-9202.csv env/cve-2024-9202-observations.csv` removed the tracked -9202 files, and they are now `D` in the working tree. If the rerun fails and the tree is committed, the -9202 admission evidence is lost. The tests already replace their own version's row, so the `rm` is unnecessary. | **H** | `git restore pilots/08-dsp-authfuzz/results/cve-2024-9202.csv pilots/08-dsp-authfuzz/env/cve-2024-9202-observations.csv` now. Never `rm` tracked evidence. |
| N3 | runner location and design | The batch driver is an untracked file outside the repo, so it is neither reproducible nor covered by the dirty marker. `\| tail -2` hides every diagnostic, and there is no per-rung timeout. | M | Commit it as `scripts/50_kc1_batch.sh`. **Pre-flight:** check `docker info`, check that `pilot08v` is internal, check the tree is clean (no `-dirty`), record HEAD. **Per rung:** `timeout 900 bash scripts/42_… "$V" > build/logs/4536-$V.log 2>&1` (the logs are already canary-redacted; `build/` is gitignored), record the exit code, and on non-zero print `tail -5` of the log. **Abort** if HEAD changes mid-batch. Clean the `pilot08v` containers between rungs. Never delete evidence files. |
| N4 | batch vs D9 push | `08ac056` was committed and pushed **during** the batch (the batch started at `4df5f58`). Later rungs would have stamped `08ac056`, giving a mixed-commit ladder. | M | Rule: no commits or pushes while a batch runs. Commit `50_kc1_batch.sh` and N1 first, then run the whole batch (-4536 ×4, then -9202 ×4) from that one HEAD. |

**Pilot steps, in order:**
1. **Stop the stuck run.** Stop your background task `bzj0beeqn`; its processes are runner 551/552, 42 PID 574 and its child 576. Docker Desktop may close with it, which is fine. Then `docker ps -aq --filter name=pilot08v | xargs -r docker rm -f` once Docker is up.
2. **Restore the -9202 files** (N2).
3. **Land N1 and N3 in one commit** and push it per D9.
4. **Prepare the batch.** Start Docker Desktop yourself (detached) and wait for `docker info`.
5. **Run the batch.** Run `50_kc1_batch.sh` from that HEAD, with no commits during the run.
6. **Commit and push the evidence**, with both ladders in the message and the KC1 claim per Review 8 H2. Then push per D9.
7. **Commit and push the report** (Review 8 M2), then push per D9.

**Verdict:** this is a harness and environment hang, not a test result. The 0.6.2 cell is valid, but it must be re-run inside the clean batch so that all eight cells share one commit. Once N1–N4 land, KC1 is decided by the next batch.

---

## Review 10 (post-34183ca), 2026-10-24: KC1 verdict check

Scope: `559c51f` (lib.sh never starts Docker, `50_kc1_batch.sh`), `7396b84` (KC1 evidence), `3805146` (report), `2c3aa4e` (smoke refresh), the per-rung logs in `build/logs/`, the public mirror (read-only), and the live process table. Read-only.

**KC1 verdict confirmed: PASSED (2 of 3; -8642 not counted per D6, so no margin).**
- **One commit, one jar set:** all 8 cells come from clean `559c51f` on the same four jars (`78d1…`, `ee1f…`, `b83b…`, `0f54…`), each recorded at a clean commit. `50_kc1_batch.sh` refuses a dirty tree, aborts if HEAD moves, and never deletes evidence.
- **-4536:** FAIL / PASS / PASS / PASS.
  - Every cell has seeds 200, catalog 200, an offer, `neg_state` FINALIZED, `agreement_on_provider` yes, `src_get` yes and `canary_in_log` no.
  - 0.6.2 has `token_post` = yes and `canary_value` = yes.
  - 0.6.3, 0.9.0 and 0.9.1 have `sink_write` = yes (positive control) with no token and no canary.
  - The flip is exactly at 0.6.3.
- **-9202:** FAIL / FAIL / FAIL / PASS, re-confirmed on the new jars.
  - Seeds are 200 on every rung, alice sees the dataset and fetches it (positive control) everywhere, and mallory is hidden from the catalogue.
  - mallory gets 200 plus the dataset on the affected rungs and 404 at 0.9.1.
- **Canary:** 0 of the 8 batch logs contain a canary value.
- **Report:** the `PILOT-REPORT.md` status rows trace to these CSVs and the evidence commit.
- **Public mirror:** `7332ccb` = local `2c3aa4e`, and the marker is in sync. Every commit has author and committer ftaakash and none has a `Co-Authored-By:` trailer.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| P1 | process table | **The old hung runner is still alive:** `run_both.sh` (PIDs 551/552) and `42_test_4536_dsp.sh 0.6.2` (PID 574, holding the Docker Desktop child 576), all from 18:27. If Docker Desktop restarts or exits, PID 574 ends, `\| tail -2` unblocks, and the runner **resumes**. It would then run 42 for 0.6.3–0.9.1 and 40 for all four rungs, overwriting the committed result rows with rows stamped at a later commit, and creating `pilot08v` containers. | **H** | Kill the runner and its stale test now: `kill 552 551 574` from Git Bash (or `taskkill` by their Windows PIDs). Check with `ps -ef \| grep -E "run_both\|42_test"`, then `git status` (it must stay clean). |
| P2 | `env/net-isolation.csv` vs `pilot08v` | **D3 is still open:** the egress probe and its positive control were archived for R1/`pilot08_dsp` only. The KC1 runs used `pilot08v`, which is checked `Internal=true` but has never been probed. SCOPE's local-only claim for KC1 rests on a flag, not a measurement. | M | Port the `05_net_check.sh` probes (positive control to a peer container, IP `1.1.1.1`, DNS `example.com`, published ports = 0) to `pilot08v`. Append them to `env/net-isolation.csv` with a `network` column, commit, and push per D9. |
| P3 | `PILOT-REPORT.md` §2–§4 | The historical sections still read as current: "KC1 blocker", "Decision needed", and the Tractus-X framing. The KC1 claim must read "Eclipse EDC (vanilla, Maven Central artifacts, iam-mock)", not Tractus-X (D5/D6). | L | Add a one-line "historical (superseded by D5–D7)" header to §2–§4, and one sentence in the status table giving the KC1 claim scope. |

**Next phases need the user's decision; the pilot must not start any of them on its own:**
1. **KC2** (new invariant violations on current EDC/Tractus-X). It needs option A, the local DCP/DIM identity stack, and it will produce undisclosed candidate findings. Those must go in gitignored notes and be held out of the per-phase push.
2. **The MCP scoping step** (SCOPE "MCP half", step 6). This is reading only: list which idea-01 scenarios the MCP conformance-draft auth scenarios already cover. No harness is built without approval.
3. **`docs/STATE.md`** lies outside `pilots/`, so changing it needs the user's OK ("built from source" → "assembled from Maven Central artifacts").

**Verdict:** kill condition 1 is decided, PASSED on clean, controlled, traceable evidence, and the DSP half continues. Before anything else, kill the orphaned runner (P1). Then close D3 (P2). After that the pilot waits for the user's choice of next phase.

---

## Review 11 (KC2 session, post-ef84d13), 2026-10-24

Scope: the KC2 session's commits `28c84de` through `41ac249` (P2/P3 close-out, KC2 phase 1 target pins, phase 2 identity-stack scaffold), `kc2/` (pins, scripts, `env/`, identity launcher), the D10 entries, and the KC2 transcript up to its checkpoint question. Read-only: no Docker, no downloads, no pushes.

**Done and correct:**
- **P2/D3 closed:** `pilot08v` egress is probed with a positive control; egress is blocked and no host ports are published. **P3 closed:** the claim scope reads "Eclipse EDC", and §2–4 are marked historical.
- **Phase 1 targets** are the latest stable releases (Tractus-X 0.13.0, which bundles EDC 0.17.0; vanilla EDC 0.18.1), pinned by digest and BOM checksum. Pre-releases are excluded and the reason is recorded. The image digest matches and the runtime jar sha256 is archived (`kc2/env/targets.csv`). Downloads are logged in ENV.md.
- **Phase 2 identity stack:** real Eclipse components (IdentityHub + IssuerService from Maven Central BOMs at 0.17.0, official `bdrs-server-memory:0.6.0` by digest), not a hand-rolled mock. The jars are reproducible and stamped at a clean commit.
- **Pushes:** phase 1 was pushed. Phase 2 commits are held locally until the phase completes, which is consistent with D9.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| Q1 | (missing) | **No frozen invariant catalogue for KC2.** KC2 counts "new invariant violations after the full invariant set". The set has to be fixed and committed **before** any test touches the current targets; otherwise anything found is post hoc and the count is not falsifiable. | **H** | Before phase 3, write `kc2/INVARIANTS.md`: each invariant's ID, spec or advisory source, pass/fail assertion, positive control and expected oracle. Commit and push it as its own phase ("KC2 design freeze"). After the freeze, adding an invariant needs a DECISIONS entry with a reason, and it is reported separately from the frozen set. |
| Q2 | KC2 plan | **The TCK precondition is not planned.** The safe sentence counts violations "in implementations that pass the official DSP TCK". Without a TCK run on each target, any violation can only be reported as "in current releases", not "in TCK-passing builds". | **H** | Add a phase that runs the official DSP TCK (v1.0.2, plus DCP TCK v1.2.1 for the identity layer) against each target, and archive pass/fail per test in `kc2/env/`. If the TCK artifacts come from a source not yet used by the pilot, ask the user first (SCOPE "Still ask first"). If a target fails the TCK, record it and narrow the claim wording; do not drop the target silently. |
| Q3 | results routing | **KC2 verdict rows must not reach public history.** Every FAIL on a current release is an undisclosed candidate finding, and D9 pushes each phase. The manual check is the only barrier, and the KC1 layout writes verdicts to `results/`, which is tracked and pushed. | **H** | Route all KC2 verdict and observation rows, tests that FAIL, and finding notes to `pilots/08-dsp-authfuzz/private/kc2/`, which is gitignored by `pilots/**/private/`. Publish only harness code that encodes no finding, plus aggregate counts once the user approves. Commit messages must not describe findings. Make `kc2/` scripts write to `private/` by default, and refuse to write KC2 rows under `results/`. Disclosure stays the user's call: Eclipse security process, 90-day embargo. |
| Q4 | `DECISIONS.md:14,16` | **Duplicate decision ID.** D10 is used twice: MCP defer, committed 20:55, and the KC2 identity stack, committed 20:59. | M | Renumber the identity-stack entry to **D11**, and fix any reference to it ("log D10" in `c1c532b`'s message cannot change; note the renumbering in the D11 row). |
| Q5 | `kc2/identity/` | **No dependency verification for the KC2 builds.** D8 covers only `testbed/launcher`. The identity launcher and the coming vanilla 0.18.1 connector pull hundreds of unverified Maven artifacts. | M | Add `kc2/identity/gradle/verification-metadata.xml` (sha1 + sha256) and cross-check it with `32_gradle_verify.sh`, generalised to take a launcher directory. Do the same for the 0.18.1 launcher. Record the results in `kc2/env/gradle-verification.csv`. |
| Q6 | identity secrets | The identity stack will generate participant keypairs, issuer keys and credentials. | M | Keep all generated keys and seeded credentials under gitignored paths (`testbed/.secrets/` or `private/`). Check `git status --ignored` before each commit. Never print private keys in logs. |
| Q7 | `ENV.md:142` | "bundled EDC 0.17.0 … not re-verified in the binary." | L | Read the EDC version from the 0.13.0 jar (`META-INF/maven/.../pom.properties`, or a core class's package version) and record it in `kc2/env/targets.csv`. |

**Open question to the user (I am not answering it):** the KC2 session asked whether to continue straight through the phase 2 integration or to checkpoint at the next milestone. Reviewer recommendation: checkpoint once all five services boot on an internal network, did:web resolves, and a DSP catalogue request returns 200 with real DCP tokens (positive control) **and** is refused without them (negative control). Q1–Q3 must land before phase 3 in any case.

**Verdict:** KC2 is set up soundly so far: real components, pinned and evidenced, and nothing has been tested against current releases yet, so no finding exists or is at risk. Three structural gaps must close before any KC2 test runs: the frozen invariant set (Q1), the TCK precondition (Q2) and private result routing (Q3). Without them, KC2's outcome would be neither falsifiable nor safely publishable.

---

## Review 12 (KC2 phase-2 checkpoint), 2026-10-24

Scope: `cf2344e` through `97c3577`, with the focus on `107586f`, `caf0632`, `308bb74`, `5bf4eae` and `97c3577`. Also read: `kc2/identity/src/main/java/pilot08kc2/Kc2SeedExtension.java`, `kc2/scripts/05,10,12,20,30`, `kc2/env/*.csv`, `kc2/env/targets-notes.md`, D11 and its amendment, and the public mirror tree via read-only `gh api`. No Docker, no downloads, no pushes.

**Milestone line held (confirmed in code):**
- `Kc2SeedExtension` only calls `IdentityHubParticipantContextService.createParticipantContext` with a single key descriptor (Ed25519, generated by IdentityHub) and the participant DID. It contains no VC, credential-store or issuer call.
- `30_up_identity.sh` boots 2 IdentityHubs, the IssuerService and BDRS, then reads readiness, the two `did.json` documents and their key curve. It makes no issuance, credential seeding, BDRS registration or connector/DCP call.

**Secrets (confirmed independently):**
- No tracked file matches key or secret patterns, and `git grep` finds no PEM private-key header and no JWK `"d"` member.
- `testbed/.secrets/` and `private/` are ignored (`.gitignore:14`, `:7`).
- The mirror tree has no secret, private, `.pem`, `.key` or candidate paths.
- The AES config key is generated at runtime (`SecureRandom`, 32 bytes) into the in-memory vault, and only its alias is logged. No key material is hardcoded.
- Management API keys such as `pilot08k2-bdrs-mgmt` are test values for the local-only testbed. They are tracked and public, which is acceptable under the testing rules, but they must never be reused anywhere else.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| R1 | `kc2/env/net-isolation.csv` (all rows at `05a7d05`) | **Isolation predates the services.** The probe ran at 21:24 with only a busybox peer on `pilot08k2_dsp`. The identity services came up at `308bb74` (22:34), so `host_published_ports=0` was measured with nothing running and is vacuous for the current topology. | **H** | Before any seeding, issuance or handshake, re-run `kc2/scripts/05_net_check.sh` on a clean commit **with all five services up** (2 IdentityHubs, the issuer, BDRS and the peer). Append rows with a `services_up` column (count plus names). Also add an egress probe run from inside one IdentityHub container (`docker exec … curl`/`wget` if the image has it, with the peer as a positive control in the same exec). Gate every later phase on that row set. |
| R2 | `308bb74` message; `kc2/env/identity-smoke.csv` | **"did:web cross-resolution 8/8" overstates the evidence.** Four rows are readiness checks. The four DID rows fetch each `did.json` from a **third** driver container and read the key curve. That shows both DIDs are served on the internal network; it does not show participant-to-participant resolution. | M | Correct the wording in the report/ENV (the commit message cannot change): "both DID documents served on the internal network (4 checks) + 4 service-readiness checks". Add real cross-resolution rows: from inside `pilot08k2-provider-ih`, fetch the consumer DID URL, and the reverse. Also check that each document's `id` equals the configured DID. Add a secrets row, `did_no_private_member=yes`: no `d` in any `publicKeyJwk`. |
| R3 | `kc2/env/gradle-verification.csv` (row at `107586f`) vs `caf0632` | **The verification evidence predates the metadata it describes.** `caf0632` refreshed `verification-metadata.xml` for the changed launcher (aes-encryption + seed SPIs), but the only cross-check row is stamped `107586f`. The 568-artifact count and the tamper result describe the earlier metadata. | M | Re-run `kc2/scripts/12_gradle_verify_identity.sh` at a clean commit and append the row. Expect a different artifact count. |
| R4 | `kc2/scripts/30_up_identity.sh:12-14` | **No jar-sha guard.** `identity-jars.csv` is correctly append-only (dirty rows retained, clean final rows at `77b124e` for `963d…` and at `308bb74` for `b415…`; the change is explained by the seed extension in `107586f`). But 30 boots whatever jar is on disk, and nothing ties the smoke rows to a recorded clean sha. | M | Add the KC1-style guard: `sha256sum` the jar about to run and require a matching clean-commit row in `identity-jars.csv`. Add a `jar_sha256` column to `identity-smoke.csv`. |
| R5 | `build/publish/authz-ladder/.git/pilot-last` | **Stale push marker.** It reads `07d39d4`, but the mirror tip `5d78ade` already contains `97c3577`. The next `format-patch` from the marker would re-apply already-pushed commits, and `git am` would fail. | M | After verifying the mirror tip's subject equals `97c3577`'s subject, set the marker to `97c3577`'s full sha. From now on, update the marker in the same step as every push. |
| R6 | Review 11 Q1–Q3 | **The confidentiality and falsifiability gates are not in place yet.** There is no `kc2/INVARIANTS.md` design freeze, no TCK phase in the plan, and no `private/kc2/` routing. No test has touched a current target, so nothing is at risk **yet**. These gates have to exist before the credential/handshake work produces a connector that can be tested. | **H** | Land all three **before** phase 3, and land Q3's private routing **before** the first DCP handshake smoke. Even a smoke catalogue request against a current target can expose a finding. Tests run in phase 3 only after the freeze commit is pushed. |
| R7 | versions (`targets-notes.md`, ENV.md) | **Version alignment is unverified.** IdentityHub/IssuerService are 0.17.0 to match Tractus-X 0.13.0's bundled EDC, which is UNVERIFIED in the binary (no pom.properties). BDRS 0.6.0 bundles EDC 0.16.0. Vanilla 0.18.1 is one minor ahead. | M | The next phase must verify three things. (a) **Tractus-X bundled EDC version by class identity:** hash a few stable EDC classes from `/app/edc-runtime.jar` and compare them with the same classes in the Maven Central 0.16.0 / 0.17.0 / 0.18.x artifacts (already-approved source). Record the match. (b) **DCP protocol compatibility:** record which DCP version and JSON-LD context URIs each component (Tractus-X 0.13.0 connector, vanilla 0.18.1, IdentityHub 0.17.0, IssuerService 0.17.0) speaks, from source or config, and make sure the handshake uses one shared version. For vanilla 0.18.1, decide whether a 0.17.0 IdentityHub is acceptable or a 0.18.x one is needed, and log it as a DECISIONS entry. (c) **BDRS 0.6.0:** confirm that its directory API matches what the 0.13.0 connector's BDRS client calls. |
| R8 | `kc2/scripts/20_gen_keys.sh` | P-256 keys are generated under `testbed/.secrets/kc2/`, but IdentityHub generates its own Ed25519 keys and does not use these. They are unused as of now. | L | State their intended consumer (the issuer's signing key in the next phase?) in the script header. Otherwise drop them, so there is no unexplained key material. |

**Next phase (credential issuance + DCP handshake) may start only after R1, R5, R6 (private routing at minimum) and R3/R4 land.**

**User decision (not decided here):** whether the vanilla 0.18.1 target gets its own 0.18.x identity components or shares the 0.17.0 stack (R7b), if source reading shows a DCP version difference.

**Verdict:**
- **Milestone discipline:** good. Real Eclipse components, the seed is minimal, no credentials were issued, and no secrets are tracked or published.
- **Evidence gaps:** the network check predates the services it should cover (R1), and the cross-resolution claim overstates what was measured (R2).
- **Confidentiality and freeze gates:** Review 11's still need to land before the handshake work goes further (R6).
- **Findings:** none exist yet, and none are at risk.

---

## Review 13 (KC2 pre-handshake), 2026-10-26

Scope: `5178493` through `1589ca9`: Review 12 hardening, the INVARIANTS freeze `a8cd4df` and amendment A1 `8479f2f`, D12, D13, the STS-secret seeding, `GenIssuer`, `HANDSHAKE-PLAN.md`, and `kc2/scripts/kc2lib.sh`. Also the KC2 transcript up to its checkpoint question. Read-only: no Docker, no downloads, no pushes.

**Review 12 status:**
- **R1 closed.** Isolation was re-run with the identity stack up, including probes from inside a container (peer positive control, IP and DNS blocked), at clean `5178493`.
- **R2 closed.** The wording is corrected, and real cross-resolution rows were added, plus a no-private-member check.
- **R3/R4 closed.** Verification was re-run (now 570 artifacts with the signing deps). The jar guard is in place.
- **R6 mostly closed:**
  - **Private routing:** `kc2_private_out` refuses `results/`, refuses path escapes and refuses any non-ignored path. It is solid.
  - **Design freeze:** INV-1..5 were frozen in `a8cd4df`. A1 (pre-results, justified, dated) adds mutation configs and promotes INV-6/7/8.
  - **The TCK is still absent** (see S1).
- **R7 closed.** D12 records one shared 0.17.0 identity stack, on the basis of a byte-identical DCP v1.0 context.
- **R8 closed.**

**Design checks:**
- **D13 (Route I):** issuer-signed VCs are stored directly, and the issuance protocol is out of scope. This is a user decision with two conditions: a realistic credential and a resolvable issuer DID. It is recorded as a paper limitation.
- **Mutation admission (A1):** a test is admitted only if it gives FAIL on the mutation config and PASS on the sanity config. This is the right detection-power control, the KC2 equivalent of KC1's positive controls.
- **Secrets:** no key or secret files are tracked. Private JWKs sit under the ignored `testbed/.secrets/kc2/`. The STS client secret is passed in by setting and is not committed.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| S1 | `kc2/INVARIANTS.md`, `kc2/HANDSHAKE-PLAN.md` | **The TCK precondition (Review 11 Q2) is still not planned anywhere in `kc2/`.** The safe sentence counts violations "in implementations that pass the official DSP TCK". Without a TCK baseline, any KC2 violation can only be reported as "in current releases". | **H** | Add a "TCK baseline" phase between the handshake and phase 3. Run the official DSP TCK (v1.0.2) against each target in its DCP-configured form, and run the DCP TCK (v1.2.1) against the IdentityHub. Archive per-test pass/fail in `kc2/env/tck-*.csv`; those are conformance results, not KC2 findings. Check first whether the TCK artifacts come from an already-approved source (Maven Central or Docker Hub); if not, ask the user. If a target fails tests, record it and narrow the claim. |
| S2 | `build/publish/authz-ladder/.git/pilot-last` | **Wrong marker value.** It holds `d1bec8a…`, which is the **mirror's** commit sha and does not exist in the Masters repo. The next `git format-patch "$(cat marker)..HEAD"` fails with "unknown revision". | M | Set the marker to the Masters sha of the last pushed commit (`1589ca9`'s full sha, after checking that its subject equals the mirror tip's). Keep this convention: the marker always holds a **Masters** sha. |
| S3 | handshake smoke vs private routing | The handshake smoke against current targets has two parts. The DCP-authenticated **200 catalogue** is an infrastructure positive control. The **untrusted-J refusal** is INV-5's test on a current release, and it can itself be a finding. | **H** | Write only infrastructure rows to `kc2/env/handshake-smoke.csv`: boot readiness, DCP 200 with the trusted issuer, did:web and BDRS resolution. Route **every** INV-n assertion, including untrusted-J, the third-participant cross-party check and any mutation-vs-sanity row, through `kc2_private_out`. If unsure, treat it as private. |
| S4 | KC2 counting | A1 promoted INV-6/7/8 into the frozen set before any results existed. That is acceptable, but the paper must be able to show that the count does not depend on post-freeze additions. | M | In every KC2 tally (private now, public only after disclosure), report INV-1..5 (original freeze `a8cd4df`) and INV-6..8 (A1 `8479f2f`) **separately**. Exclude INV-1/2 rediscoveries of the KC1 CVEs from "new violations". |
| S5 | timebox | The pilot started on 2026-10-21 with a 3-week timebox, so it ends around 2026-11-11. The remaining work: the handshake (3 participants, 2 targets), a TCK baseline, and phase 3 (8 invariants × 2 targets × sanity/mutation). | M | Add a dated plan to `PILOT-REPORT.md`: handshake by about 10-28, TCK baseline by about 10-30, phase 3 by about 11-07, report by 11-11. Record each slip. If phase 3 cannot finish, KC2 must report "incomplete invariant set" honestly, not "0 violations". |
| S6 | `PILOT-REPORT.md` | There is no KC2 status row yet: phase 1/2 progress, D11–D13, the freeze and A1. | L | Add a KC2 status section at the next checkpoint. Public content stays finding-free. |

**Your decision (the KC2 session asked; I am not answering):** continue straight into credential signing and the connector bring-up, or checkpoint here. Reviewer recommendation: continue, and checkpoint when (a) the DCP-authenticated catalogue returns 200 for consumer→provider on **both** targets with the trusted issuer, (b) isolation has been re-run with every service up, and (c) the TCK baseline phase (S1) is planned in `kc2/`. The untrusted-J result goes to `private/` only (S3).

**Verdict:** the KC2 groundwork is careful. It has real components, a frozen and amended invariant set with mutation-based detection power, solid private routing, and no secrets or findings in public. Before phase 3 can produce a countable result, two things must be added: the TCK baseline (S1) and strict private routing for the handshake's INV-5 control (S3). Fix the marker (S2) before the next push.

---

## Review 14 (KC2 handshake), 2026-10-27

Scope: `eabb556` through `80c263d` (TCK plan, credential seeding, the DCP handshake interop fixes, the third participant, full-stack isolation, KC2 status). Read: D11 amendment 2, `Kc2SeedExtension`, `Kc2TxScopeExtension`, `kc2/scripts/40_up_handshake.sh` and `handshake_lib.sh`, `kc2/env/*`, `kc2/TCK-PLAN.md`, the mirror log, and `private/kc2/` (file count and ignore status only, contents not read). No Docker, no downloads.

**Repo state:** clean tree. All 11 pilot commits since Review 13 are on the mirror, matched by subject. The marker holds a Masters sha equal to HEAD (`80c263d`, mirror `869419c`). Every commit has author and committer ftaakash with no trailer. No KC2 commit message states an invariant outcome; they report counts and "ran (private)" only. Nothing from `private/` or `.secrets/` is tracked or on the mirror.

**The four interop fixes: no verifier check was weakened (confirmed in code and config):**
1. *Key id is a DID URL.* This is spec-conformant key identification. The verifier still resolves and checks the key.
2. *`edc.participant.id` = DID.* The audience check stays on. The pilot saw it **reject** the BPN-as-id setup, which shows the check is live.
3. *Raw credential-service path.* This is holder-side routing only.
4. *`Kc2TxScopeExtension`.* This is holder-side only: it maps the Tractus-X scope alias to the DCP alias before IdentityHub's own transformer runs. The provider still verifies the VP signature, the issuer against its trusted list and the token claims.

On the connector side, trusted issuers come from the standard `EDC_IAM_TRUSTEDISSUER_<n>_ID` setting. The optional `EXTRA` trusted issuer hook is **not** used by the smoke run, so it is reserved for the INV-5 mutation config. `OTEL_JAVAAGENT_ENABLED=false` is irrelevant to authorization.

**Handshake evidence:**
- **Tracked `handshake-smoke.csv`:** infrastructure rows only. The final clean set at `1240aed` (15/15) covers 3 IdentityHubs seeded with credentials, 3 BDRS seeds (204), 3 connectors booted, BDRS booted and the issuer DID resolving. The DSP catalogue without a token gets 401, and the DCP-authenticated catalogue gets 200 for **both** consumer and third with a `dcat:Catalog` body. Rows carry the connector digest and the IdentityHub jar sha, which is recorded at clean `f0f08eb`.
- **Isolation:** re-run at `1240aed` with the **full stack** up (16 rows), including in-container probes.
- **Untrusted-issuer (INV-5) control:** it ran, and its output is in `private/kc2/` (2 files, gitignored; not inspected).

**Credential realism (D13):** type `[MembershipCredential, VerifiableCredential]`. The subject id is the holder DID, with `holderIdentifier` = BPN. Real `issuanceDate` and `expirationDate` are set. It is an ES256 JWT with `iss` = issuer DID and `sub` = holder DID, and the issuer DID resolves (smoke row). The issuer private JWKs sit only under the ignored `testbed/.secrets/kc2/`.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| T1 | `DECISIONS.md` D11 amendment 2, fixes 2 and 4 | **The fixes are justified by description, not by citation.** Fix 2 says "as in Tractus-X's own e2e fixture", and fix 4 says "Tractus-X normally pairs the connector with its own IdentityHub distribution, which accepts its alias". Neither gives a source path. Without a citation the scope adapter is an unverified deviation. | M | Add file paths at a pinned commit: Tractus-X `v0.13.0` for the e2e/helm `edc.participant.id` = DID setting, and the Tractus-X IdentityHub/wallet source that maps `org.eclipse.tractusx.vc.type`. If the alias mapping cannot be found in source, mark fix 4 **UNVERIFIED**. Either way, list it in INVARIANTS "Scope limitation" as a stated testbed deviation that affects only holder-side presentation queries. |
| T2 | vanilla 0.18.1 target | **The second target has not handshaken yet** (D12: shared 0.17.0 identity stack). Step 2 is half done. | **H** | Next step: build the vanilla 0.18.1 DCP launcher, with Gradle verification and a cross-check row, as for `kc2/identity`. Reach the same infrastructure smoke: 3 participants, no-token 401, DCP 200 for consumer and third, isolation re-run. Check whether vanilla needs the scope adapter at all, since it should request the DCP alias natively, and record the answer. The adapter must stay **off** for a target that does not need it. INV-5's control for vanilla goes to `private/` only. |
| T3 | `kc2/TCK-PLAN.md` | **The plan names the TCK artifacts (Maven Central, already approved) but must say how the DSP TCK authenticates as a counterparty to a DCP-configured connector.** The TCK needs its own DCP identity (DID, credential, BDRS entry), or else a documented TCK-side config. | M | Add a TCK identity section to the plan: a fourth "tck" participant seeded through the same IdentityHub/issuer/BDRS path, or the TCK's own documented mechanism. Run the TCK **on both targets** before phase 3. Archive per-test pass/fail in `kc2/env/tck-*.csv`; conformance results are public. Any TCK test failure is recorded and narrows the claim. It does not stop the baseline. |
| T4 | D13 / INVARIANTS scope limitation | DID resolution runs over HTTP (`EDC_IAM_DID_WEB_USE_HTTPS=false`). This is standard for local e2e setups, but it is a transport deviation from production. | L | Add one sentence to the scope limitation: "did:web over HTTP in the testbed; authorization logic unaffected." |
| T5 | `Kc2SeedExtension.java:47` | The class javadoc still says the extension "does NOT issue or seed any VerifiableCredential", but it now does (Route I, line ~149). | L | Update the javadoc to match D13. |
| T6 | timebox | The handshake was due ~10-28. Tractus-X is done on 10-27; vanilla is still open. TCK baseline ~10-30, phase 3 ~11-07, report 11-11. | M | Keep the plan. If vanilla's DCP launcher is not at 200 by 10-29, ask the user whether phase 3 should run on Tractus-X only, and record it as a decision. Never quietly drop the target. |

**Next steps, in order:** (1) the vanilla 0.18.1 handshake (T2); (2) TCK identity, then the TCK baseline on both targets (T3); (3) only then phase 3: frozen INV-1..8, sanity plus mutation per target, all verdict rows in `private/kc2/`, with INV-1..5 and INV-6..8 counted separately. Commit and push each completed step per D9.

**User decisions (not decided here):** (a) whether phase 3 may run on Tractus-X only if vanilla slips (T6); (b) none others yet.

**Verdict:**
- **Tractus-X 0.13.0:** the handshake is real and controlled. A DCP-authenticated 200 for two counterparties, a 401 without a token, and the audience check visibly enforced, with the isolation re-run on the full stack.
- **Four fixes:** none of them weakens a verifier check, though two still need source citations (T1).
- **Repository:** fully committed and pushed, with no findings or secrets in public.
- **Remaining:** the vanilla target and the TCK identity must land before phase 3.

---

## Review 15 (KC2 pre-phase-3), 2026-10-29

Scope: `d60d67c` through `546e613`: the T1–T5 fixes, the vanilla 0.18.1 DCP launcher and handshake, the TCK plan and D14, the TCK builds and dependency verification, the two DSP TCK baselines, and the operator Docker preflight. Also the KC2 transcript up to its "start phase 3?" question. Read-only apart from this file. No Docker, no downloads.

**Repo state:** clean tree. The marker = HEAD `546e613`, a Masters sha. Every pilot commit subject since Review 14 is present in the mirror log. No trailers, and no outcome wording in messages.

**Done and correct:**
- **T1:** citations added; fixes 2 and 4 verified upstream. **T4:** did:web over HTTP stated as a testbed deviation. **T5:** javadoc fixed.
- **T2:** the vanilla 0.18.1 handshake reaches 12/12 at clean `e6906d7`, with the scope adapter **OFF** (switchable, as required). Isolation was re-run with the vanilla full stack up, and the launcher's deps are verified (657/657).
- **D14 (user):** the TCK baseline follows the upstream configuration (TCK runtime with mock identity, not DCP). The claim wording is fixed correctly: "pass the official DSP TCK in the upstream TCK configuration (mock identity), without DCP"; the paper must not say the DCP-configured release passes.
- **DSP TCK 1.0.2:** **65/65** on vanilla 0.18.1 and **65/65** on Tractus-X 0.13.0 (release image binary plus add-on). Per-test CSVs and raw output are in `kc2/env/`. TCK jars are verified (659 + 125, tamper-tested). Before results are recorded, the Tractus-X run asserts from the boot log that its stand-ins are the ones actually loaded.
- **Docker:** `00_ensure_docker.ps1` is operator-only and never called from tests, which is consistent with Review 9 N1. The cause is recorded: AutoStart was off and the engine was being terminated externally.

**Admission rule checked for soundness:** the sanity configuration is a scenario on the same build where the invariant holds by construction (for example, INV-1: the policy admits B). It is not the attack scenario on the current target. So "PASS on sanity + FAIL on mutation" validates the test without masking a violation in the current-release cell. The rule is consistent.

| # | file:line | Issue | Sev | Required change |
|---|---|---|---|---|
| U1 | KC2 transcript; Review 11 Q3 | **Publishing counts.** The KC2 session plans that "tracked files only show counts, split INV-1–5 and INV-6–8". A per-invariant or per-target count (for example "INV-x: 1 FAIL on target y") already locates an undisclosed finding. Review 11 Q3 said aggregate counts are published **only once the user approves**. | **H** | Until disclosure is decided, tracked files and commit messages carry **no** phase-3 counts at all, not even totals: only "phase 3 run complete, results private". All tallies stay in `private/kc2/`. Ask the user before publishing any number. |
| U2 | phase-3 runner (missing) | Phase 3 is **16 cells × 3 configurations** (8 invariants × 2 targets × sanity, mutation and current) and needs KC1's batch discipline. | **H** | Before the first phase-3 cell, add and commit `kc2/scripts/60_phase3_batch.sh`, modelled on `50_kc1_batch.sh`. It must refuse a dirty tree, abort if HEAD moves, keep per-cell logs and all rows **under `private/kc2/`** via `kc2_private_out`, and set a timeout per cell. It runs, per invariant and target, **sanity → mutation → current**. If the admission step fails, the current cell is written as `INVALID(admission)` and is never counted. Run Docker's preflight once beforehand by hand; make no commits during the batch. |
| U3 | `kc2/TCK-PLAN.md:87-90`; Tractus-X add-on | **The Tractus-X TCK run used stand-ins modified from upstream's test code:** named classes, and a PolicyArchive stand-in made deterministic. A PolicyArchive stand-in sits on a policy path, so its fidelity matters. | M | Record, in `kc2/env/`, each stand-in's upstream source path at the pinned Tractus-X tag and a diff from upstream. State in TCK-PLAN that the changes are load-order/naming only and change no policy semantics. If any semantic change exists, mark the Tractus-X TCK result **UNVERIFIED**. |
| U4 | discarded TCK runs | Two runs were discarded as setup artifacts (the vanilla callback address and the Tractus-X stand-in race). The reasons are documented, but the raw outputs are not archived. | M | Archive the raw output of each discarded run if it still exists (`kc2/env/tck-dsp-<target>-discarded-<n>.txt`, with the reason in its first line); otherwise mark "not archived" in TCK-PLAN. Discarded runs stay visible, so the baseline is not selectively reported. |
| U5 | `kc2/TCK-PLAN.md:22` | **The DCP TCK (v1.2.1, IdentityHub) is planned but has not run.** INV-5 rests on the identity stack verifying correctly. | M | Either run the DCP TCK against IdentityHub 0.17.0 before phase 3's INV-5 cells, or record a dated deferral with its reason. In that case INV-5's result must carry "identity stack not TCK-baselined". |
| U6 | timebox | The handshake (10-28) and TCK (10-30) milestones were met early. Phase 3 is due ~11-07 and the report 11-11. | L | On track. Note it in the PILOT-REPORT KC2 plan. |

**Next steps, in order:** (1) U1: fix the publishing rule in `kc2/` docs and the status text **before** any phase-3 run. (2) U2: the batch runner, committed and pushed. (3) U3/U4: TCK fidelity records. (4) U5: the DCP TCK, or a recorded deferral. (5) **Phase 3, when the user says go.** The KC2 session asked; it is the user's call.

**User decisions (not decided here):** (a) go or no-go for phase 3; (b) whether any phase-3 counts may ever be published before disclosure (U1); (c) whether the DCP TCK runs before INV-5 or is deferred (U5).

**Verdict:**
- **Both targets:** now handshaking and TCK-baselined in the upstream configuration, with honest claim wording (D14). The invariant set is frozen and its admission rule is sound.
- **Before phase 3 can produce countable, safely handled results:** close the publishing gap for counts (U1), put a disciplined private batch runner in place (U2), and record the Tractus-X stand-ins' fidelity (U3).

---

## Review 16 (INV-6 test validity), 2026-10-31

A soundness check of the INV-6 probe (contract-policy evaluation at negotiation) only. No result of any
current release is examined or implied here; any detail is in `private/kc2/review-inv6.md` (gitignored).
Read: the uncommitted `Kc2Inv6PolicyExtension` fixture, the private INV-6 driver, and `kc2/INVARIANTS.md`
INV-6 + amendment A1. Read-only.

**Validity verdict: the INV-6 current cell is NOT yet a like-for-like test, and the KC2 session's choice to
record it INVALID (rather than count it) is the correct one under the frozen oracle.**

- The fixture is present and bound in both the sanity and the current configurations the same way, so
  those two are like-for-like on fixture presence (check 1 of the brief).
- But the sanity configuration as implemented is a *connectivity* control, not an *enforcement* control:
  its expected outcome is the same one you would get if the bound constraint were never evaluated at all.
  So "PASS on sanity" does not establish that the bound constraint is actually enforced at the tested
  phase. Sanity and the admission mutation also differ in two variables at once (policy and binding), so
  the pair does not isolate enforcement.
- There is therefore no positive-enforcement control on the current build: nothing shows that a bound
  constraint provably refuses the wrong party at this phase. Without it a negative outcome cannot be
  distinguished from a fixture-wiring artifact (the KC1 F1 left-operand-binding class). This is exactly why
  the cell must stay INVALID, never a counted result (check 2).
- `kc2/INVARIANTS.md` INV-6 already *defines* the needed control (its sanity text includes a "deny policy →
  refused → PASS" leg), but the driver implements only the admit leg. So the frozen catalogue and the
  driver disagree, and closing the gap needs a driver change, not a freeze amendment (check 3).

**Required before INV-6 can count on any target:** implement the sanity deny-leg as the positive-enforcement
control; INV-6 counts only where that leg provably refuses the denied party at the tested phase, else the
cell is INVALID. Instructions sent to the KC2 session. No INV-6 result is admissible until this lands.

---

## Review 17 (INV-4/7 validity + claim status), 2026-10-31

Validity and coverage only. No current-release authorization result is examined or implied; detail and the
claim-logic worked example are in `private/kc2/review-inv47.md` (gitignored). Read: the INV-4 feasibility
driver and log, `kc2/INVARIANTS.md` INV-4/INV-7, and the frozen `kill-test.md` / `SCOPE.md`.

**Q1 — why INV-4/INV-7 are INVALID: a testbed setup gap on the legitimate transfer path, not a design
limit.** Both invariants are transfer-time and well-posed. They came out INVALID because the *legitimate*
positive-control transfer does not yet reach STARTED on the target in our testbed's data-plane
configuration (the data-plane selector matches no instance for the requested transfer type). With no
working legitimate path there is no positive control, so the oracle correctly yields INVALID — never a
vacuous PASS and never a counted FAIL. The invariant definitions are sound; the honest transfer fixture is
incomplete. This is the same family as INV-6's missing enforcement control: a setup gap, not a dead end.

**Q2 — fixable within scope and timebox (recommended).** Using documented upstream configuration only
(normal connector APIs; no crafted messages, no bypassing connector checks): align the transfer setup with
the published e2e/system-test transfer configuration so the legitimate transfer reaches STARTED, on either
the vanilla 0.18.1 signaling setup or — preferred/fallback — the Tractus-X 0.13.0 release image with its
own documented e2e transfer wiring. INV-4/INV-7 then count only where the legitimate transfer is green on
that build. Timebox: get one target's legitimate transfer working by ~11-04; if none is green by then,
record INV-4/INV-7 as INVALID:positive-control-not-established and report the set as incomplete.

**Q3 — claim status (direct answer).** The research does **not** fail, and the initial claim is not lost.
The safe sentence has two halves. The "rediscovers known flaws" half is **already established by KC1**
(both CVEs admitted as clean FAIL→PASS ladders). The "finds further violations in TCK-passing
implementations" half is what KC2 tests and is **still open**, pending the transfer fix and completing the
exercisable set. Per the frozen kill condition 2, the downgrade to a tool/workshop paper triggers **only**
on "0 new violations after the **full** set" — i.e. the full set validly exercised and nothing found. An
INVALID cell is an un-run test, not a zero, so:
- ≥1 admitted new violation → KC2 does not fire → full claim stands.
- 0 new violations with part of the set INVALID → the result must be reported as **incomplete** ("X of 8
  invariants validly exercised; 0 among those; rest not conclusively testable in the timebox"), which is
  honest incompleteness, **not** the KC2 downgrade and **not** a project failure.
- Even the genuine downgrade case keeps real contributions: the validated method, the regression suite,
  the mutation-validated invariant catalogue, and the upstream TCK/scenario contributions.
**Integrity requirement:** an incomplete invariant set must be reported as incomplete; INVALID cells are
listed with their reason and never folded into a "0 violations" statement.

Instructions sent to the KC2 session. No INV-4/INV-7 result is admissible until a legitimate transfer is
established on the target.

---

## Review 18 (KC2 pre-final-batch), 2026-11-05

Scope: `7090a1a` (D16), `0c356a5`, `cd4d24a` (D17), `7e4ea74` (D11 amendment 3), the committed
`kc2/scripts/60_phase3_batch.sh`, and the private INV-6 driver's structure (design only). Validity and
coverage only: no current-release result is examined or implied. Read-only apart from this file.

**Repo state:** clean tree. Marker = HEAD `7e4ea74` (a Masters sha). The KC2 session confirmed every
subject on the mirror after fixing the pilot-relative patch paths.

**Done and correct:**
- **D17** (user, decided before any INV-4/7 result): legitimate-transfer deadline 11-08, final batch ~11-12,
  report 11-15. The legitimate-transfer milestone is met early.
- **D11 amendment 3** is config-only and cites upstream sources (BdrsClientImpl, its component test,
  TrustedIssuerConfigurationExtension at the version BDRS actually bundles). The BDRS trusted-issuer change
  **narrows** trust (wildcard → MembershipCredential only). No verifier check is disabled. The Tractus-X
  legitimate transfer now reaches STARTED, which supplies the positive control INV-4/INV-7 need.
- **`60_phase3_batch.sh`** refuses a dirty tree, aborts if HEAD moves, applies a per-cell timeout, writes
  everything under `private/kc2/` and gates each current cell on sanity PASS + mutation FAIL. This matches
  Review 15 U2.
- **D16** (LLM-gateway half replaces MCP) is recorded with SCOPE's KC3/KC4 amendments, and the gateway half
  stays out of build scope.

| # | where | Issue | Sev | Required change |
|---|---|---|---|---|
| W1 | INV-6 admission design (my Review 16 recommendation) | **Review 16 over-corrected, and I own that.** INV-6's sanity now includes a deny-leg (bound constraint, deny B, same build, same config) and requires it to refuse B. The current cell runs that **same** measurement. So a current-cell FAIL can only ever coincide with a failed admission and becomes INVALID: the current cell can no longer produce a counted violation. It is no longer falsifiable, which is the opposite of what the admission rule is for. | **H** | Make the enforcement validation **independent of the verdict measurement.** Preferred: probe with a constraint the **release itself** registers and binds for the negotiation phase (verify from each target's pinned source which constraints that is), so no pilot fixture sits in the enforcement path. Then the precondition is "the constraint is bound by the release (cited source line)". Sanity = the admit case. Mutation = a labelled test-only unbinding. Positive control = A finalizes. The verdict = B under the deny policy. Alternative: validate the fixture's wiring on a separate reference configuration, never on the cell being judged. Either way this changes INV-6's oracle mechanics, so under the freeze rule it needs a dated amendment (A2) **and the user's sign-off** before INV-6 counts. Until then INV-6 is not countable. |
| W2 | `private/kc2/scripts/inv6.sh:18` (prebuilt-image injectability) | INV-6 records Tractus-X as `INVALID:mutation-not-injectable-on-prebuilt-image`. But the TCK baseline already ran the **Tractus-X release image plus an add-on classpath** (`tck-extension` + stand-ins). So labelled test-only add-ons **are** injectable on that image. The not-injectable claim is not established. | M | Use the same add-on mechanism to host labelled mutation fixtures on Tractus-X for INV-4/6/7. Keep two rules: (a) the **current** cell runs the pristine release image plus only the probe fixtures that are identical across sanity/mutation/current, never the mutation add-on; (b) the add-on's contents are recorded (jar sha) per cell. Re-assess INV-6 on Tractus-X after W1. |
| W3 | private drivers vs commit stamps | **The test drivers that produce every phase-3 row live in the gitignored `private/kc2/scripts/`.** The dirty marker ignores them, so a row stamped with a clean commit was produced by driver code that commit does not contain and that nothing versions. A driver edit between batches is invisible. | **H** | Add a `driver_sha256` column to every cell row: sha256 of `inv<N>.sh` + `p3lib.sh` at run time. At the start of each batch, snapshot all private drivers to `private/kc2/batches/<commit>-<utc>/` (gitignored), and have the batch refuse to run if a driver changed after its snapshot. The final report cites the batch snapshot id alongside the commit. |
| W4 | INV-4 / INV-7 drivers (to be built) | These are the next drivers, and they must not repeat W1. | **H** | For each, the sanity case is the legitimate scenario only (A's own agreement → transfer STARTED; A's EDR used against its own transfer). The admission mutation is a labelled add-on that breaks the specific check. The current cell's verdict measurement must **not** also be an admission requirement. Positive control on every cell: A's legitimate transfer STARTED. Coverage stays Tractus-X-only per the user (2026-10-31), stated in the report. |
| W5 | final report (11-15) | The paper's claim depends on honest coverage. | M | Prepare an invariant × target coverage matrix **privately** (validly exercised / INVALID with reason category / not applicable). In public files, keep "phase 3 complete, results private" until the user decides disclosure and publication (Review 15 U1). The report must state the invariant set as **incomplete** if any invariant was not validly exercised (Review 17). |
| W6 | D16 gateway half | Not to be started. | L | Build nothing for idea 10 until KC2 has a result and the user says go. PyPI is a new source and needs asking first (SCOPE). |

**Order of work:** (1) W3 driver versioning, because it affects every row from now on; (2) W1: put the INV-6
redesign options to the user (amendment A2 needs their sign-off); (3) W2 + W4: INV-4/INV-7 drivers on
Tractus-X with add-on mutations and independent admission; (4) the final admission-gated batch ~11-12 from
one clean commit and one driver snapshot; (5) the report on 11-15, with coverage stated honestly.

**User decisions (not decided here):** (a) approve or reject the INV-6 oracle redesign as amendment A2 (W1);
(b) whether any phase-3 numbers or coverage may be published before disclosure (W5).

**Verdict:**
- **On track under D17.** The legitimate-transfer blocker is fixed with sourced, trust-narrowing configuration.
- **Must close before the final batch:**
  - INV-6's admission is currently non-falsifiable (W1, my earlier error).
  - The drivers that produce every row are unversioned (W3).
  - INV-4/INV-7 must be built so they don't repeat W1 (W4).

---

## Review 19 (INV-6 A2, INV-4 DSP scope, INV-7 NA), 2026-11-05

Scope: `d845b6a` (W3 driver versioning), `ef82b3a` (A2), `a2d7b5a`/`fec7ffc` (INV-6 mutation add-on +
provenance), `c3c991a`/`5effefe` (INV-4 add-on + provenance), and the KC2 session's INV-7 architecture
assessment and proposed INV-4 DSP-level test. Validity, coverage and scope only — no current-release
verdict is examined or implied; detail is in `private/kc2/review-inv47-dsp.md` (gitignored). Read-only
apart from this file.

**Repo state:** clean tree; marker = HEAD `5effefe` (a Masters sha). No tracked result/verdict files
(only the batch runner and fixtures are tracked under `kc2/`).

**Done and correct:**
- **W3 (driver versioning):** the private phase-3 drivers are now versioned per Review 18.
- **A2 (my Review 18 W1 fix) is sound.** INV-6's admission (a labelled classpath add-on that neuters the
  release's own negotiation constraint) is now a different measurement from the verdict (pristine release,
  deny offer). The precondition — that the release itself binds a negotiation-scope constraint — is cited
  from pinned source; vanilla has none, so INV-6 is correctly recorded INVALID there and is Tractus-X-only.
  INV-6 is falsifiable again. The admission add-ons carry recorded jar provenance and never sit on a
  current-release classpath.

| # | item | Assessment | Sev | Action |
|---|---|---|---|---|
| X1 | INV-7 = NA by architecture | **Sound.** Both frozen clauses dissolve against how EDC resolves the data address and against a documented allow-all access-control default; INV-7's own oracle permits NA-with-reason, so no catalogue amendment is needed. Correctly **not** scored as a finding (documented default, not a hidden flaw). | — | Record INV-7 NA with its reasons in `private/kc2/`. The documented default is worth noting as a coverage/TCK-gap observation, not a Paper-A violation. **User's KC2 interpretation call**, stated in the report; do not score it FAIL unilaterally. |
| X2 | INV-4 DSP-level counterparty test | **In defensive scope as TCK-style negative conformance testing — IF bounded.** The honest consumer refuses client-side, so the provider's `validateAgreement` boundary is only reachable by a counterparty sending the DSP message directly, which is what the DSP TCK's protocol tests do and what SCOPE's "DSP client fixture" contemplates. It does **not** bypass the provider's checks — it tests them. | H (user go) | Bounds (all required): B uses **B's own** legitimately-issued DCP credential/token (A's agreement id is a non-secret reference, not forgery); the provider keeps **all** checks on; local provider only; pass/fail only; a FAIL is private → Eclipse disclosure. Positive control = A's own transfer STARTED; admission mutation = a skip-`validateAgreement` provider add-on (must FAIL), never on the current classpath. **Hard stop:** if any step needs fabricating A's signed token/VP or reading A's key, STOP (out of scope; a forged input yields no readable verdict). It is a methodology step (a DSP protocol driver), so the **user authorizes it before it is built**, and it is a test fixture, never a reusable exploit. |
| X3 | INV-4/INV-7 coverage as a result | INV-4 and INV-7 target enforcement points EDC structures away or leaves as a documented optional no-op. That they are not honestly mountable as PASS/FAIL on current EDC is itself a reportable coverage result. | M | Report NA/structural with reasons; never fold into "0 violations". The invariant set is **incomplete** (INV-6 TX-countable, INV-5 countable, INV-4 pending the DSP test, INV-7 NA, INV-1/2 = KC1 rediscoveries not "new", INV-3 NA, INV-8 partial). State this plainly; how it reads against the claim is the user's call. |
| X4 | confidentiality | Holding so far: no tracked result files, no verdict wording in commit messages. | L | Keep it. Phase-3 numbers/coverage are published only on the user's go (Review 15 U1). |

**Order:** (1) put X2 (the DSP-level INV-4 test) and X1 (INV-7 NA interpretation) to the **user**, with the
X2 bounds and the hard stop stated; (2) on the user's go, build the INV-4 DSP driver as a bounded fixture;
(3) run the final admission-gated batch (~11-12) from one clean commit + one driver snapshot, all output
private; (4) the report (11-15) states coverage honestly and the set as incomplete.

**User decisions (not decided here):** (a) authorize the bounded INV-4 DSP-level test (X2); (b) whether the
documented allow-all default (INV-7) is reported as a coverage observation vs anything stronger (X1);
(c) publishing any phase-3 numbers/coverage before disclosure.

**Verdict:** INV-6 is sound and falsifiable again (A2 closes my earlier error). INV-7 NA is correctly
reasoned and correctly not a finding. The INV-4 DSP-level test is the one remaining path to a second clean
Tractus-X verdict and is within defensive scope **as a bounded TCK-style negative test**, but it is a
methodology step the user must authorize, with a hard no-forgery boundary. The honest headline is that part
of the frozen set is structurally NA on current EDC, which must be reported as incomplete, not as zero.

---

## Review 20 (INV-4 client fixture + amendment A3), 2026-11-06

Scope: `b0f1e3c` (INV-4 DSP client fixture, amendment A3, batch-runner admission path) and `80903b6`
(add-on jar provenance). Commits only; no transcript read. Validity, coverage and confidentiality only;
no current-release verdict is stated or implied here. Read-only apart from this file.

**Repo state:** clean tree; marker = HEAD `80903b6` (a Masters sha); both commits are on the mirror.

**Done and correct:**
- The user authorized the bounded INV-4 DSP-level test and A3 (recorded in A3 as user-approved,
  2026-11-06). The fixture follows the Review 19 bounds as stated in the commit: B uses its own DCP token,
  A's token, VP and keys are not touched, the provider stays pristine for the verdict, and the fixture is
  off by default.
- The add-on jar provenance is recorded per build (sha256, bytes, commit), as Review 18 W2 asked.
- The INV-4 verdict definition (PASS / FAIL / INVALID) is well-posed. INVALID covers "attack not
  delivered", so a non-delivery cannot read as a PASS.

| # | where | Issue | Sev | Required change |
|---|---|---|---|---|
| Y1 | `kc2/INVARIANTS.md` A3 ("Finding — defense-in-depth" bullet) | **Confidentiality.** This bullet records how the current release behaved when INV-4 was run against it. That is a current-release observation, and it is now in tracked history and on the mirror. It contradicts the "no current-release result in tracked files" rule (Review 15 U1) and the commit's own "No phase-3 result or number recorded". It is not an undisclosed weakness, so the disclosure risk is low. It is still a phase-3 result published before the user's publication decision. | **H** | Forward commit: replace that bullet with a mechanics-only statement (the enforcement is layered, so the admission is not a single-check mutation), and move the observed behaviour to `private/kc2/`. Do the same for the A3 "Admission" bullet's description of the specific refusal. **Never force-push or rewrite history.** Whether the already-pushed text warrants anything further is the **user's call**. Run the tracked-file leak check before every future commit. |
| Y2 | `60_phase3_batch.sh` new `elif s=PASS && m=NA` branch | **Admission loophole.** The new branch admits **any** invariant on any target whose mutation cell returns NA, for any reason. A mutation that is NA because it was not injectable, or because its driver broke, now admits the current cell with no falsifiability check. A3 justifies the exception for INV-4 on Tractus-X only. | **H** | Restrict the branch to an explicit allow-list (`INV-4` × `tractusx`). Also require the mutation cell's NA reason to be the specific layering observation. Every other `PASS + NA` stays `INVALID:admission`. Record the admission path (`A1` or `A3`) as a column on the row. |
| Y3 | A3 admission basis | **Weaker evidence tier, and misattributed.** Review 17 required a positive control before INV-4 could count at all. It did not offer positive-control + attack-refused as a **substitute** for a mutation FAIL. Without a FAIL-capable mutation, INV-4 never shows its driver can detect a violation. A refusal could also come from something unrelated to agreement binding. A3's check of the specific refusal type mitigates this but does not replace a mutation. | **M** | Preferred: a labelled two-layer mutation add-on that neutralizes **both** layered checks on the provider. It must FAIL with A's control intact, which restores A1. It stays off every current-release classpath. If that is not feasible in the timebox, keep A3, but the report must list INV-4 as **admitted without a mutation (weaker tier)**, next to the A1-admitted invariants and never pooled with them. Correct A3's wording so it does not attribute this rule to Review 17. |
| Y4 | add-on jar packaging | One jar now holds the provider mutations (INV-6, INV-4) **and** the consumer client fixture. In the current cell B needs the jar and the provider must have **none** of it. A shared jar makes it easy to put a mutation where it shouldn't be. | **M** | Split into a consumer-fixture jar and a provider-mutation jar, with provenance recorded for each. The batch asserts, per current cell, that the provider classpath contains no add-on jar (sha check) and that B carries only the fixture jar. |

**Order:** (1) Y1 (forward-commit scrub; ask the user about anything further); (2) Y2 (allow-list the
A3 path); (3) Y4 (split the jars and add the classpath assertion); (4) Y3 (attempt the two-layer mutation,
otherwise label the tier); (5) the final admission-gated batch ~11-12 from one clean commit and one driver
snapshot; (6) the report on 11-15, with the set reported as incomplete and the admission tiers stated.

**User decisions (not decided here):** (a) whether the already-pushed A3 text needs anything beyond a
forward scrub (Y1); (b) whether INV-4 is reported on the A3 tier if the two-layer mutation is not built
(Y3); (c) publishing any phase-3 numbers before disclosure (unchanged).

**Verdict:**
- **The INV-4 build is in scope and was authorized.**
- **Before the final batch:**
  - Scrub the current-release observation from tracked A3 (Y1).
  - Close the general NA-admission loophole (Y2).
  - Separate the fixture jar from the mutation jar (Y4).
- **INV-4 sits on a weaker evidence tier than INV-6** until a two-layer mutation FAILs (Y3).

---

## Review 21 (INV-4 oracle refinement), 2026-11-07

Scope: INV-4 entry and amendment A3 in `kc2/INVARIANTS.md` (rev. 2026-11-06), `kc2/scripts/60_phase3_batch.sh`, and local commits `8f5411a`, `6854fbd`, `925fdfa` (mirror `3e16222`, `65a9a19`, `9b46bb1`).

Read-only. From `private/kc2/` I read only:
- file names and timestamps;
- the cell file's invariant, config and timestamp columns;
- the verdict-assignment lines of the INV-4 driver.

No result, count or finding is stated here. Test design only.

### Q1. Is the acceptance-vs-refusal criterion grounded in the spec?

**Yes.**
- In the DSP Transfer Process Protocol, the provider decides whether to honour a `TransferRequestMessage` when it **processes the request**. It either acknowledges with a transfer process in state REQUESTED or answers with an error. STARTED is a later, provider-initiated transition (`TransferStartMessage`) that depends on data-plane provisioning, not on the agreement binding.
- Keying the verdict on STARTED would conflate a data-plane failure with a binding refusal. That would be a false-negative path, so the refinement removes a confounder rather than adding one.
- **Section numbering is UNVERIFIED:** cite "Transfer Process Protocol: TransferRequestMessage; Transfer Process States (REQUESTED / STARTED)" against the DSP version the TCK baseline used (TCK ≤ 1.0.2, `kc2/TCK-PLAN.md:12`) before quoting a section number in the paper.
- The tracked text already keyed on refused vs accepted before `8f5411a`. The refinement only fixed what counts as **accepted**: acknowledged past the binding, instead of reaching STARTED.

### Q2. Was it settled before any current-release cell counted?

**Yes, as far as the record shows.**
- The criterion entered tracked files at `8f5411a` (2026-11-06 19:21) and `925fdfa` (19:42).
- The private INV-4 driver was last modified at 19:39, between those two commits.
- `private/kc2/` holds **no** admission-gated batch snapshot (`batches/` is absent) and **no** INV-4 row in the cell file. The only INV-4 artefacts on disk are feasibility logs from 2026-10-31 and 2026-11-04, which predate both the client fixture and the refinement.
- **Caveat:** the driver is unversioned, and the development runs on 11-06 left no log. "Changed while chasing the mutation FAIL" therefore cannot be audited run by run.
- **Direction of the change:** it only **widens FAIL** (acknowledged-but-not-STARTED now reads FAIL). It cannot turn a violation into PASS.

### Q3. Do the controls hold by construction?

**Mutation FAILs by construction (OK).**
- With both provider gates neutralised (the participant-scoped lookup and `validateAgreement`), a well-formed, authenticated foreign-agreement request has no remaining binding check.
- The driver correctly refuses to read FAIL unless three things hold: the provider add-on is active (`mutation-not-applied`), delivery happened (`attack-not-delivered`), and A's control is STARTED. A refusal under the mutation is INVALID (`mutation-did-not-violate`), never PASS.

**Sanity PASSes only vacuously (gap).**
- The sanity cell PASSes iff A's own transfer STARTs. It never sends B's request, so the **PASS branch of the verdict** (refusal classified as PASS) is first exercised in the current cell itself.
- A1 admission is therefore genuine for FAIL-detection but untested for PASS-classification. See Z3.

### Q4. Can the oracle produce false negatives or spurious FAILs?

| # | where | Issue | Sev | Required change |
|---|---|---|---|---|
| Z1 | INV-4 driver, verdict line "B TERMINATED ⇒ PASS" | **False-negative path.** PASS is keyed on B's transfer process ending TERMINATED, whatever the reason. A schema error (400), auth failure (401), provider error (500) or dispatch failure also ends TERMINATED, so a fixture or setup artefact reads **PASS**. The comment says "refused on agreement-binding grounds", but the code does not check the grounds. | **H** | PASS only if the provider's refusal is one of the two binding layers: the agreement-lookup miss (404 `TransferError`) or the identity check (409). Capture the provider-side status or error and record it in the observations. Any other termination is `INVALID:refused-non-binding(<status>)`. |
| Z2 | current and mutation cells | **Spurious-FAIL path.** If B's identity resolves to A's, the request is legitimately accepted and reads FAIL. Examples: a shared participant context, or a stand-in BPN mapping like the TCK stand-ins in `kc2/env/tck-tx-standins.md`. | M | Per cell, assert and record that B's authenticated identity ≠ A's and that the cited agreement's consumer = A. Otherwise INVALID. |
| Z3 | sanity / admission | The PASS branch is never exercised before the current cell (see Q3). | M | Add two **single-layer control cells** on mutated builds: neutralise only gate 1, then only gate 2. The other gate still refuses, so each must PASS with the specific binding status from Z1. This exercises the PASS branch and the refusal-reason check on a known-refusing provider, and confirms the layering claim in A3. Off every current classpath, as now. |
| Z4 | acceptance evidence | "Accepted" is read from B's **consumer-side** state (REQUESTED / STARTING / STARTED / COMPLETED). | M | Corroborate with provider-side evidence: a provider transfer process exists for B's request id. Read it via the provider management API in the evidence step only, never as the assertion path. Disagreement between the two sides → INVALID. |
| Z5 | provenance | The criterion lives in the unversioned driver, changed at 19:39 after `8f5411a`. | L | Record the INV-4 driver sha in A3's refinement note. The batch snapshot and manifest already pin it per run. |

### Verdict

**INV-4 is cleared for the 11-12 batch, on two conditions:**
- **Z1:** a binding-specific refusal is required for PASS.
- **Z3:** the single-layer control cells PASS. They must run before the batch and be committed as admission evidence.

**Should land as well:** Z2 and Z4. Without them, a FAIL needs manual corroboration before it counts.

**What holds now:**
- The refinement itself is spec-grounded and outcome-independent in direction, and nothing was counted before it.
- The two-layer mutation is a genuine A1 FAIL control.
- If Z1 or Z3 is not done by the batch, report INV-4 as INVALID:oracle-unverified rather than counting a PASS.

---

## Review 22 (INV-4 Z1–Z5 implementation and classifier provenance), 2026-11-07

Scope: amendment A4 (`24e0508`), the batch header-schema guard (`e72f686`), and the gitignored INV-4 driver `private/kc2/scripts/inv4.sh`. The driver's sha256 together with `p3lib.sh` is `b641f94a…`; it is byte-identical to the dry-run-2 snapshot and matches A4 Z5.

Read-only. From `private/kc2/` I read only:
- driver code;
- snapshot names, times and manifest presence;
- the dry-run cell file's invariant, target, config, commit, driver sha, snapshot and timestamp columns;
- for **mutated-build cells only**, their result and gate-control lines.

No current-release cell's result, detail or log was read for this review, and none is stated.

### 1. Provenance of every classifier element

| Element | Where it is used | Provenance | OK? |
|---|---|---|---|
| Reason text "agreement not found or not valid" | `classify_refusal`, `inv4.sh:60` | EDC 0.17.0 `TransferProcessProtocolServiceImpl.java:276` (agreement-lookup miss → `ServiceResult.notFound`) and `:264` (`validateAgreement` failure → `ServiceResult.conflict`), with the same reason text on both paths | yes, source |
| Codes 404 and 409 | `inv4.sh:60,158-159,179` | `DspRequestHandlerImpl.java:300-301` (`CONFLICT → 409`, `NOT_FOUND → 404`) applied to the two lines above | yes, source |
| Exclusion of the bare "Not found" | A4 Z1 | `TransferProcessProtocolServiceImpl.java:294` (a different, non-binding path) | yes, source |
| Parse shape: `errorDetail` as a JSON string carrying `dspace:code` / `dspace:reason` | `inv4.sh:58-59` | **Mixed.** The parser was written at 18:12:04 IST, after dry run 1 (snapshot `…T121754Z`, driver `450fe6…`, which had no such classifier) executed its INV-4 cells. In dry run 1 the mutation cell was the two-layer build, which **accepts** B, so no refusal `errorDetail` came from a mutated build in that run. A4 also cites "the dry run's captured errorDetail". The parse shape was therefore **probably informed by dry run 1's current-release cell**. | **no, as recorded** |
| The same parse shape, re-observed | dry run 2 (`…T124248Z`, driver `b641f94a…`), mutation cell | Gate-2-off control → `dspace:code` 404 plus the binding reason. Gate-1-off control → 409 plus the binding reason. Two-layer → accepted, with a provider transfer process present. The mutation cell reads FAIL (admission) only because both controls were classified `binding:404` / `binding:409` by the same parser. | yes, mutated builds |

**Assessment:**
- One element, the `errorDetail` parse shape, was first fitted after a current-release cell was seen. That is the contamination this check exists to catch.
- **Its effect is neutralised on the record:**
  - every value the classifier matches is fixed by source;
  - the shape is now independently confirmed on mutated builds with the frozen driver;
  - a shape mismatch fails safe (it falls to `nonbinding` and then INVALID, never PASS).
- **What still needs correcting is the provenance claim**, not the classifier (R1).

### 2. Specificity

**A real violation cannot read PASS:**
- PASS (`inv4.sh:179`) requires a parsed DSP `TransferError` whose code is 404 or 409 **and** whose reason is the binding text. An accepted request carries no `TransferError`.
- Any other termination is `INVALID:refused-non-binding` (`:180`).
- Residual edge: PASS does not also require that the provider holds **no** transfer process for B. That is low risk, but the guard is cheap (R3).

**A setup artefact cannot read FAIL:**
- FAIL (`:184`) requires A's positive control to be STARTED, B to be delivered, B to be in an accepted state, **and** a provider-side transfer process for B's `correlationId` (Z4).
- In the current cell, identity preconditions (Z2, `:173`) are checked first.
- The mutation cell does not call `identity_ok`. The 409 gate-1-off control does prove that B ≠ A there (an identity collision would pass the identity check), but A4 says "each mutation/current cell asserts" (R4).

### 3. Z2–Z5 as described in A4

- **Z2:** present in the current cell. In the mutation cell it is implied by the 409 control, not asserted (R4).
- **Z3:** implemented and verified on mutated builds (dry run 2). **Not stored as admission evidence:**
  - the per-gate classes appear only in `logs/inv4-tractusx-mutation.log`, which is overwritten each run and not snapshotted;
  - the dry-run row's `detail` column is empty.

  The batch row is therefore not self-standing admission evidence (R2).
- **Z4:** present in both the mutation path (`:162`) and the current path (`:184`).
- **Z5:** the sha is recorded in A4 and matches the live driver and the dry-run-2 snapshot.
- **Header guard (`e72f686`):** correct. It refuses to append to a cells file with a different schema and never rewrites one.

### 4. Is the frozen state fit for counting?

**Not yet:**
- The provenance record is wrong (R1).
- The admission evidence is not stored with the row (R2).

R2 needs a driver change, so the freeze moves.

| # | Fix | Sev |
|---|---|---|
| R1 | Correct A4 Z1 (tracked): provenance = `TransferProcessProtocolServiceImpl.java:264,276,294` and `DspRequestHandlerImpl.java:300-301` (EDC 0.17.0), plus the parse shape as confirmed on the **mutated-build** gate controls (dry run 2). Remove "the dry run's captured errorDetail". State that the parser was first written after a dry run that included a current cell, and that it is confirmed on mutated builds only. | **H** (blocking) |
| R2 | In the mutation branch, write the gate outcomes into the row's `detail`: `c1=<class>;c2=<class>;tl=<class>;provtp=<yes/no>`. These are mutated-build data, so they are safe to track. Commit an admission-evidence extract (mutation rows only) with commit, driver sha, snapshot and add-on jar shas. | **H** (blocking) |
| R3 | PASS also requires the provider to hold no transfer process for B (`B_PROVTP` empty). Otherwise `INVALID:acceptance-contradiction`. | M |
| R4 | Either call `identity_ok` in the mutation branch, or reword A4 Z2 to "current cell asserts; mutation cell implied by the 409 control". | M |

**Freeze rules for the fixes:**
- R2 and R3 may touch **only** the mutation branch (`inv4.sh:126-163`) and the PASS condition at `:179`. `classify_refusal` (`:56-60`) and every other current-cell line stay byte-identical.
- After the change, re-verify by running **sanity and mutation cells only** (no current cell).
- Record the new driver sha in A4, and commit before the batch.

**The batch:**
- After this review is committed, the counting batch runs from the resulting clean HEAD, not from `e72f686`. Only `REVIEW-phases.md` and the R1–R4 files may differ from it.
- The current-release cell was already run with the final classifier in dry run 2. That is acceptable for a dry run, but from here on **no** classifier change is allowed before counting.

### Verdict

**NOT CLEARED for 11-12 as frozen at `e72f686`.**

INV-4 becomes **CLEARED**, with no further review needed, once:
- R1 and R2 are committed;
- R3 and R4 are committed or explicitly deferred in A4;
- a sanity-and-mutation-only re-run on the new driver reads mutation FAIL with gate classes `binding:404` / `binding:409`;
- the coordinator confirms by diff that the driver change is confined to the mutation branch and the PASS line.

If any current-cell classifier line changes, a new review is required.

---

## Review 23 (phase-3 counting run: results-blind compliance), 2026-11-08

**Scope:** the RUN_KIND=real phase-3 run of 2026-11-07, snapshot `private/kc2/batches/34c98cc-20261107T181054Z`.

**Method:** results-blind. Every check below was done with scripts that print only match/mismatch, counts of structural columns, timestamps, or code line numbers. **No `result` or `detail` value of the run was read, printed or stated.** No PASS/FAIL, count or finding detail appears here.

### Checks

**1. D18 before the run: yes.**
- D18 local commit `34c98cc`: 2026-11-07T18:09:43Z.
- Mirror `51ca8fe`: pushed at 18:09:56Z (origin reflog).
- Run start (snapshot id and first row): 18:10:54Z / 18:10:55Z.
- D18's text says it was "decided before any counted current-release result exists". It is recorded as "user (coordinator-relayed: yes)" (see note N1).

**2. Row integrity: match.**
- Every row matches: commit `34c98cc`, run kind `real`, and the same snapshot.
- No duplicate (invariant, target, config). 16 invariant × target pairs, and all 16 have a current-config row.
- Snapshot `MANIFEST.sha256` hashes to `7dfcec97…012c2`, as reported, and the snapshot verifies against it.
- Each row's `driver_sha256` equals sha256(snapshot `inv<N>.sh` ‖ `p3lib.sh`) for INV-3, 4, 5, 6 and 8.
- INV-1, 2 and 7 have no driver file and an empty driver sha. That is consistent with them being fixed-class or NA by design (N2).
- The INV-4 snapshot driver sha is `11e56a4e…`, equal to A4 Z5 (`kc2/INVARIANTS.md:405`).

**3. Frozen state: yes.**
- No local or mirror commit after 18:10:00Z, and the tracked tree is clean.
- Every live private driver is byte-identical to its snapshot copy.

Review 22's clearing conditions were met before the run:
- the INV-4 driver diff from the dry-run-2 driver (`b641f94a`) touches only the mutation branch (snapshot lines 139–166) and the PASS line (182); `classify_refusal` is unchanged;
- the new sha is recorded in A4 Z5;
- the mutated-builds-only re-verification is committed as `kc2/env/inv4-admission-extract.csv` (5 rows: sanity, mutation, two single-gate controls and the two-layer control, all on driver `11e56a4e`), in `2f5a77b`, before the run.

**4. Exactly one real run: yes.**
- `batches/` holds this snapshot plus the two `dryrun-8a0599f-*` snapshots.
- One real cells file exists, plus the dry-run file and `phase3-cells.pre-review21-…csv.bak`.
- The `.bak` is an archived pre-schema file: 6 rows from 2026-10-28, commit `e287cfa`, no run-kind column. It predates every dry run, is not part of this run, and nothing was merged (N3).

**5. All terminal: yes.**
- All 16 cells are terminal, with a non-empty result and no infrastructure-error class: **yes**. Per the user's no-numbers rule, no further breakdown is given (corrected 2026-11-08).

**6. No leak: yes.**
- No commit after run start, locally or on origin. The tracked tree is clean.
- The last pre-run tracked edits (`2f5a77b` admission extract, `d98434b` README, `34c98cc` D18) all predate the run and carry no current-release data. The admission extract holds mutated-build cells only, as Review 22 permitted.

### Notes (non-blocking)

| # | Note | Sev |
|---|---|---|
| N1 | D18 cites the user's decision as coordinator-relayed. That is acceptable for a scheduling change made before results existed. For the report, cite where the user's own "yes" is recorded. | L |
| N2 | Cells with no driver carry an empty `driver_sha256`. The report should state that INV-1, 2 and 7 are by-design fixed-class or NA rows, not driver output. | L |
| N3 | Rename or annotate the `.bak` as "pre-schema exploratory, not counted", so a later reader cannot mistake it for a second run. | L |
| N4 | The D18 commit landed 71 s before the run started. That satisfies the order, but the margin is thin. Keep the run-start timestamp in the report next to the D18 push time. | L |

### Verdict

**COMPLIANT.** The phase-3 counting run was a single, clean, frozen-state run:
- at commit `34c98cc`, decided and pushed before it started;
- on the Review-22-cleared INV-4 driver;
- with every driver matching the snapshot manifest;
- with all 16 invariant × target cells terminal;
- with nothing from it in tracked history or on the mirror.
