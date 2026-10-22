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
