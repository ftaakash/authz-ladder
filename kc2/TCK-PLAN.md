# KC2 TCK baseline — plan (between the handshake and phase 3)

**Why.** The frozen claim's premise is that findings are in builds that **pass the official conformance
suites**. So before any phase-3 invariant verdict counts, each current target must be shown to **pass
the official DSP TCK** in its DCP-configured form, and the IdentityHub to pass the **DCP TCK**. Phase-3
verdicts do **not** run until this baseline exists (Review 13 S1).

## Source (already approved — no new download source)

- **Maven Central** hosts the TCK libraries: `org.eclipse.dataspacetck.dsp:dsp-tck`,
  `org.eclipse.dataspacetck.dcp:dcp-testcases`, `org.eclipse.dataspacetck.common:tck-runtime`
  (checked 2026-10-26: all 200; DSP TCK versions through **1.0.2** present).
- **Docker Hub** hosts runtime images under `eclipsedataspacetck/*` (`dsp-tck-runtime`, `dcp-tck-runtime`).
Both are sources the pilot already uses (SCOPE standing approvals), so the TCK phase needs no new
approval. Pin by version (Maven) or digest (image) and log in ENV.md like every other download.

## Targets and suites

| Suite | Version | Run against |
|---|---|---|
| DSP TCK | **1.0.2** (latest 1.0.x) | each current target connector (Tractus-X 0.13.0; vanilla EDC 0.18.1) in its DCP-configured form |
| DCP TCK | **1.2.1** (confirm availability; else nearest 1.2.x and log) | the IdentityHub 0.17.0 presentation/STS endpoints |

If 1.2.1 is not on Maven Central, pin the nearest available 1.2.x and record the substitution here.

## Procedure

1. Pin the TCK version/image; log in ENV.md (source, version/digest, date).
2. Configure the TCK's connector-under-test hooks to point at the target's DSP endpoint with the local
   DCP identity stack (same stack as the handshake).
3. Run the suite; archive **per-test pass/fail** to `kc2/env/tck-dsp-<target>.csv` and
   `kc2/env/tck-dcp-identityhub.csv` (test id, result, suite version, target image/jar digest, commit).
   These are conformance results on public specs — **not** findings — so they are tracked (not private).
4. **If a target fails one or more TCK tests:** record it and **narrow the claim** for that target
   (the premise "passes the official suite" no longer holds unqualified); never silently drop the target.

## Phase-3 gating and tally rules (Review 13 S4)

- Phase 3 runs the frozen invariants (INV-1..8) against the current targets **only after** this baseline
  is archived and green (or its failures recorded and the claim narrowed).
- Every KC2 tally reports **INV-1..5** (original freeze, `a8cd4df`) and **INV-6..8** (amendment A1,
  `8479f2f`) **separately**. A rediscovery of a **KC1 CVE** by INV-1 (−9202) or INV-2 (−4536) on a
  current release is a regression, **never** counted as a NEW violation.
- All phase-3 run output (assertions, observations, verdicts, notes) goes through `kc2_private_out`
  into `private/kc2/`. Tallies (kept private) split INV-1..5 vs INV-6..8. **Tracked files and commit messages
  carry no phase-3 number at all, not even a total** — only "phase 3 run complete, results private" — until
  the user approves publishing a number (Review 15 U1, 2026-10-29).

## How the DSP TCK authenticates — facts at the pinned tags (Review 14 T3, 2026-10-27)

- **Upstream does not run the DSP TCK through DCP.** Tractus-X 0.13.0 (`edc-tests/e2e/dsp-tck-tests/…/EdcCompatibilityPostgresTest.java`,
  `src/test/resources/docker.tck.properties`) starts the TCK image `eclipsedataspacetck/dsp-tck-runtime:1.0.0` and has it send
  a **static** `Authorization` header with a mock-IAM body (`{"region":"any","audience":"any","clientId":"any"}`)
  against a dedicated **TCK runtime** (`:edc-tests:runtime:runtime-dsp` + `org.eclipse.edc:tck-extension`, which seeds the
  scenario datasets/agreements `CAT0101`, `ACN0101`, `ATP0101`, … and exposes the TCK webhook endpoints). Vanilla EDC v0.18.1
  does the same in `system-tests/tck/dsp-tck-connector-under-test` + `system-tests/tck/tck-extension`.
