# Pilot 08: MCP half scoping (idea 01 vs. official conformance auth scenarios)

**Date:** 2026-10-24. **Type:** read-only desk study (SCOPE.md, "MCP half (idea 01) — scoped separately"). No MCP harness was built, no SDK was run and no MCP server was contacted. The conformance repo was read through `gh api` (contents and commits endpoints), not cloned.
**Inputs:** [idea 01](../../ideas/01-mcpauthfuzz/idea.md), [01 kill test](../../ideas/01-mcpauthfuzz/kill-test.md), [08 kill test](../../ideas/08-dsp-authfuzz/kill-test.md) (kill condition 3 and "Why 01 alone no longer carries Paper A").
**Pinned source:** `modelcontextprotocol/conformance` `main` at **`c37eec888e1c6ff140af79987a40008548b7cc5f`** (commit date 2026-10-01, "bump version to 0.2.0-alpha.12"). The last commit touching `src/scenarios/client/auth/` is `0e9535048` (2026-10-01). In the tables below, `C/` stands for `https://github.com/modelcontextprotocol/conformance/blob/c37eec888e1c6ff140af79987a40008548b7cc5f/`.

## 1. Idea 01's scenario set

`idea.md` does not state a five-item list. It names the surface through its candidate deltas: the CVE-2026-104850 class (credentials sent to a server-chosen authorization server), delta 3 "CIMD attack surface: the auth server fetches a client-controlled URL (SSRF, metadata spoofing, cache poisoning)", and delta 4 "Spec-version downgrade: DCR↔CIMD and old↔new spec negotiation". The five-family list is fixed in the "Narrowed" frozen claim of `01/kill-test.md` and repeated in the 08 kill test. It matches:

| ID | Family (01 kill test wording) | Side of the flow under test |
|---|---|---|
| S1 | Issuer / authorization-server mix-up | MCP client |
| S2 | Metadata spoofing (PRM and AS metadata served by a hostile party) | MCP client |
| S3 | CIMD fetch abuse (SSRF, spoofed client metadata document, cache poisoning) | **authorization server** that fetches the CIMD URL |
| S4 | Resource-indicator / audience confusion | MCP client (and, for audience, the resource server) |
| S5 | DCR↔CIMD downgrade, old↔new spec-version negotiation | MCP client and AS |

One wording note: `idea.md` places "metadata spoofing" under CIMD (a spoofed *client* metadata document), while the kill test lists it as its own family. This study reads S2 as client-side spoofing of PRM/AS metadata, the kill-test reading, and keeps CIMD-document spoofing in S3.

## 2. Conformance auth scenarios at the pinned SHA

`C/src/scenarios/client/auth/index.ts` groups client auth scenarios into four lists. Only the first is scored for SDK tiers. The draft list is commented "informational - not scored for tier assessment".

| List (index.ts) | Scenarios |
|---|---|
| `authScenariosList` (scored, tier 1) | `auth/metadata-default`, `-var1`, `-var2`, `-var3`; `auth/basic-cimd`; `auth/scope-from-www-authenticate`, `scope-from-scopes-supported`, `scope-omitted-when-undefined`, `scope-step-up`, `scope-retry-limit`; `auth/token-endpoint-auth-basic`, `-post`, `-none`; `auth/pre-registration` |
| `backcompatScenariosList` (optional) | `auth/2025-03-26-oauth-metadata-backcompat`, `auth/2025-03-26-oauth-endpoint-fallback` |
| `extensionScenariosList` (optional) | `auth/client-credentials-jwt`, `-basic`; `auth/enterprise-managed-authorization`; `auth/dpop`, `auth/dpop-nonce`; `auth/wif-jwt-bearer` |
| `draftScenariosList` (informational) | `auth/resource-mismatch`; `auth/offline-access-scope`, `offline-access-not-supported`; `auth/authorization-server-migration`; `auth/iss-supported`, `iss-not-advertised`, `iss-supported-missing`, `iss-wrong-issuer`, `iss-unexpected`, `iss-normalized`; `auth/metadata-issuer-mismatch` |

