# CVE oracle — version pinning & regression ladder

**Purpose:** fix the exact affected/patched builds so the three EDC advisories can serve as a correctness oracle. Admission rule (from [SCOPE.md](SCOPE.md)): a test is valid only if it **FAILs on the affected build and PASSes on the patched build**. All versions/commits below are from OSV + NVD/Mend (sources at end); none invented. Severity scores vary by aggregator — treated as secondary.

## Per-CVE pinning

### CVE-2024-4536 — OAuth2 secret disclosure (vault scoping)
- **Package:** `org.eclipse.edc` (Connector) · **GHSA:** `GHSA-2x52-8f29-7cjr`
- **Introduced:** 0.2.1 · **Last affected:** 0.6.2 · **Fixed:** **0.6.3**
- **Fix commit:** `a4e6018d2c0457fba6f672fafa6c590513c45d1b` (release tag `v0.6.3`); introduced `5803513f0c4cc795c0d1d069f7039c8ca1bd8f7e`
- **Mechanism:** consumer-supplied key name resolves a secret against the **provider's** vault; secret is sent to a consumer-controlled token URL. Invariant = *vault scoping* (a counterparty cannot name which secret the provider dereferences).
- **⚠ Fix nature = feature removal, but the patched PASS is *not* vacuous (D7b).** 0.6.2 registers both the OAuth2 data-**sink** and data-**source** decorators; 0.6.3 removes the **sink** decorator (commit `a4e6018`), leaving the source. The DSP-driven test (`scripts/42_test_4536_dsp.sh`) puts the consumer-named `oauth2:clientSecretKey` + consumer `tokenUrl` on the transfer **destination** (PUSH sink). On 0.6.3 the connector **still performs the sink write** — this is the positive control — it simply no longer authenticates it with the vault-resolved secret, so no secret leaves the provider. Because the sink-write behaviour persists and only the disclosing auth is gone, the 0.6.3 PASS measures a real behavioural fix, not an absent feature. This is why -4536's removal-fix PASS **counts** toward KC1 whereas -8642's (D6) does not: -8642's whole module is gone at the patched version, so its PASS would be vacuous. (finder: sovity GmbH)

### CVE-2024-9202 — single-dataset request skips catalogue filtering (CWE-862)
- **Package:** `github.com/eclipse-edc/connector` · **GHSA:** *not located in search; tracked via NVD/OSV, CNA = Eclipse Foundation* (verify the GHSA page before citing it in the paper)
- **Introduced:** 0.1.3 · **Last affected:** **0.9.0** · **Fixed:** **0.9.1**
- **Fix commit:** `1bd6e683e6304f7e34e0d161cd750424dc2d4dae`; introduced `d518ff58cc009d75ce8b73aba2a65688a91cdde5` · **PRs:** #4490, #4491
- **Location:** `DatasetResolverImpl` (reported ~L76–79). Mechanism: catalogue request is filtered by policy, but a **single-dataset** request bypasses that filter.
- **Invariant** = *catalogue visibility* (per-dataset access decision == catalogue-level policy). **Exploit precondition:** attacker must know/guess a restricted dataset ID.
- This is the `-9202` "last affected = 0.9.0" that the kill-test's *next action* points at.

### CVE-2024-8642 — transfer token validity not checked
- **Package:** `org.eclipse.edc:transfer-data-plane` · **GHSA:** `GHSA-8259-2x72-2gvc`
- **Introduced:** 0.5.0 · **Fixed:** **0.9.0**
- **Fix commit:** `04899e91dcdb4a407db4eb7af3e7b6ff9a9e9ad6` (release tag `v0.9.0` = `2de2e94d06ead5d4fd3c1f8ab1980f5b8ee9dfb1`); introduced `b113a82e3cd5c4a929e8ea2ece2590980dc6d27f`
- **Location:** `ConsumerPullTransferTokenValidationApiController` calls `TokenValidationService.validate(token, publicKeyResolver)` **without** the validation-rules arg → expiry/nbf/iat never checked.
- **Invariant** = *token validity* (transfer tokens are verified before use).
- **⚠ Preconditions:** dataplane configured for **http proxy consumer pull** AND module `transfer-data-plane` present. Deprecated from 0.6.0 in favour of Dataplane Signaling; **removed at 0.9.0** → same vacuous-PASS caveat as -4536.

## The key desk finding: one pair won't work — use a ladder

