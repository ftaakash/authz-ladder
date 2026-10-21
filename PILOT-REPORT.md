# Pilot 08 — DSP AuthFuzz: pilot report

Running log of the feasibility pilot. Every number traces to a script output under
`results/` or `env/`; unverified items are marked UNVERIFIED. Defensive scope: see [SCOPE.md](SCOPE.md).

## Status at 2026-10-21

| Milestone | State |
|---|---|
| Testbed pinned & pulled (Route A, 5 rungs) | DONE (`env/image-check.csv`) |
| R1 boots, smoke 5/5 | DONE (`env/boot-smoke.csv`; R1 / tx 0.7.0 only) |
| **Local-only network isolation** | **DONE, verified** (`env/net-isolation.csv`; R1 only) |
| In-network driver harness | DONE (smoke now driven from inside the net) |
| SUT switch to vanilla EDC + `iam-mock` (D5, option B) | **DONE** — all 4 rungs (0.6.2/0.6.3/0.9.0/0.9.1) build, boot, smoke (`env/vanilla-jars.csv`, `env/vanilla-smoke.csv`) |
| Identity stubs (DID:web / STS / BDRS) + consumer | superseded by D5: Tractus-X DCP/DIM deferred to KC2 (option A). iam-mock gives an authenticated counterparty (DSP + mock token → 200) |
| Test fixtures: F1 bound constraint, F5 mgmt auth | **DONE** — F1 registers + discriminates (alice sees / mallory hidden); F5 enforces mgmt key (401/200) |
| F3 seeded canary vault | **NOT STARTED** — needed only for -4536 |
| **KC1 test — CVE-2024-9202** (catalogue bypass, 0.9.0→0.9.1) | **DONE, ADMITTED** — 0.9.0 FAIL / 0.9.1 PASS (`results/cve-2024-9202.csv`) |
| KC1 test — CVE-2024-4536 (vault scoping, 0.6.2→0.6.3) | **NOT STARTED** — needs F3 + a full OAuth2 push-transfer flow |
| KC1 verdict (needs BOTH -9202 and -4536) | **PENDING** — 1 of 2 rediscovered |

## 1. Local-only network isolation — closed and verified

The gap: the testbed network was a default bridge, so containers had outbound internet
(a provider-container `wget https://example.com` returned `EGRESS_OK` — observed in session, not archived). SCOPE.md
promises local-only operation, so this had to close before any test ran.

Fix: `testbed/compose.yaml` network `dsp` is now `internal: true`. All images are already
pulled by digest, so no egress is needed at runtime.

Consequence (important for the harness design): an internal Docker network has **no NAT**, so
Docker also stops publishing container ports to the host — a host-driven harness (curl to
`127.0.0.1:<port>`) can no longer reach the connectors (all requests returned `000` — not archived). A
bridge with IP-masquerade disabled was tested as a less-invasive alternative but **did not**
block egress on this Docker Desktop / WSL2 host (`EGRESS: REACHED` — observed in session, not archived). So the harness now runs
from an **ephemeral driver container joined to the internal network** (`pilot08/curl:8.11.1`,
already local), reaching connectors by service name. Nothing is exposed off-box.

Verification (`scripts/05_net_check.sh` → `env/net-isolation.csv`, all `ok=yes`):

| check | expected | got |
|---|---|---|
| network_internal_flag | true | true |
| egress_probe_control (same `wget` → provider:8080) | REACHED | REACHED |
| egress_ip_1.1.1.1 | BLOCKED | BLOCKED |
| egress_dns_example.com | BLOCKED | BLOCKED |
| embedded_dns_provider | RESOLVES | RESOLVES |
| driver_to_provider_health | 200 | 200 |
| host_published_ports | 0 | 0 |

The positive control shows the probe itself works, so the BLOCKED rows are meaningful. Smoke through
the driver is 5/5 (`env/boot-smoke.csv`): health 200, management no-key 401, management key 200,
**DSP catalog no-auth 401, fake-bearer 401**. Both CSVs hold one run each, on R1 (tx 0.7.0) only, and are
stamped with the commit they ran on; they must be re-run on a clean commit against the vanilla SUT (D5).

## 2. KC1 blocker — counterparty authentication needs a full DCP/DIM identity stack

Both in-scope invariants are reachable **only** through the DSP protocol API:
- **-9202** (catalogue visibility): the single-dataset DSP request path in `DatasetResolverImpl`.
- **-4536** (vault scoping): the OAuth2 data-sink transfer, negotiated over DSP.

The DSP API in Tractus-X 0.7.x rejects unauthenticated **and** bogus-token requests:
`dsp_catalog_noauth → 401`, `dsp_catalog_fakebearer → 401`. Exercising either invariant
therefore requires a second participant that presents a **valid** DCP token.

Jar inspection of R1 (`/app/edc-controlplane.jar`, Tractus-X 0.7.0 / EDC 0.6.1) shows the
auth path is full DCP/IATP with **no mock/dev IAM** to shortcut it:
- `org/eclipse/tractusx/edc/iam/iatp/sts/dim/DimSecureTokenService` → STS is **remote (DIM)**:
  the connector delegates token creation to a hosted wallet at `EDC_IAM_STS_DIM_URL`.