**Against the 08 kill test's list of seven drafts:** all seven are still present and still draft. Four more drafts exist, but none is adversarial. `iss-supported` and `iss-not-advertised` are positive controls. The two `offline-access-*` scenarios are refresh-token scope checks. No new adversarial draft scenario was added after 2026-05-22 (`f12baed38`, SEP-2468 traceability).

**Changes since the 08 kill test (2026-10-21 reading):**
- `31c5e7aa5` (2026-09-06, #483) ties each negative verdict to an observed prerequisite. For example, `iss-wrong-issuer` is now UNTESTABLE, not PASS, when the client never fetched AS metadata (`C/src/scenarios/client/auth/issuer-parameter.ts`, `issRejectionCheck`, l.17–101 (doc comment and function, function at l.39)).
- `98535fb92` (2026-09-06, #488) adds the scored check `resource-parameter-matches-prm` to every honest flow that calls `addResourceParameterChecks` (`C/src/scenarios/client/auth/helpers/resourceParameterChecks.ts`, l.116–158).

**Authorization-server suite:** `C/src/scenarios/authorization-server/` has three scenarios: `authorization-server-metadata-endpoint`, `authorization-code-grant` and `dpop`. For CIMD, the only check is that AS metadata advertises `client_id_metadata_document_supported` (`C/src/scenarios/authorization-server/authorization-server-metadata.ts`, l.96–108, WARNING if absent). Nothing tests how an AS fetches or validates a CIMD document.

**Open, not merged (state on 2026-10-24):** [PR #393](https://github.com/modelcontextprotocol/conformance/pull/393) `auth/metadata-query-params` (PRM discovery URL keeps query params); [PR #203](https://github.com/modelcontextprotocol/conformance/pull/203) (issuer-override option, issuer-mismatch scenario); [issue #437](https://github.com/modelcontextprotocol/conformance/issues/437) (no CIMD-only scenario without a DCR endpoint); [PR #527](https://github.com/modelcontextprotocol/conformance/pull/527) (DPoP Bearer-downgrade probe, stacked on [#395](https://github.com/modelcontextprotocol/conformance/pull/395)).

## 3. Coverage matrix

Legend: **C** covered, **P** partial, **–** not covered, blank = not relevant to the row. Only scenarios relevant to at least one row are shown.

| Conformance scenario (file at pinned SHA) | S1 mix-up | S2 metadata spoof | S3 CIMD fetch | S4 resource/audience | S5 downgrade |
|---|---|---|---|---|---|
| `auth/iss-wrong-issuer`, `iss-unexpected`, `iss-supported-missing`, `iss-normalized` (`C/src/scenarios/client/auth/issuer-parameter.ts` classes at l.251, 341, 432, 528) | **C**: RFC 9207 `iss` in the authorization response is compared against the recorded issuer, and the client must not send the code to the token endpoint | | | | |
| `auth/authorization-server-migration` (`C/src/scenarios/client/auth/authorization-server-migration.ts` l.19–24) | **C**: PRM switches AS₁→AS₂; AS₂ must not see AS₁'s `client_id`/secret (SEP-2352 credential–issuer binding) | | | | |
| `auth/metadata-issuer-mismatch` (`C/src/scenarios/client/auth/issuer-parameter.ts` l.620–745) | P: catches a hostile AS whose metadata names a different issuer | **P**: covers AS metadata `issuer` ≠ well-known URL on the PRM-advertised path only | | | |
| `auth/resource-mismatch` (`C/src/scenarios/client/auth/resource-mismatch.ts` l.30–149) | | **P**: covers a PRM `resource` naming another origin | | **C** (resource): RFC 9728 §3.3 / RFC 8707 check; client must not start authorization | |
| scored `resource-parameter-*` checks in honest flows (`C/src/scenarios/client/auth/helpers/resourceParameterChecks.ts` l.41–158) | | | | **P**: `resource` sent, consistent, equal to PRM value; honest server only | |
| `auth/basic-cimd` (`C/src/scenarios/client/auth/basic-cimd.ts` l.24–102) | | | **–**: client side only; checks the client *uses* a CIMD URL | | **P**: WARNING (not FAILURE) if the client ignores advertised CIMD and uses DCR; honest AS |
| `auth/2025-03-26-*` backcompat (`C/src/scenarios/client/auth/march-spec-backcompat.ts`) | | | | | **–**: tests that the fallback *works*, not that a hostile server cannot force it |
| AS suite `authorization-server-metadata-endpoint` (`C/src/scenarios/authorization-server/authorization-server-metadata.ts` l.96–108) | | | **–**: checks only that CIMD support is advertised | | |

### Row verdicts

| Row | Verdict | What the conformance suite leaves open (one line) |
|---|---|---|
| S1 issuer / AS mix-up | **covered** (1.0) | Single server, single AS pair per run. Two MCP servers sharing one AS credential store inside one host is not exercised. |
| S2 metadata spoofing | **partial** (0.5) | Issuer and resource are checked only on the main PRM discovery path. Untested: issuer validation on fallback/legacy discovery paths, the target of server-supplied metadata URLs (SSRF), and cross-origin redirects during metadata or token requests. |
| S3 CIMD fetch abuse | **not covered** (0) | No AS-side scenario fetches a hostile CIMD URL (SSRF, spoofed document, caching). The client-side CIMD scenario is honest-path only. Issue #437 is still open. |
| S4 resource / audience confusion | **partial** (0.5) | PRM-resource mismatch is covered (draft) and the parameter itself is scored. Not covered: a host reusing a token minted for server A at server B, i.e. audience isolation across servers. Server-side audience validation is outside the client suite. |
| S5 DCR↔CIMD / spec downgrade | **not covered** (0) | Only an honest-path SHOULD (WARNING) for preferring CIMD. No scenario where a hostile server or AS strips CIMD, forces DCR, or negotiates an older protocol version to avoid `iss`/resource checks. |

**Count: 2.0 of 5 (1 + 0.5 + 0 + 0.5 + 0).** The 08 kill test estimated "about 2.5 of 5". This study corrects it down by 0.5, because S4's audience half has no scenario. If S4 is narrowed to "resource indicator" only, the count is 2.5. Either way the result sits on idea 01's own kill condition 3 threshold (≥50 % → REWORK): 40 % under the strict reading, 50 % under the narrow one. The REWORK verdict in `01/kill-test.md` therefore rests on a borderline count, not a clear one.

**Another factor: the drafts are already wired into the SDKs.** A GitHub code search on 2026-10-24 for `"resource-mismatch" org:modelcontextprotocol` returned conformance-client code in the Go, Rust, Ruby, Swift, TypeScript, C#, Java, Kotlin and Python SDK repos ([search](https://github.com/search?q=%22resource-mismatch%22+org%3Amodelcontextprotocol&type=code)). The PHP SDK's baseline lists all client `auth/*` scenarios, drafts included, as expected failures ([php-sdk baseline](https://github.com/modelcontextprotocol/php-sdk/blob/57b45eb97b1d/tests/Conformance/conformance-baseline-2026-07-28.yml)). The Go and Java baselines list no draft auth scenario as an expected failure ([go-sdk](https://github.com/modelcontextprotocol/go-sdk/blob/2e00768cde3f/conformance/baseline.yml), [java-sdk](https://github.com/modelcontextprotocol/java-sdk/blob/54e8b6127747/conformance-tests/conformance-baseline.yml)). Whether their CI actually runs the draft suite was not checked: **UNVERIFIED**. If it does, S1/S2/S4-resource failures in Go and Java would already be visible, and the "beyond the drafts" space in KC3 shrinks to the uncovered cells above.

## 4. 2026 client OAuth advisories mapped to rows

Dates are the repository-advisory publication dates. The GitHub global-database dates differ and are given in brackets.

| Advisory | Package, affected → fixed | Summary | Row(s) | Caught by a draft today? |
|---|---|---|---|---|
| [GHSA-6qxp-vccf-f47h](https://github.com/advisories/GHSA-6qxp-vccf-f47h) / CVE-2026-104850, TS, 2026-09-30 [global 2026-10-06] | `@modelcontextprotocol/sdk` ≥1.12.0 <1.31.0; `@modelcontextprotocol/client` ≥2.0.0 <2.2.0 | Hostile MCP server names its own AS; the client sends stored `refresh_token`/`client_secret`/assertion there. Credentials were not bound to their AS. | S1 | Yes in principle: `authorization-server-migration` tests the same binding (SEP-2352). Not run against the vulnerable version here. |
| [GHSA-qx49-fqc8-xw99](https://github.com/modelcontextprotocol/python-sdk/security/advisories/GHSA-qx49-fqc8-xw99) / CVE-2026-115563, Python, 2026-09-28 [returned 404 from the global advisory API on 2026-10-24] | `mcp` ≥1.9.1 <1.30.0; ≥2.0.0a1 <2.2.0 | Same class, plus AS-metadata `issuer` "not validated on every discovery path": a server with no PRM can serve metadata that presents the real AS as issuer. | S1, S2 | S1 part yes (migration); the S2 fallback-path part is **not** (metadata-issuer-mismatch uses the PRM path only). "Reported by Cycode" (08 kill test) is **UNVERIFIED**: the advisory credits list GitHub handles only. |
| [GHSA-6prh-2h8m-c8cw](https://github.com/advisories/GHSA-6prh-2h8m-c8cw) / CVE-2026-111769, TS, 2026-10-02 [global 2026-10-20] | `@modelcontextprotocol/sdk` <1.32.0; `@modelcontextprotocol/client` ≥2.0.0 <2.3.0 | Transports and OAuth requests followed cross-origin redirects; a 307/308 re-sent token-request bodies (`refresh_token`, `client_secret`) and custom headers. | S2 (hostile metadata/AS transport behaviour) | **No.** No conformance scenario issues a cross-origin redirect. |
| [GHSA-33f5-2c5q-wgwj](https://github.com/advisories/GHSA-33f5-2c5q-wgwj) / CVE-2026-63127, Rust, 2026-06-29 [global 2026-09-16] | `rmcp` <2.0.0 | PRM `resource` field not parsed or validated (RFC 9728 §3.3/§7.3); a hostile server can relay the OAuth flow to a real AS and take the token. | S4 (and S2) | Yes: exactly `auth/resource-mismatch`. |

Same-class advisories found while reading (not cited by the kill test; listed so the S2 row is complete): Rust [GHSA-c9xm-49cp-xcr9](https://github.com/modelcontextprotocol/rust-sdk/security/advisories/GHSA-c9xm-49cp-xcr9) (client fetches a server-controlled `resource_metadata` URL, SSRF; `rmcp` ≤1.8.0 → 2.0.0); Rust [GHSA-5p52-q7pq-9fq2](https://github.com/modelcontextprotocol/rust-sdk/security/advisories/GHSA-5p52-q7pq-9fq2) (incomplete fix of the former, host-string denylist; `rmcp` ≥2.0.0 ≤3.6.0 → 3.7.0, published 2026-10-22); Ruby [GHSA-4m5j-jjfc-97gx](https://github.com/modelcontextprotocol/ruby-sdk/security/advisories/GHSA-4m5j-jjfc-97gx) (`resource_metadata` SSRF: an HTTPS-only check that does not block private or cloud-metadata addresses; `mcp` ≤1.1.0 → 1.2.0); Rust [GHSA-9g45-5xwm-f3wc](https://github.com/modelcontextprotocol/rust-sdk/security/advisories/GHSA-9g45-5xwm-f3wc) and Python [GHSA-5h93-6whr-6q8j](https://github.com/modelcontextprotocol/python-sdk/security/advisories/GHSA-5h93-6whr-6q8j) (cross-origin redirect header/body leaks, the 6prh class). None of these is caught by a conformance scenario. **What this shows:** the drafts catch the S1 and S4-resource advisories. The uncovered S2 sub-cases (fallback discovery path, metadata-fetch SSRF, cross-origin redirects) account for seven advisories across four SDKs (TS, Python, Rust, Ruby) in 2026, all found and fixed by others.

## 5. Kill condition 3 outlook (estimate only, nothing run)

KC3 (08 kill test): "10 official SDKs + ≥3 hosts produce <2 failures beyond what the conformance drafts already catch → drop MCP to related work".

### Official SDKs (all ten repos under `github.com/modelcontextprotocol`, none archived; latest GitHub release on 2026-10-24)

| SDK | Latest release | Client-side OAuth advisory in 2026 (row) |
|---|---|---|
| [typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk/releases/latest) | v2.4.0 (2026-10-23) | yes: S1, S2-redirect |
| [python-sdk](https://github.com/modelcontextprotocol/python-sdk/releases/latest) | v2.3.0 (2026-10-02) | yes: S1/S2, S2-redirect |
| [rust-sdk](https://github.com/modelcontextprotocol/rust-sdk/releases/latest) (`rmcp`) | rmcp-v3.7.0 (2026-10-22) | yes: S4, S2-SSRF ×2, S2-redirect |
| [go-sdk](https://github.com/modelcontextprotocol/go-sdk/releases/latest) | v1.8.0 (2026-09-14) | none (4 published advisories, all server-side) |
| [java-sdk](https://github.com/modelcontextprotocol/java-sdk/releases/latest) | v2.1.0 (2026-10-16) | none (7 published; server-side or transport DoS, none OAuth) |
| [csharp-sdk](https://github.com/modelcontextprotocol/csharp-sdk/releases/latest) | v2.3.0 (2026-10-20) | none (no published advisories) |
| [kotlin-sdk](https://github.com/modelcontextprotocol/kotlin-sdk/releases/latest) | 0.15.0 (2026-07-28) | none (3 published; transport DoS, none OAuth) |
| [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk/releases/latest) | 0.12.1 (2026-05-07) | none (no published advisories) |
| [ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk/releases/latest) | v1.8.1 (2026-10-21) | yes: S2-SSRF ([GHSA-4m5j-jjfc-97gx](https://github.com/modelcontextprotocol/ruby-sdk/security/advisories/GHSA-4m5j-jjfc-97gx), `mcp` ≤1.1.0 → 1.2.0) |
| [php-sdk](https://github.com/modelcontextprotocol/php-sdk/releases/latest) | v0.9.0 (2026-10-18) | none OAuth (1 published, client SSE DoS); its baseline fails every client auth scenario, so client OAuth looks unimplemented (inferred from the baseline file, not from code) |

All ten advisory lists were read on 2026-10-24 through the repository security-advisories API (`repos/modelcontextprotocol/<sdk>/security-advisories`), which returns published advisories only. An SDK with no advisory may still have an undisclosed or unreported bug.

### Candidate hosts (open source, can be pinned and run locally)

| Host | Latest release (2026-10-24) | OAuth implementation | Independent of the SDKs? |
|---|---|---|---|
| [VS Code](https://github.com/microsoft/vscode/releases/tag/1.143.1) | 1.143.1 (2026-10-22) | own code: [`src/vs/base/common/oauth.ts`](https://github.com/microsoft/vscode/blob/e646868227c3e3a9e3f24277c8c7220be42c0be7/src/vs/base/common/oauth.ts), `mainThreadMcp.ts` | yes |
| [Zed](https://github.com/zed-industries/zed/releases/tag/v1.25.3) | v1.25.3 (2026-10-23) | own code: [`crates/context_server/src/oauth.rs`](https://github.com/zed-industries/zed/blob/8dd255c3eafb5231056fe4e6f601cedd011f1c93/crates/context_server/src/oauth.rs) | yes |
| [Goose](https://github.com/block/goose/releases/latest) | v1.56.0 (2026-10-23) | depends on `rmcp` ([Cargo.toml](https://github.com/block/goose/blob/main/Cargo.toml)) | no (Rust SDK); host-level multi-server handling still its own |
| [mcp-remote](https://github.com/geelen/mcp-remote/releases/latest) | v0.15.2 (2026-10-20) | depends on `@modelcontextprotocol/client` ^2.0.0 ([package.json](https://github.com/geelen/mcp-remote/blob/main/package.json)) | no (TS SDK) |
| [LibreChat](https://github.com/danny-avila/LibreChat/tags) | tag v0.8.8 (no GitHub "latest release") | depends on `@modelcontextprotocol/sdk` ^1.32.1 (`packages/api/package.json`) | no (TS SDK) |

Closed-source hosts (Claude Desktop, Cursor, others) are left out because they cannot be pinned and rebuilt in a local testbed. Whether VS Code's and Zed's own OAuth code reaches every S1–S5 path was not checked: **UNVERIFIED**. Only **two** of the candidate hosts are confirmed independent OAuth implementations. KC3 asks for ≥3 hosts, so the third would test the host layer (multi-server credential isolation) over an SDK's OAuth core, not a third OAuth implementation.

### Where failures beyond the drafts could plausibly come from (ESTIMATE)

| Uncovered cell | Plausibility of ≥1 failure across the set | Basis |
|---|---|---|
| S2: cross-origin redirect during metadata/token requests | moderate–high | Same class fixed in TS, Python and Rust in 2026 (above). Seven SDKs (Go, Java, C#, Kotlin, Swift, Ruby, PHP) and two independent hosts have no published advisory in this class. |
| S2: SSRF via server-supplied metadata URLs | moderate | Two Rust advisories (the second an incomplete fix of the first) and one Ruby advisory in 2026. Other SDKs unknown. |
| S2: issuer validation on fallback/legacy discovery paths | moderate | Python advisory names this explicitly. Not exercised by `metadata-issuer-mismatch`. |
| S4-audience / S1 multi-server: token or client credentials shared across servers in one host | unknown | A host-level property, so only hosts can show it. No public advisory found. |
| S5: hostile downgrade (strip CIMD, force DCR, force an older protocol version) | low–moderate | Backcompat code paths exist (`march-spec-backcompat.ts`). Revision 2026-07-28 deprecates DCR (per `01/kill-test.md` re-test; not re-opened here). No public advisory found. |
| S3: AS-side CIMD fetch | out of KC3's client scope | Targets authorization servers, not SDK clients. Counts toward KC3 only if SDK-provided AS components implement CIMD fetching (not checked: **UNVERIFIED**). |

**Estimate:** reaching ≥2 failures beyond the drafts across 10 SDKs and ≥3 hosts looks **more likely than not**. The redirect and SSRF classes alone hit four of the ten SDKs in 2026 (TS, Python, Rust, Ruby). Six (Go, Java, C#, Kotlin, Swift, PHP) have no published advisory in either class. This rests on a base-rate argument, not on any test run here. It has two weaknesses. First, these classes are now public, so maintainers may already have closed them, as the TS/Python/Rust fixes show. Second, KC3 counts *new* failures only, so already-published advisories do not count. **UNVERIFIED until a harness is run, which is not approved.**

## 6. Recommendation (for the user's decision; not decided here)

**Recommendation: REWORK the MCP half, not GO as written and not yet DROP.**

Reasons:
1. The conformance drafts already cover the headline families: S1 fully and S4's resource half. Rediscovering CVE-2026-104850 or GHSA-33f5 would only show what `authorization-server-migration` and `resource-mismatch` already check, so the "harness rediscovers the known MCP CVE" story adds little.
2. Coverage is 2.0 of 5 by this study's count, below idea 01's 50 % trigger under the strict reading. The open space is real but sits in specific sub-cases: S2's fallback paths, redirects and SSRF; S4/S1 multi-server isolation in hosts; S5 downgrade; and S3, which is an AS-side target.
3. Those sub-cases are where 2026 advisories kept appearing (seven beyond-draft advisories in four SDKs), which supports the KC3 estimate. They have also been found and fixed by others quickly, which is the race risk named in the 08 kill test.
4. A reworked MCP half would test only the uncovered cells and offer each as an upstream conformance scenario (redirect, SSRF, fallback-issuer, downgrade, multi-server). That matches Paper A's frozen consequence: "regression scenarios contributed upstream".

**DROP case (for balance):** DSP alone already carries the novelty claim (08 kill test: Gate B is WEAK for MCP alone). The MCP half doubles the stacks for a residual that is narrow and contested. Dropping it keeps Paper A finishable in the timebox.

**Decision for Aakash:**
- (a) **Rework**: approve a bounded MCP harness build limited to the uncovered cells in §3 (local mock server/AS only, pinned SDK versions, no live servers), then run KC3 as frozen; or
- (b) **Drop**: move MCP to related work now, so Paper A is DSP-only and KC3 is closed without a run; or
- (c) **Defer**: leave KC3 open until DSP kill condition 2 has a result, then choose (a) or (b).

Building anything under (a) needs explicit approval (SCOPE.md: "The MCP harness is not built unless the user approves").
