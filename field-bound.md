# Step 1 — bound the field (2026-10-21)

Goal: before building, check whether any existing tool/spec already ships
**authorization-invariant tests for DSP** (kill condition 4). All three sources read
at primary source today.

| Source | URL | DSP authz-invariant tests? | Notes |
|---|---|---|---|
| **DSP TCK v1.0.2** (04 Sep 2026, latest) | github.com/eclipse-dataspacetck/dsp-tck/releases | **No** | Modules: catalog, contract-negotiation (consumer/provider), transfer-process, metadata. Authz-adjacent only: "Configurable HTTP Authorization header" (#107, a config option) and `SECURITY.md` (#71, policy doc). No authorization module, no multi-party/counterparty test, no access-control negative test. Confirms frozen signal #3. |
| **AgentRFC** 2603.23801 (Zheng & Zhang, 25 Mar 2026) | arxiv.org/abs/2603.23801 | **No** | 11 TLA+ security invariants + AgentConform checker (replays counterexamples against live SDKs). "Some findings are under coordinated disclosure; full evaluation details will be released in the complete version." No public repo found. Covers **MCP/A2A/ANP/ACP only** — not DSP/EDC. |
| **mcp-statecheck** (`lxingy3/mcp-statecheck`, v0.1.0) | github.com/lxingy3/mcp-statecheck | **No** | Python, stateful differential testing of MCP. Invariants: lifecycle/init, request-identity, cancellation, transport, cleanup, tasks ext, subscriptions, determinism. **No** authz/OAuth/token-validity/access-control invariants. Only authz-adjacent items: an Authorization-header passthrough and a secret-redaction leak check. MCP only; not DSP. |

## Verdict

**Kill condition 4 does NOT fire.** No existing tool or TCK release ships
authorization-invariant tests for DSP before the pilot. Gate B (not-established)
stands; no Gate B re-run needed at this point.

## Ledger change

`ideas/08-dsp-authfuzz/kill-test.md`: mcp-statecheck row updated from
"not opened / unknown" to "✅ opened 2026-10-21 / none — MCP state-machine only,
no authz invariants, not DSP". Frozen claim, safe sentence and kill conditions
unchanged.

## Watch items (Gate G, before submission)

- eclipse-dataspacetck/dsp-tck releases after v1.0.2 — watch for any authz module.
- AgentRFC full/complete version — re-check whether it extends to DSP and whether a
  repo is released (would re-trigger kill condition 4 / Gate B).

## Caveats (added on review, 2026-10-21)

- The TCK releases page shows dates without years. "04 Sep 2026" for v1.0.2 is taken from the earlier
  repo-tree read recorded in idea.md signal 3, not from the releases page itself.
- The v1.0.2 release notes do not list modules. The module list comes from the RC notes and the earlier
  repo-tree read.
- `lxingy3/mcp-statecheck` was found by GitHub name search. That it is the same tool cited in 2610.00182
  is **presumed, not confirmed** (the citing paper's link was not re-opened).