- `IatpIdentityExtractor`, `CredentialScopeExtractor`, `MembershipCredentialConstraintFunction`,
  trusted-issuer and BDRS classes (42 DCP/IATP classes total). Listing archived in `env/jar-iatp.txt`.
- The only `*IdentityService` match is Jetty's unrelated `DefaultIdentityService` — not an IAM mock.

So a counterparty that the provider will accept must present a **Verifiable Presentation
containing a MembershipCredential issued by a trusted issuer**, obtained via a DIM-style STS.
Standing that up locally means emulating: did:web documents (static, easy), a BDRS BPN→DID
map (easy), a **DIM/STS wallet that mints Self-Issued tokens and VPs** (hard), and a
**trusted-issuer VC issuance + seeding** into each connector's credential store (hard, and
`edc-runtime-memory` bundles no identity hub). This is the "Open setup risk" flagged in
[VERSIONS.md](VERSIONS.md); it is now confirmed as the gating item and is not a single-session build.

## 3. Decision needed before KC1 can run

| Option | What it is | Cost | Effect on the claim |
|---|---|---|---|
| **A. Build the local DCP/DIM identity stack** | Emulate did:web + BDRS + a DIM-style STS wallet (VP + MembershipCredential) + trusted issuer, as a new `identity` service (compose only has the provider's env pointing at `http://identity:8000/…`; no such service exists yet) | High (multi-session; JWT/VP signing, credential seeding) | Highest fidelity; keeps "connectors that pass the official suites" framing intact |
| **B. Switch the SUT to a build/config with a mock IAM** | e.g. vanilla EDC with `iam-mock`, or an older MVD with a simpler identity stack | Medium, but needs a **source build + dependency download** (user OK required; egress now blocked) | SUT is no longer the Tractus-X distribution (reopens D3); also changes -8642 reachability |
| **C. Reduce the oracle to a layer reachable without counterparty auth** | Test the invariants below the DSP auth boundary | Low | Likely **fails the admission rule** — both CVEs live behind DSP auth, so a non-DSP probe would not faithfully "FAIL on affected" |

Recommendation at the time was **A**; superseded by the user's choice of **B** — see §4.
Feasibility of B was verified this session: the `iam-mock` module is present in
`eclipse-edc/Connector` at **all four** ladder tags (v0.6.2 / v0.6.3 / v0.9.0 / v0.9.1), read from
the GitHub tree at each tag and recorded in `env/iam-mock-check.csv` (per-tag commit SHAs to be
captured at clone). So two locally-built EDC connectors can complete DSP flows without a DCP/DIM wallet.

## Evidence index
Every number above traces to a file under `env/` or `results/`; anything observed but not stored is marked "not archived".
- `env/net-isolation.csv` — local-only verification incl. positive control (R1 only)
- `env/boot-smoke.csv` — boot sanity through the driver, 5 checks incl. fake-bearer (R1 only)
- `env/image-check.csv` — per-rung jar/class evidence
- `env/jar-iatp.txt` — R1 IATP/DCP class listing (42 entries, no mock IAM, DIM STS)
- `env/iam-mock-check.csv` — `iam-mock` present at the four vanilla ladder tags
- `results/logs/` — pull + boot logs (**not in git**: `*.log` is ignored at repo root; un-ignoring needs a root `.gitignore` change)
- Decisions: [DECISIONS.md](DECISIONS.md) (D1–D5). §3 resolved to **B** (D5) — see §4.

## 4. Resolution of §3 (2026-10-21)

User chose **B** (logged as D5 in [DECISIONS.md](DECISIONS.md)); the "Recommendation: A" above is superseded.
KC1 runs on vanilla EDC + `iam-mock` at the four pinned tags in [VERSIONS.md](VERSIONS.md); A is deferred to KC2.
KC1 rule (as in SCOPE.md): a CVE counts as rediscovered only if its test flips FAIL→PASS exactly at its
fixing version on the vanilla ladder 0.6.2 → 0.6.3 → 0.9.0 → 0.9.1 (-4536 at 0.6.2→0.6.3, -8642 at
0.6.3→0.9.0, -9202 at 0.9.0→0.9.1). A CVE whose code is not reachable on the ladder counts as not
rediscovered. The frozen threshold (≥2 of 3) is unchanged. D4 is superseded for KC1.
Next steps, in order:
1. ~~Confirm `iam-mock` exists at each pinned tag~~ — done: present at all four tags (`env/iam-mock-check.csv`); per-tag commit SHAs are captured at clone.
2. Estimate the source-build download size; under 5 GB from Maven Central/Gradle is pre-approved, log it in ENV.md. Build inside the testbed, keep the `dsp` network internal at runtime. (Rough estimate this session: Gradle distribution ~150 MB + Maven deps ~0.3–0.8 GB across the 4 tags + source clones — under the 5 GB pre-approval; the build itself is a long-running job, minutes × 4 tags, so confirm before starting.)
3. Re-check -8642 reachability on the vanilla ladder (`transfer-data-plane` present at 0.6.2/0.6.3?). If reachable, KC1 is back to 3 CVEs with margin.
4. Then the -4536 and -9202 regression assertions (pass/fail only), checked against the predicted flip points.