The three fixes land at **three different releases**, and each "patched" build for one CVE is still "affected" by another. The only window where all three coexist is **[0.5.0, 0.6.2]** (bounded below by -8642's introduction, above by -4536's fix). So there is no single (vulnerable → patched) pair that exercises all three. The oracle must be a **4-build regression ladder**:

| Build | -4536 vault | -9202 catalogue | -8642 token |
|---|---|---|---|
| **v0.6.2** | FAIL (vuln) | FAIL (vuln) | FAIL (vuln) |
| **v0.6.3** | PASS (fixed) | FAIL (vuln) | FAIL (vuln) |
| **v0.9.0** | PASS | FAIL (vuln) | PASS (fixed) |
| **v0.9.1** | PASS | PASS (fixed) | PASS |

Each CVE test is **admitted only if it flips FAIL→PASS at exactly its fixing version** across this ladder:
- -4536 flips between **0.6.2 → 0.6.3** ✓
- -8642 flips between **0.6.3 → 0.9.0** ✓  *(note: 0.6.2 vs 0.6.3 would NOT distinguish -8642 — both are vulnerable — which is why a single pair fails)*
- -9202 flips between **0.9.0 → 0.9.1** ✓

A test whose results don't match this exact 12-cell pattern is **rejected** as not actually measuring the CVE. This is strictly stronger than a vuln/patched pair: it's a monotonic ladder with a predicted transition point per column.

**v0.6.2 is the triple-vulnerable anchor** — build the first harness drafts against it.

## How this ladder is actually run for KC1 (D5–D8) — supersedes the MVD/Route-A notes below

The pinning above still defines the oracle, but the **route** to the builds changed. See [DECISIONS.md](DECISIONS.md):

- **D5/D6 — SUT.** KC1 runs on **vanilla Eclipse EDC + `iam-mock`**, each rung **assembled from the released
  Maven Central artifacts** at its pinned version (not built from source, and not Tractus-X). The launcher recipe
  is `testbed/launcher/`; per-rung jar sha256 in `env/vanilla-jars.csv`. The Tractus-X "Route A reality check"
  section below and the "Open items before any download" (MVD mapping/reachability) are **superseded for KC1**;
  they remain only as the deferred-KC2 (option A) record.
- **D6 — -8642 does not count.** `transfer-data-plane` (the -8642 module) is published only through 0.8.1 and is
  **absent** from 0.9.0/0.9.1 where -8642 is "fixed", so its patched PASS is vacuous and does not admit the test.
  KC1 therefore rests on **-4536 and -9202, both must flip** (≥2-of-3, no margin).
- **D7 — -4536 is DSP-driven** with an `iam-mock` consumer connector, and its removal-fix PASS **counts** (the
  sink write persists as a positive control — see the -4536 note above). Admissible test: `scripts/42_test_4536_dsp.sh`.
- **D8 — dependencies checksum-verified.** Gradle dependency verification (sha1+sha256, 1416 artifacts)
  cross-checked against the publishers; see [ENV.md](ENV.md) §Dependency verification.

KC1 admission on the vanilla ladder (0.6.2 → 0.6.3 → 0.9.0 → 0.9.1): **-4536** flips FAIL→PASS at 0.6.2→0.6.3;
**-9202** flips FAIL→PASS at 0.9.0→0.9.1 (FAIL at 0.6.2/0.6.3/0.9.0). The 12-cell pattern above still governs admission.

## Open items before any download (need user OK for pulls) — ⚠ SUPERSEDED for KC1 by D5 (kept for KC2/option A)

1. **MVD ↔ EDC version mapping.** The MinimumViableDataspace tracks specific Connector releases; confirm which MVD tag pins EDC 0.6.2 / 0.6.3 / 0.9.0 / 0.9.1, or whether some builds need the raw Connector `samples` instead. *(not yet checked — UNVERIFIED)*
2. **Reachability in MVD.** -9202 (catalogue) and -8642 (transfer, needs http-proxy-consumer-pull + transfer-data-plane) are plausibly reachable in the MVD; **-4536** (OAuth2 data sink) may not be wired in the MVD and could require the Connector OAuth2 sample. *(UNVERIFIED)*
3. **GHSA for -9202** not yet located — find the official advisory page before citing it.

