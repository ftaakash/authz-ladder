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
