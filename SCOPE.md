# Pilot 08 — DSP AuthFuzz: scope and defensive framing

**Pilot of:** Paper A core, idea [08 DSP AuthFuzz](../../ideas/08-dsp-authfuzz/idea.md) · kill test (frozen): [kill-test.md](../../ideas/08-dsp-authfuzz/kill-test.md)
**Timebox:** 3 weeks (feasibility pilot), extended to 2026-11-15 (D17). **Status:** started 2026-10-21.

## What this pilot is

A reproducible, **local-only regression-test suite** that checks whether open-source
Dataspace Protocol (DSP) connector builds enforce their own specified authorization
invariants. It uses three public, already-patched Eclipse EDC advisories as a
**correctness oracle**: a test is valid only if it flags the known-vulnerable build and
clears the patched build. Results are reported as **pass/fail**. The pilot performs no
network activity against any system the researcher does not themselves operate, and
discloses any gap found only through the Eclipse security process.

This is defensive security work: conformance-style testing of authorization behaviour,
in the same spirit as the official DSP TCK's protocol tests. It is not an exploit toolkit.

## Element-by-element framing

| Pilot element | Defensive framing |
|---|---|
| Conformance test driver (a DSP client/provider fixture) | A **test driver** that exercises a connector's authorization checks the way the DSP TCK exercises its protocol checks — a test fixture, not an exploit tool. |
| Rediscover the 3 EDC CVEs | **Regression tests for already-patched, publicly-disclosed advisories** (CVE-2024-4536, -9202, -8642), used as a correctness oracle: the test must fail on the vulnerable version and pass on the patched one. |
| Invariant catalogue | A set of **pass/fail assertions** derived from the DSP spec and the public advisories (catalogue visibility, token validity/nbf/iat, vault scoping, agreement-bound transfer). |
| Find new violations | **Two linked outputs:** (a) **invariant violations in connector builds that pass the official DSP TCK** — this is what kill condition 2 counts and what the frozen safe sentence asserts; and (b) the resulting **TCK coverage gaps**, offered upstream as candidate test contributions. |
| Targets | **Local-only** connectors the researcher runs themselves: vanilla Eclipse EDC assembled from the released Maven Central artifacts of each pinned version, with `iam-mock`, dependencies checksum-verified (kill condition 1, D5/D6) and Tractus-X EDC images pinned by digest (kill condition 2). No live or third-party systems are ever touched. |
| Output | **Pass/fail rows in a CSV** (build version, invariant ID, result, commit hash) plus upstream test contributions, under coordinated disclosure to the Eclipse security process. |

## Second boundary: LLM-gateway half (idea 10) — scoped separately

**Changed 2026-11-03 (D16, user):** the second boundary of Paper A is now the LLM-gateway
half ([idea 10](../../ideas/10-llm-gateway-authz/idea.md)), replacing the MCP half
(idea 01, folder deleted 2026-11-03; reason in [the killed list](../../ideas/_killed/README.md)), which moves to related work. The MCP
scoping note ([mcp-scoping.md](mcp-scoping.md)) is kept as a record.

The gateway half is **out of scope for this pilot's build phase**, like the MCP half was
(D10): it is built only after DSP kill condition 2 has a result, and only with the user's go.
When it is built it follows the same rules as this pilot: local-only, mock model providers
(no traffic to OpenAI/Anthropic or any third-party gateway), pass/fail results, already-patched
advisories as the oracle (FAIL on the affected version, PASS on the fixed one), and any
candidate finding kept out of public git history. Any report goes to **the affected project's
own private security channel** (GitHub private vulnerability reporting for LiteLLM, new-api,
one-api), under the same 90-day default embargo; it is the user's call and is never auto-sent.
Gateway images come from GHCR / Docker Hub (already-approved sources); PyPI would be a new
download source and needs asking first.

## Pilot exit criteria (3-week timebox)

Kill conditions are frozen in [kill-test.md](../../ideas/08-dsp-authfuzz/kill-test.md); summary and action:

| # | Kill condition (summary) | Action on firing |
|---|---|---|
| 1 | Harness fails to rediscover **≥2 of the 3** EDC CVEs on affected versions | **KILL the DSP half** — method broken; record and report. |
| 2 | On current EDC/Tractus-X, **0 new** invariant violations after the full set | **Downgrade** to a tool/workshop paper. |
| 3 | *(amended D16, 2026-11-03; was: MCP half <2 failures beyond the conformance drafts)* Gateway half: <4 of 6 pre-selected gateway advisories flip FAIL→PASS at their fixing version, **or** 0 new invariant violations on current releases of ≥3 gateways | **Drop the gateway half** to related work; Paper A becomes DSP-only. |
| 4 | AgentRFC full version **or** a TCK release adds DSP authorization-invariant tests before the pilot ends; *(added D16)* **or** a paper testing authorization/metering invariants across ≥3 LLM gateways appears | **Re-run Gate B** (novelty) for the affected half. |

How kill condition 1 is applied on the actual testbed (D4, D5): a CVE counts as rediscovered only if its test flips FAIL→PASS exactly at its fixing version on the vanilla EDC ladder (0.6.2 → 0.6.3 → 0.9.0 → 0.9.1; see [VERSIONS.md](VERSIONS.md)). A CVE whose code is not reachable on the ladder counts as **not rediscovered**. The frozen threshold (≥2 of 3) is unchanged.

Continue to kill condition 2 only if 1 passes. If 1 fails, stop the DSP half and report.

## Constraints and disclosure

- **Local testbed only.** Never scan or probe any third-party or live system.
- **No weaponization.** Assertions return pass/fail, not distributable exploit payloads.
- **Disclosure is the user's call.** Aakash decides whether and when to report. Any report
  goes to the **Eclipse security process only**. Default embargo: **90 days or until a patch
  ships, whichever comes first.** No advisory or email is ever auto-sent.
- **Candidate findings stay out of public git history.** The Masters repo may become a public
  artifact, so any candidate (new, undisclosed) finding is kept in an **untracked / gitignored**
  notes file until disclosure completes — never committed to the repo's public history.

## Reproducibility / integrity

- Environment versions and image digests live in [ENV.md](ENV.md).
- Every number in the report traces to a stored script output under `env/` (testbed evidence) or `results/` (test results). Anything observed but not stored is marked "not archived".
- Results CSVs record **build version, invariant ID, pass/fail, and commit hash only**.
- No CVE detail or result is invented; unverified items are marked UNVERIFIED.

## Deviations from the original plan

See [DECISIONS.md](DECISIONS.md). In short: the Eclipse MVD is not used (D3). Kill condition 1 runs on vanilla Eclipse EDC assembled from released Maven Central artifacts with `iam-mock` (D6), because Tractus-X 0.7.x requires a full DCP/DIM identity stack (D5); the paper claim for kill condition 1 is therefore "Eclipse EDC", not "Tractus-X". Kill condition 2 returns to Tractus-X once a local DCP identity stack exists (option A, deferred). D4 (2 of 3 CVEs on the Tractus-X ladder) is superseded for kill condition 1 by D5. CVE-2024-8642 does not count toward the 2-of-3 bar (D6): its module is removed rather than fixed at the patched version, so a PASS there would be vacuous. Kill condition 1 therefore rests on -4536 and -9202, and both must flip.

## Standing approvals (user, 2026-10-21)

- **Downloads under 5 GB each** from sources already used by the pilot are pre-approved: Docker Hub / GHCR images, Maven Central / Gradle dependencies and distribution, Gradle Plugin Portal build plugins (added 2026-10-21), JDK/tooling installers, and **GitHub source clones of the open-source projects under test** (e.g. `eclipse-edc/Connector` at pinned tags; added 2026-10-21). Log each one in [ENV.md](ENV.md) (name, source, size, digest or commit SHA, date).
- **Commits** of files the pilot creates or modifies under `pilots/08-dsp-authfuzz/` are pre-approved.
- **Still ask first:** any single download ≥ 5 GB; any new download source; commits outside `pilots/`; any disclosure. Never force-push.
- Downloads happen only in a build/pull step; the runtime testbed network stays internal (no egress).