## Sources
- OSV: https://osv.dev/vulnerability/CVE-2024-4536 · https://osv.dev/vulnerability/CVE-2024-9202 · https://osv.dev/vulnerability/CVE-2024-8642
- GHSA-2x52-8f29-7cjr (−4536); GHSA-8259-2x72-2gvc (−8642)
- Fix commits/PRs: eclipse-edc/Connector commits above; PRs #4490 / #4491 (−9202)
- NVD CVE-2024-9202 (CWE-862; CVSS 3.1 5.3 Medium `AV:N/AC:H/PR:L/UI:N/S:U/C:H/I:N/A:N`), Mend (fix 0.9.1)

---

## Route A reality check (2026-10-21, after registry + source inspection) — ⚠ SUPERSEDED for KC1 by D5 (kept for KC2/option A)

The vanilla-EDC ladder above (0.6.2 → 0.6.3 → 0.9.0 → 0.9.1) **cannot be run from prebuilt images**:
Eclipse publishes no images for Connector releases. Prebuilt connectors exist only as Tractus-X EDC,
so the Route A ladder is the Tractus-X ladder pinned in [ENV.md](ENV.md). Per-rung prediction, from
each tag's `libs.versions.toml` and build files (all read at source):

| Rung | Tractus-X | EDC | -4536 vault | -9202 catalogue | -8642 token |
|---|---|---|---|---|---|
| R1 | 0.7.0 | 0.6.1 | FAIL (vuln) | FAIL (vuln) | n/a — module absent |
| R2 | 0.7.1 | 0.6.3 | PASS (fixed) | FAIL (vuln) | n/a |
| R3 | 0.7.5 | 0.7.2 | PASS | FAIL (vuln) | n/a |
| R4 | 0.7.6 | 0.7.2 + `dataset-bugfix` | PASS | PASS (vendor backport) | n/a |
| R5 | 0.8.0 | 0.10.1 | PASS | PASS (upstream fix) | n/a |

Admission rule unchanged: -4536 must flip exactly at R1→R2; -9202 exactly at R3→R4 and stay PASS at R5.

### Findings from the inspection
1. **CVE-2024-8642 is unreachable in Tractus-X ≥ 0.7.0.** Its code is in `org.eclipse.edc:transfer-data-plane`
   (consumer-pull via HTTP proxy). Tractus-X 0.7.0 and 0.7.7 control planes use `dpf.transfer.signaling`
   instead; no `transfer-data-plane` module in either build. A test would PASS vacuously on every rung, so
   -8642 is **not testable on Route A**. It needs a vanilla EDC 0.5.0–0.8.x build with `transfer-data-plane`
   (Route B, targeted) or Tractus-X 0.6.0 (EDC 0.5.1, older identity stack). **UNVERIFIED** which is cheaper.
2. **Tractus-X backported a -9202 mitigation at 0.7.6.** `edc-extensions/dataset-bugfix/DatasetFixExtension`
   registers a response filter on the DSP protocol API: a `GET …/catalog/datasets/{id}` response whose
   `dcat:Dataset` has an empty `odrl:hasPolicy` array is turned into 404. 0.7.5 and 0.7.6 bundle the same
   EDC (0.7.2) and `DatasetFixExtension` is present only in 0.7.6 (jar check, ENV.md). Both jars have 58258
   classes, so other classes also changed; the pair is near-controlled, not proven single-variable. Methodological consequence: a distribution's
   CVE status cannot be read from its bundled EDC version — it must be measured behaviourally.
3. **-4536 module present on every rung, including patched ones** (6 dpf-oauth2 classes in all five jars), so the
   patched PASS is not guaranteed to be vacuous: the test must measure behaviour, not absence.
   Earlier note: `libs.edc.dpf.oauth2` (data-plane HTTP OAuth2) is in the data plane at 0.7.0 and
   0.7.7. Whether the provider resolves a consumer-named secret through it at R1 is still to be shown by test.

### Consequence for kill condition 1
Route A can exercise **2 of 3** CVEs (-4536, -9202): exactly the ≥2 threshold, **no margin**. Adding -8642
requires one targeted vanilla-EDC build (user decision; not started).

### Open setup risk
Tractus-X 0.7.x control planes include DCP identity (`tx-iatp`, `tx-iatp-sts-dim`, `bdrs-client`). Two local
connectors need a local identity stack (DID:web documents, STS, BDRS, trusted issuer). No mock-IAM module was
found in `edc-runtime-memory`. The plan is for the local test driver to serve these locally. **UNVERIFIED**
until the first runtime boots.