- So "passes the official DSP TCK" is, upstream, a property of a **TCK-configured runtime built from the same release
  code with mock identity**, not of the release image's DCP configuration.
- Sources needed are all already approved: TCK image (Docker Hub; pin by digest), `org.eclipse.edc:tck-extension`
  (Maven Central, present at 0.17.0 and 0.18.1), DSP TCK libraries 1.0.0–1.0.2 (Maven Central).

**Options for the baseline (user decision at step 3):**
- **A — reproduce the upstream TCK configuration per target** (recommended baseline): a TCK runtime assembled from each target's
  pinned release artifacts + `tck-extension`, mock-IAM header exactly as upstream, TCK image pinned by digest, run on the internal
  network; per-test pass/fail to `kc2/env/tck-dsp-<target>.csv`. Faithful to how the premise is established upstream.
- **B — additionally, DSP TCK against the DCP-configured target**: a fourth `tck` participant seeded through the same IdentityHub/
  issuer/BDRS path; its STS mints a long-lived self-issued token (`edc.iam.sts.token.expiration`) that the TCK sends as the static
  header; its DID's CredentialService serves its VP. Stronger, but still needs `tck-extension` in the runtime for the scenario seeding.
Either way TCK failures **narrow the claim; they do not block** phase 3.

**Decision (D14, 2026-10-28): Option A.** Claim wording: the targets *pass the official DSP TCK in the upstream TCK
configuration (mock identity), without the real identity protocol (DCP)*. Option B is not run.

## Baseline result (2026-10-28/29) — both targets pass

| Target | Connector-under-test | DSP TCK | Result | Evidence |
|---|---|---|---|---|
| vanilla EDC 0.18.1 | upstream `dsp-tck-connector-under-test` reproduced (`controlplane-base-bom` + `tck-extension` 0.18.1), jar `404149ac…` | 1.0.2 (`sha256:f5f7fcc8…`) | **65/65 pass** | `kc2/env/tck-dsp-vanilla.csv`, `.txt` |
| Tractus-X 0.13.0 | **release image binary** (`sha256:bc54335d…`) + add-on (`tck-extension` 0.17.0 + upstream test stand-ins), add-on `28f0cc3c…` | 1.0.2 | **65/65 pass** | `kc2/env/tck-dsp-tractusx.csv`, `.txt` |

65 scenarios each: catalogue (3), metadata (1), contract negotiation provider (15) / consumer (16), transfer process
provider (15) / consumer (15). Per D14 the claim is *"pass the official DSP TCK in the upstream TCK configuration (mock
identity), without the real identity protocol (DCP)"*. TCK 1.0.2 = latest release; upstream pins 1.0.0 (Tractus-X) and
1.0.0-RC6 (vanilla).

**Reproduction validity checks.** (1) Network adaptation of upstream's config: connector host → `cut`, TCK callback →
`http://tck:8083` (a first vanilla run with upstream's `0.0.0.0` callback timed out on every callback scenario — discarded as a
setup artifact). (2) Tractus-X stand-ins are asserted from the boot log before results are recorded: `IdentityService` →
`NoopIdentityService`, `PolicyArchive` → `TckPolicyArchive`, `BdrsClient` → `TckPassThroughBdrsClient`. A first Tractus-X
run in which the PolicyArchive stand-in lost the provider race (11 transfer-provider scenarios failed on a null policy
assignee) was discarded as a setup artifact; the stand-in is now ordered deterministically.
**Phase-3 gate (this file): met** — baseline archived and green for both targets.

**Review 15 U3/U4 (2026-10-29).** Stand-in provenance and a line-by-line comparison with upstream are in
`kc2/env/tck-tx-standins.md`: the reproduction changes **load order and naming only, no policy semantics** (plus the stated
runtime difference: in-memory release binary vs. upstream's PostgreSQL runtime). The raw output of the two **discarded** runs
(vanilla callback-address run; Tractus-X lost-PolicyArchive run) was deleted when the runs were discarded and is **not archived**;
their failure signatures are recorded above from the session observations (vanilla: callback scenarios timed out after 7 s;
Tractus-X: 11 transfer-provider scenarios, NPE on `Policy.getAssignee()`).
