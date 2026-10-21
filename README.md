<div align="center">

# authz-ladder

**Regression-testing authorization invariants in Dataspace Protocol connectors,<br>using already-patched CVEs as a correctness oracle.**

![status](https://img.shields.io/badge/status-feasibility%20pilot-orange)
![scope](https://img.shields.io/badge/scope-local%20testbed%20only-blue)
![output](https://img.shields.io/badge/output-pass%2Ffail%20only-lightgrey)
![sut](https://img.shields.io/badge/SUT-Eclipse%20EDC-6f42c1)
![harness](https://img.shields.io/badge/harness-bash%20%2B%20curl%20%2B%20jq-success)

</div>

---

## What this is

Data spaces (Gaia-X, Catena-X, Manufacturing-X) exchange data between companies through
**connectors** that speak the [Dataspace Protocol](https://docs.internationaldataspaces.org/ids-knowledgebase/dataspace-protocol) (DSP).
The official DSP TCK checks that connectors speak the protocol correctly. It does not check
that they enforce their own **authorization rules**: who may see which dataset, whose secrets
a counterparty can make the provider use, whether transfer tokens are validated.

**authz-ladder** is a local-only regression-test suite for those rules. Each test is a
pass/fail assertion about one invariant. A test is admitted only if a known, public,
already-patched advisory proves it measures something real:

> A test is valid only if it **FAILS on the affected release** and **PASSES on the patched release**,
> flipping at exactly the version that shipped the fix.

Once a test passes this oracle, it can be run against current releases.

## The oracle

| CVE | Invariant | Affected → fixed | Counts toward kill condition 1 |
|---|---|---|---|
| [CVE-2024-4536](https://osv.dev/vulnerability/CVE-2024-4536) | **Vault scoping**: a counterparty cannot choose which provider secret is dereferenced | ≤ 0.6.2 → **0.6.3** | ✅ |
| [CVE-2024-9202](https://osv.dev/vulnerability/CVE-2024-9202) | **Catalogue visibility**: a single-dataset request obeys the same policy filter as the catalogue (CWE-862) | ≤ 0.9.0 → **0.9.1** | ✅ |
| [CVE-2024-8642](https://osv.dev/vulnerability/CVE-2024-8642) | **Token validity**: transfer tokens are checked for expiry before use | ≥ 0.5.0 → 0.9.0 | ❌ supporting evidence only. The module is *removed*, not fixed, at 0.9.0, so a PASS there would be vacuous (D6) |

### The ladder

No single affected/patched pair covers all three fixes, so the oracle is a **four-rung version ladder**
of vanilla Eclipse EDC with `iam-mock`:

```
            0.6.2          0.6.3          0.9.0          0.9.1
-4536     FAIL ─────────▶ PASS           PASS           PASS
-9202     FAIL           FAIL           FAIL ─────────▶ PASS
```

Every column must match this pattern exactly, or the test is rejected as not measuring its CVE.
Full derivation, sources and fix commits: [VERSIONS.md](VERSIONS.md).

## Status

> Feasibility pilot, 3-week timebox, started 2026-10-21. **No CVE assertion has run yet.**

| Milestone | State | Evidence |
|---|---|---|
| Tractus-X ladder pinned by digest and verified (5 rungs) | ✅ done | [`env/image-check.csv`](env/image-check.csv), [`env/pins.tsv`](env/pins.tsv) |
| Network isolation (internal network, no egress, no host ports) | ✅ verified 7/7 | [`env/net-isolation.csv`](env/net-isolation.csv) |
| Tractus-X R1 boot + smoke | ✅ 5/5 | [`env/boot-smoke.csv`](env/boot-smoke.csv) |
| Switch to vanilla EDC + `iam-mock` for kill condition 1 (D5) | 🟡 in progress | [`DECISIONS.md`](DECISIONS.md) |
| `iam-mock` present at all four ladder versions | ✅ | [`env/iam-mock-check.csv`](env/iam-mock-check.csv), [`env/maven-modules.csv`](env/maven-modules.csv) |
| Vanilla 0.6.2 builds, boots, mock-identity DSP call accepted | ✅ 3/3 | [`env/vanilla-smoke.csv`](env/vanilla-smoke.csv) |
| Vanilla 0.6.3 / 0.9.0 / 0.9.1 | ⏳ | — |
| Regression tests for -4536 and -9202 | ⏳ not started | — |

Running log: [PILOT-REPORT.md](PILOT-REPORT.md) · Decisions: [DECISIONS.md](DECISIONS.md) · Reviews: [REVIEW-testbed.md](REVIEW-testbed.md), [REVIEW-phases.md](REVIEW-phases.md)

## Kill conditions

The pilot exists to find out early whether this is worth a paper.

| # | Fires if… | Then |
|---|---|---|
| 1 | Fewer than 2 of 3 CVEs are rediscovered on the ladder (in practice **both** -4536 and -9202 must flip) | Stop: the method is broken |
| 2 | Zero new invariant violations on current releases | Downgrade to a tool/workshop paper |
| 3 | The MCP half finds < 2 failures beyond the conformance drafts | Drop MCP; DSP-only |
| 4 | A TCK release or prior work ships DSP authorization-invariant tests first | Re-check novelty |

## Repository layout

```
.
├── SCOPE.md            binding scope, defensive framing, standing approvals
├── DECISIONS.md        decision log (D1–D6)
├── VERSIONS.md         CVE pinning and version ladder, with sources
├── ENV.md              every pinned image, digest, download and toolchain version
├── PILOT-REPORT.md     running results log
├── field-bound.md      related-work bound (kill condition 4 check)
├── REVIEW-*.md         independent read-only reviews of the pilot
├── env/                stored evidence: one CSV/TXT per check
├── scripts/            numbered, re-runnable steps (bash + curl + jq)
└── testbed/
    ├── compose.yaml    Tractus-X testbed (kill condition 2), internal network
    └── launcher/       vanilla EDC + iam-mock launcher (kill condition 1)
```

## Running it

Requirements: Docker with Compose, bash (Git Bash works on Windows), curl, jq.
Nothing listens on the host; all traffic stays on internal Docker networks and is
driven from a throwaway driver container.

```bash
# Kill condition 1: vanilla EDC ladder
./scripts/02_pull_driver.sh          # pinned curl driver image
./scripts/30_build_vanilla.sh 0.6.2  # build in a pinned gradle container (needs egress)
./scripts/31_run_vanilla.sh 0.6.2    # boot on an internal network, write env/vanilla-smoke.csv

# Kill condition 2: Tractus-X testbed
./scripts/00_pull_images.sh && ./scripts/01_verify_images.sh
./scripts/10_gen_keys.sh             # throwaway local test keys (gitignored)
TX_TAG=0.7.0 ./scripts/20_up.sh && ./scripts/21_smoke.sh
./scripts/05_net_check.sh            # isolation proof, writes env/net-isolation.csv
```

Every output row records the commit it ran on, with `-dirty` appended if the tree had uncommitted changes.

## Scope and ethics

This is **defensive** research: conformance-style testing in the spirit of the DSP TCK, not an exploit toolkit.

- **Local testbed only.** Never scans or probes any third-party or live system.
- **Pass/fail only.** Assertions report results; no exploit payloads are published.
- **Coordinated disclosure.** Any new finding goes only to the Eclipse security process, under a
  90-day default embargo. Undisclosed findings never enter this repository's history.
- **Integrity.** Every number traces to a stored file in `env/` or `results/`; anything unverified is marked UNVERIFIED.

Full rules: [SCOPE.md](SCOPE.md).

## Part of

Paper A of a Masters research project, *securing the agent/software supply chain: intermediaries nobody verifies*.
A second protocol (MCP authorization) is scoped for later. Some links in the docs point to planning
files that are kept outside this repository.

<div align="center"><sub>Built on <a href="https://github.com/eclipse-edc/Connector">Eclipse EDC</a> and <a href="https://github.com/eclipse-tractusx/tractusx-edc">Tractus-X EDC</a>. Not affiliated with the Eclipse Foundation.</sub></div>
