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
  into `private/kc2/`; tracked files carry only the **count** of candidate findings, split INV-1..5 vs
  INV-6..8, with no invariant/version/mechanism detail.
