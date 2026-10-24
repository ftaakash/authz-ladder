# KC2 invariant catalogue — DESIGN FREEZE

**Frozen:** 2026-10-25. **Status:** design only — no test has run against any current target.

This file defines the authorization invariants KC2 checks and the oracle rules for each. It is
derived **only** from the public DSP/DCP specifications and the three **already-patched, publicly
disclosed** Eclipse EDC advisories (CVE-2024-4536, -9202, -8642). It contains **no results** and
encodes **no undisclosed finding** — so it is tracked and pushed (per the coordinator's step 1).

> **Confidentiality (SCOPE / Review 11 Q3).** This catalogue is the *specification* of what should
> hold. Anything produced by *running* it against a current release — test scripts specialised to a
> discovered violation, observations, verdict rows, logs, notes — stays under `private/kc2/`
> (gitignored). Tracked files may state only the **count** of candidate findings, never which
> invariant, version, or mechanism. Disclosure is the user's call, Eclipse security process only.

## Freeze rules

- Each invariant below is frozen as written. A change (new invariant, altered assertion, altered
  oracle) requires a **dated amendment** at the bottom of this file with a one-line reason, and is
  **reported separately** from the frozen set (Review 11 Q1).
- An invariant's result against a current release **counts** only if the invariant was first
  **validated as a sound test**: it must return PASS on the stated *sanity configuration* (where the
  invariant holds by construction) and FAIL on a configuration where it is known-violated (the
  affected KC1 version, where one exists). A test that cannot be made to both PASS and FAIL on known
  configurations is **INVALID** and its current-release result is discarded (not counted as PASS).

## Oracle vocabulary (same discipline as KC1)

- **Observation** (what was seen: HTTP code, body predicate, state) is recorded separately from the
  **verdict** (PASS / FAIL / INVALID). No verdict without its observation.
- **Positive control**: every cell must show the *legitimate* path still works (so a FAIL means
  "the illegitimate path also worked", not "nothing worked"). A cell whose positive control fails is
  **INVALID**, never PASS.
- **Precondition check**: the setup the assertion needs (e.g. a policy-hidden dataset actually
  exists, a canary secret is actually in the vault) is verified *before* the assertion; if it is not
  met the cell is **INVALID**.
- **PASS** = the invariant held (illegitimate path refused, legitimate path works).
  **FAIL** = the invariant was violated (illegitimate path succeeded) *and* the positive control and
  preconditions held. **INVALID** = preconditions or positive control not met → discard, never a
  vacuous PASS.
- Every row carries the image/jar digest and a clean commit.

---

## INV-1 — Catalogue visibility (per-dataset access == catalogue-level policy)

- **Source.** CVE-2024-9202 (`DatasetResolverImpl`, single-dataset request skips catalogue policy
  filter; CWE-862); DSP Catalog Protocol (`CatalogRequestMessage` vs `GET …/catalog/datasets/{id}`).
- **Invariant.** A counterparty may obtain a single dataset by id **iff** that dataset is visible to
  that counterparty in the policy-filtered full catalogue. The per-dataset endpoint must apply the
  same access-policy decision as the catalogue endpoint.
- **Preconditions.** A dataset D exists whose access policy **admits** party A and **denies** party B;
  B's identity is authenticated (DCP). Precondition check: in the full catalogue, A sees D and B does
  **not**.
- **Assertion (B, the denied party).** `GET …/catalog/datasets/{D}` as B must not return D.
- **Positive control (A, the admitted party).** A's catalogue shows D **and** A's single-dataset
  request returns D. Also B's catalogue request succeeds (B is authenticated) but omits D.
- **Sanity configuration (PASS by construction).** Same build, but D's policy **admits B**: then both
  the catalogue and the single-dataset endpoint return D to B — consistent → PASS. (Validates the
  assertion is not hard-wired to FAIL.)
- **Known-violated configuration (must FAIL).** KC1 affected build EDC 0.6.2/0.6.3/0.9.0 (single-dataset
  bypass present); fixed at 0.9.1.
- **PASS** single-dataset request by B is refused/empty (e.g. 404 or no `dcat:Dataset`).
  **FAIL** B receives D. **INVALID** B not actually hidden in the catalogue, or A's positive control fails.

## INV-2 — Vault scoping (a counterparty cannot name which secret the provider dereferences)

- **Source.** CVE-2024-4536 (OAuth2 data-plane: a consumer-supplied key name resolves a secret in the
  **provider's** vault, sent to a consumer-controlled token URL).
- **Invariant.** No counterparty-supplied value (e.g. `oauth2:clientSecretKey` on a transfer
  destination) may cause the provider to resolve an arbitrary secret from its own vault and transmit
  it to a counterparty-controlled endpoint.
- **Preconditions.** Provider vault holds a per-run **canary** secret at a known alias (value never
  logged/stored — redacted). A DCP-authenticated consumer negotiates an agreement and starts a PUSH
  transfer whose `dataDestination` names that alias as the OAuth2 client-secret key and a
  consumer-controlled `tokenUrl`.
- **Assertion.** The provider must **not** POST the canary value to the consumer `tokenUrl`.
- **Positive control (D7b).** The sink write itself still occurs (`sink_write=yes`) — the data-plane
  path is exercised — it simply carries no vault-resolved secret.
- **Sanity configuration (PASS by construction).** Same build, transfer destination names **no**
  secret alias: the sink write happens and no secret is sent → PASS.
- **Known-violated configuration (must FAIL).** KC1 affected build EDC 0.6.2 (leaks); fixed 0.6.3+.
- **PASS** no canary value reaches the consumer endpoint (token POST absent or without the secret),
  sink write present. **FAIL** canary value received by the consumer endpoint. **INVALID** sink write
  never happens (positive control failed) or canary not actually seeded.

## INV-3 — Transfer/access token validity (exp / nbf / iat verified before use)

- **Source.** CVE-2024-8642 (`ConsumerPullTransferTokenValidationApiController` validated a token
  **without** the validation-rules arg → expiry/nbf/iat unchecked); DSP/DCP token handling.
- **Invariant.** A transfer/access token presented to obtain data must be rejected if it is expired,
  not-yet-valid (`nbf` in the future) or has an invalid `iat`.
- **Preconditions.** A data-plane / transfer path that consumes a bearer/access token is reachable,
  and a token-minting path exists that can produce an **expired** (and separately a future-`nbf`) token
  for the same key as a valid one.
- **Assertion.** A request carrying an expired (resp. future-`nbf`) token is refused (401/403).
- **Positive control.** The **same** request with a currently-valid token succeeds.
- **Sanity configuration (PASS by construction).** A build/config that enforces the validation rules:
  expired token refused, valid token accepted → PASS.
- **Known-violated configuration (must FAIL).** An EDC build with `transfer-data-plane` consumer-pull
  present and unchecked (≤ 0.8.x). **Reachability caveat:** this path was removed from mainline at
  0.9.0 and is absent from the current Tractus-X 0.13.0 / vanilla 0.18.1 runtimes (Dataplane Signaling
  replaced it). If the token-validity code path is **not reachable** on a current target, INV-3 is
  recorded **INVALID / not-applicable** on that target (never a vacuous PASS), exactly as -8642 did not
  count for KC1 (D6).

## INV-4 — Agreement-bound transfer (transfer requires a matching contract agreement)

- **Source.** DSP Transfer Process Protocol + Contract Negotiation: a `TransferRequestMessage` cites a
  `contractId`; the provider must bind the transfer to a valid agreement for **that asset** between
  **those parties**.
- **Invariant.** A transfer may proceed only for an asset covered by a valid, finalized agreement
  between the requesting counterparty and the provider. A transfer citing no agreement, an agreement
  for a **different asset**, or an agreement of a **different party**, must be refused.
- **Preconditions.** Two DCP-authenticated parties; a finalized agreement exists for (party A, asset X).
- **Assertion.** A transfer request by A for asset **Y** (no agreement), or by party **B** reusing A's
  agreement id, is refused.
- **Positive control.** A's transfer for asset X under its valid agreement succeeds (reaches a
  STARTED/COMPLETED transfer state).
- **Sanity configuration (PASS by construction).** Only the properly-negotiated (A, X) transfer is
  attempted → it succeeds and no unbound transfer is accepted → PASS.
- **PASS** unbound/mismatched transfer refused, bound transfer works. **FAIL** unbound or
  cross-party/cross-asset transfer proceeds. **INVALID** the bound positive-control transfer fails, or
  no agreement could be finalized.

## INV-5 — Credential issuer trust (presentation accepted only from a trusted issuer)

- **Source.** DCP (Decentralized Claims Protocol): a counterparty authenticates by presenting a VP
  whose credential (e.g. MembershipCredential) was issued by an issuer the verifier **trusts**
  (`edc.iam.trusted-issuer.*`), resolved via did:web.
- **Invariant.** A DSP request authenticated by a VP whose credential is issued by an **untrusted**
  issuer must be rejected; the catalogue/negotiation must not proceed for that party.
- **Preconditions.** Two issuers exist: a **trusted** one (seeded into the provider's trusted-issuer
  list) and an **untrusted** one (not seeded). A consumer holds a MembershipCredential from each.
- **Assertion (negative control for the handshake).** A consumer presenting the **untrusted**-issuer
  credential is refused at the DSP boundary (no 200 catalogue).
- **Positive control.** The **same** consumer presenting the **trusted**-issuer credential gets a 200
  catalogue.
- **Sanity configuration (PASS by construction).** Provider trusts issuer I; consumer presents I's
  credential → 200; consumer presents J's (untrusted) credential → refused → PASS.
- **PASS** untrusted-issuer presentation refused, trusted-issuer presentation works. **FAIL** untrusted
  issuer accepted. **INVALID** the trusted-issuer positive control fails (handshake itself broken).

---

## Mapping to KC1 and to the handshake

| Invariant | KC1 CVE oracle | Validated where |
|---|---|---|
| INV-1 catalogue visibility | CVE-2024-9202 (FAIL 0.6.2/0.6.3/0.9.0 → PASS 0.9.1) | KC1 ladder + current targets |
| INV-2 vault scoping | CVE-2024-4536 (FAIL 0.6.2 → PASS 0.6.3+) | KC1 ladder + current targets |
| INV-3 token validity | CVE-2024-8642 (path removed ≥0.9.0) | likely INVALID/NA on current targets (reachability) |
| INV-4 agreement-bound transfer | (spec-derived; no single CVE) | sanity config + current targets |
| INV-5 issuer trust | (DCP-derived; = handshake negative control) | sanity config (handshake step) + current targets |

INV-5's sanity check is the **negative control required for the phase-2 handshake** (a credential
from an untrusted issuer must be rejected): standing it up proves the handshake is a real trust
decision, not an accept-all.

## Out of this frozen set (would need an amendment to add)

Candidate further invariants noted but **not** frozen now (each needs a dated amendment + separate
report if added): contract-policy constraint evaluation on negotiation (not just catalogue), EDR/token
refresh scoping, data-plane public-API audience binding, DID/key rotation handling. Adding any of
these after results exist risks post-hoc invariants, so they are deliberately excluded from the frozen
baseline.

## Amendments

_(none yet — append dated entries here; each changes the frozen set and is reported separately.)_
