<div align="center">

# authz-ladder

**Regression-testing authorization invariants in Dataspace Protocol connectors,<br>using already-patched CVEs as a correctness oracle.**

![status](https://img.shields.io/badge/status-feasibility%20pilot-orange)
![KC1](https://img.shields.io/badge/kill%20condition%201-passed-success)
![KC2](https://img.shields.io/badge/kill%20condition%202-phase%203%20in%20progress-yellow)
![scope](https://img.shields.io/badge/scope-local%20testbed%20only-blue)
![output](https://img.shields.io/badge/output-pass%2Ffail%20only-lightgrey)
![SUT](https://img.shields.io/badge/SUT-Eclipse%20EDC%20%7C%20Tractus--X%20EDC-6f42c1)

</div>

---

## What this is

Data spaces (Gaia-X, Catena-X, Manufacturing-X) exchange data between companies through
**connectors** that speak the [Dataspace Protocol](https://docs.internationaldataspaces.org/ids-knowledgebase/dataspace-protocol) (DSP).
The official DSP TCK checks that connectors speak the protocol correctly. It does not check
that they enforce their own **authorization rules**: who may see which dataset, whose secrets
a counterparty can make the provider use, whether a transfer is bound to its agreement.

**authz-ladder** is a local-only regression-test suite for those rules. Each test is a
pass/fail assertion about one invariant, and a test is admitted only once it is shown to measure
something real:

> A test is valid only if it **FAILS on the affected release** and **PASSES on the patched release**,
> flipping at exactly the version that shipped the fix.

Admitted tests are then run against **current releases that pass the official DSP TCK**, to look for new violations.

## Results so far

### Kill condition 1: the method rediscovers known flaws ✅ passed (2026-10-24)

On vanilla Eclipse EDC with `iam-mock`, assembled from released Maven Central artifacts under
Gradle dependency verification, one jar set, one clean commit:

```
                      0.6.2    0.6.3    0.9.0    0.9.1
CVE-2024-4536 vault   FAIL ──▶ PASS     PASS     PASS
CVE-2024-9202 catalog FAIL     FAIL     FAIL ──▶ PASS
```

Both tests flip exactly at their fixing version, with positive controls on every cell
(the admitted party still gets its data; a real transfer reaches the sink). The -4536 test runs
**through DSP**, with a second connector as the counterparty, as a real participant would.
CVE-2024-8642 does not count: its module is removed rather than fixed, so a PASS would be vacuous (D6).

| CVE | Invariant | Affected → fixed | Evidence |
|---|---|---|---|
| [CVE-2024-4536](https://osv.dev/vulnerability/CVE-2024-4536) | **Vault scoping**: a counterparty cannot choose which provider secret is dereferenced | ≤ 0.6.2 → **0.6.3** | [`results/cve-2024-4536.csv`](results/cve-2024-4536.csv) |
| [CVE-2024-9202](https://osv.dev/vulnerability/CVE-2024-9202) | **Catalogue visibility**: a single-dataset request obeys the catalogue policy (CWE-862) | ≤ 0.9.0 → **0.9.1** | [`results/cve-2024-9202.csv`](results/cve-2024-9202.csv) |

### Kill condition 2: new violations on current releases 🟡 in progress

| Step | State | Evidence |
|---|---|---|
| Current targets pinned: **Tractus-X EDC 0.13.0** (bundles EDC 0.17.0) and **vanilla EDC 0.18.1** | ✅ | [`kc2/env/targets.csv`](kc2/env/targets.csv) |
| Real identity layer (DCP): Eclipse IdentityHub + IssuerService 0.17.0, Tractus-X BDRS, did:web, locally issued MembershipCredential | ✅ | [`DECISIONS.md`](DECISIONS.md) D11–D13 |
| DCP-authenticated catalogue between connectors, both targets; isolation re-verified with the full stack up | ✅ 51/51 | [`kc2/env/handshake-smoke.csv`](kc2/env/handshake-smoke.csv), [`kc2/env/net-isolation.csv`](kc2/env/net-isolation.csv) |
| **Official DSP TCK 1.0.2** (upstream TCK configuration) | ✅ **65/65 on both targets** | [`kc2/env/tck-dsp-tractusx.csv`](kc2/env/tck-dsp-tractusx.csv), [`kc2/env/tck-dsp-vanilla.csv`](kc2/env/tck-dsp-vanilla.csv) |
| DCP TCK on the identity stack | ⏸ deferred (D15) | [`kc2/TCK-PLAN.md`](kc2/TCK-PLAN.md) |
| Invariant catalogue frozen before any test: **INV-1…INV-8**, each with a sanity config (must PASS) and a mutation (must FAIL) | ✅ | [`kc2/INVARIANTS.md`](kc2/INVARIANTS.md) |
| Phase 3: frozen invariants against the current releases | 🟡 in progress | results private until disclosure (see below) |

## Repository layout

```
.
├── SCOPE.md            binding scope, defensive framing, standing approvals
├── DECISIONS.md        decision log (D1–D15)
├── VERSIONS.md         CVE pinning and the version ladder, with sources
├── ENV.md              every pinned image, digest, download and toolchain version
├── PILOT-REPORT.md     running results log
├── REVIEW-*.md         independent read-only reviews of every phase
├── mcp-scoping.md      MCP half (second protocol): conformance-coverage desk study, deferred (D10)
├── env/  results/      kill condition 1 evidence and verdicts
├── scripts/            kill condition 1: build, boot, tests, one-batch runner (bash + curl + jq)
├── testbed/            vanilla EDC + iam-mock launcher, receiver, Tractus-X compose
└── kc2/                kill condition 2
    ├── INVARIANTS.md   frozen invariant catalogue
    ├── TCK-PLAN.md, HANDSHAKE-PLAN.md
    ├── identity/ vanilla/ tck*/   dependency-verified launchers
    ├── scripts/        targets, identity stack, handshake, TCK, phase-3 runner
    └── env/            KC2 infrastructure evidence (no test results)
```

## Running it

Requirements: Docker with Compose, bash (Git Bash works on Windows), curl, jq.
Nothing listens on the host. All traffic stays on internal Docker networks and is driven from a
throwaway container. Builds run in pinned Gradle containers with checksum-verified dependencies.

```bash
# Kill condition 1: the four-version ladder, one batch on one clean commit
./scripts/02_pull_driver.sh
for v in 0.6.2 0.6.3 0.9.0 0.9.1; do ./scripts/30_build_vanilla.sh $v; done
./scripts/50_kc1_batch.sh                  # -9202 and -4536 tests, writes results/ + env/

# Kill condition 2: current targets with the real DCP identity layer
./kc2/scripts/00_pull_targets.sh
./kc2/scripts/10_build_identity.sh && ./kc2/scripts/11_build_vanilla.sh
./kc2/scripts/30_up_identity.sh
./kc2/scripts/40_up_handshake.sh           # Tractus-X 0.13.0
./kc2/scripts/41_up_handshake_vanilla.sh   # vanilla EDC 0.18.1
./kc2/scripts/50_tck_baseline.sh vanilla   # official DSP TCK (also: tractusx)
```

Every evidence row records the commit it ran on (with `-dirty` if the tree had uncommitted changes)
and the checksum of the exact binary tested.

## Scope and ethics

This is **defensive** research: conformance-style testing in the spirit of the DSP TCK, not an exploit toolkit.

- **Local testbed only.** Never scans or probes any third-party or live system.
- **Pass/fail only.** Assertions report results; no exploit payloads are published.
- **Coordinated disclosure.** Kill condition 2 tests, results and notes stay out of this repository.
  Any new finding goes only to the Eclipse security process, under a 90-day default embargo,
  and is published here only after disclosure completes.
- **Integrity.** Every number traces to a stored file; anything unverified is marked UNVERIFIED.
  Every phase was reviewed independently ([REVIEW-phases.md](REVIEW-phases.md)).

Full rules: [SCOPE.md](SCOPE.md).

## Part of

Paper A of a Masters research project, *securing the agent/software supply chain: intermediaries nobody verifies*.
A second protocol (MCP authorization) is scoped and deferred until kill condition 2 has a result (D10).
Some links in the docs point to planning files kept outside this repository.

<div align="center"><sub>Built on <a href="https://github.com/eclipse-edc/Connector">Eclipse EDC</a>, <a href="https://github.com/eclipse-edc/IdentityHub">Eclipse IdentityHub</a> and <a href="https://github.com/eclipse-tractusx/tractusx-edc">Tractus-X EDC</a>. Not affiliated with the Eclipse Foundation.</sub></div>
