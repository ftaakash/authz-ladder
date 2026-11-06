# KC2 invariant catalogue — DESIGN FREEZE

**Frozen:** 2026-10-25. **Status:** design only — no test has run against any current target.

This file defines the authorization invariants KC2 checks and the oracle rules for each. It is
derived **only** from the public DSP/DCP specifications and the three **already-patched, publicly
disclosed** Eclipse EDC advisories (CVE-2024-4536, -9202, -8642). It contains **no results** and
encodes **no undisclosed finding** — so it is tracked and pushed (per the coordinator's step 1).

> **Confidentiality (SCOPE / Review 11 Q3).** This catalogue is the *specification* of what should
> hold. Anything produced by *running* it against a current release — test scripts specialised to a
> discovered violation, observations, verdict rows, logs, notes — stays under `private/kc2/`
> (gitignored). **Tracked files and commit messages carry NO phase-3 number at all** — not per invariant,
> not per target, not even a total (Review 15 U1, 2026-10-29: any count can locate an undisclosed finding).
> They may say only "phase 3 run complete, results private". Every tally stays in `private/kc2/`; no number
> is published without the user's explicit approval. Disclosure is the user's call, Eclipse security process only.

## Freeze rules

- Each invariant below is frozen as written. A change (new invariant, altered assertion, altered
  oracle) requires a **dated amendment** at the bottom of this file with a one-line reason, and is
  **reported separately** from the frozen set (Review 11 Q1).
- An invariant's result against a current release **counts** only if the invariant was first
  **validated as a sound test** — the **admission rule**: it must return **PASS on its sanity
  configuration** (where the invariant holds by construction) **and FAIL on its mutation
  configuration** (a deliberately broken setup where the invariant is violated by construction). A
  test that cannot be made to do both is **INVALID** and its current-release result is discarded
  (never a vacuous PASS).
- The **mutation configuration** is a labelled, test-only break of the sanity setup that encodes the
  spec rule's negation — it is **never** used for a current-release verdict and reveals no finding
  (it is the generic "what a violation looks like"). For INV-1/INV-2 the KC1 affected builds already
  serve as the mutation; the others define a fixture/config mutation below. (Amendment A1, 2026-10-26.)

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
- **Mutation configuration (must FAIL — admission).** The KC1 affected build, same hidden-dataset setup:
  B receives D → FAIL. (This is the spec rule negated by a real historical bug, not a finding.)
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
- **Mutation configuration (must FAIL — admission).** The KC1 affected build EDC 0.6.2, same canary +
  consumer-named alias: the canary value reaches the consumer token URL → FAIL.
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
- **Mutation configuration (must FAIL — admission; only where reachable).** A build/config invoking the
  validator **without** the validity rules (the -8642 path) accepts an expired token → FAIL. Where the
  path is unreachable on a target, INV-3 is INVALID/NA there and is not admitted.

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
- **Mutation configuration (must FAIL — admission).** A labelled test-only fixture/config on the sanity
  setup that **skips the agreement-binding check** (accepts a transfer whose `contractId` does not match
  the asset/parties): the unbound transfer then proceeds → FAIL. Fixture never used for a current-release
  verdict.
- **PASS** unbound/mismatched transfer refused, bound transfer works. **FAIL** unbound or
  cross-party/cross-asset transfer proceeds. **INVALID** the bound positive-control transfer fails, or
  no agreement could be finalized.
- **Admission/mechanics refined by amendment A3 (2026-11-06):** because the honest consumer will not emit a
  transfer for an agreement it does not hold, the assertion is delivered by a DSP client fixture on the
  attacker (its own token); the provider is pristine. The release **layers** the agreement-binding (a
  participant-scoped agreement lookup, then a consumer-identity check), so a single-check mutation cannot by
  itself realize the violation. INV-4 is admitted at a **weaker tier than A1** (positive control + assertion,
  not a mutation FAIL), Tractus-X only. See A3 (source-level mechanics; no run observation here).

## INV-5 — Credential issuer trust (presentation accepted only from a trusted issuer)

- **TCK-baseline tag (D15, 2026-10-29).** The DCP (identity-layer) TCK baseline was **deferred** (standalone
  reproduction blocked in the TCK's credential-seeding step; see `kc2/TCK-PLAN.md` §DCP TCK). INV-5's phase-3
  result on each current target therefore carries the tag **"identity stack not TCK-baselined"**. The DSP TCK
  baseline (both targets 65/65) is unaffected.
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
- **Mutation configuration (must FAIL — admission).** The provider configured to **also trust J**: the
  J-issued presentation is then accepted (200) → FAIL. Shows the test discriminates on the trusted-issuer
  list, not on something else.
- **PASS** untrusted-issuer presentation refused, trusted-issuer presentation works. **FAIL** untrusted
  issuer accepted. **INVALID** the trusted-issuer positive control fails (handshake itself broken).

## INV-6 — Contract-policy constraint evaluation at negotiation (not only catalogue)

- **Source.** DSP Contract Negotiation + ODRL policy: the **contract** (negotiation/agreement) policy
  constraints must be evaluated when a counterparty negotiates, not only the catalogue access policy.
  A party that is filtered out of the catalogue but reaches negotiation directly must still be refused
  an agreement its policy forbids.
- **Invariant.** A contract negotiation for an offer whose contract policy the counterparty does not
  satisfy must be refused (no finalized agreement), independently of catalogue visibility.
- **Preconditions.** An offer for asset X whose **contract policy** admits A and denies B; both
  DCP-authenticated. (B may or may not see X in the catalogue — the point is the negotiation decision.)
- **Assertion (B).** B's contract negotiation for X terminates without a finalized agreement.
- **Positive control (A).** A's negotiation for X finalizes an agreement.
- **Sanity configuration (PASS by construction).** Contract policy admits B → B's negotiation finalizes
  → PASS; with the deny policy, B is refused → PASS. (Both consistent with the policy.)
- **Mutation configuration (must FAIL — admission).** A labelled fixture that binds **no** constraint
  function in the negotiation scope (so the deny constraint is silently dropped — the same class as the
  KC1 F1 catalogue gap): B's negotiation then finalizes an agreement it should not → FAIL.
- **PASS** B refused, A finalizes. **FAIL** B finalizes a forbidden agreement. **INVALID** A's positive
  control fails, or the deny policy was not actually in force.
- **Oracle superseded by amendment A2 (2026-11-05):** the admission gate above made the sanity *deny-leg*
  the same measurement as the current-release verdict (non-falsifiable). A2 rebuilds the oracle on a
  **release-bound negotiation constraint** (admission independent of the verdict) and scopes INV-6 to
  **Tractus-X only**. See A2 for the sanity/mutation/verdict and the source citations.

## INV-7 — Data-plane public-API audience / EDR binding

- **Source.** DSP/Dataplane Signaling + EDR (Endpoint Data Reference): an access token / EDR issued for
  transfer process T and party A authorizes data access **only** for T and A.
- **Invariant.** A data-plane public-API token/EDR issued for (transfer T, party A) must not grant
  access for a different transfer T′ or a different party B.
- **Preconditions.** Two finalized transfers T (party A) and T′ (party A or B) with distinct EDRs/tokens
  on a reachable data-plane public API.
- **Assertion.** Presenting T's token/EDR against T′'s data endpoint (or as party B) is refused
  (401/403/empty).
- **Positive control.** T's token against T's own endpoint returns the data.
- **Sanity configuration (PASS by construction).** Each token used only against its own transfer →
  succeeds; cross-use → refused → PASS.
- **Mutation configuration (must FAIL — admission).** A labelled config that disables the audience/EDR
  binding check (accepts any well-formed token regardless of transfer/party): cross-use then succeeds
  → FAIL.
- **PASS** cross-use refused, own-use works. **FAIL** cross-use returns data. **INVALID** own-use fails,
  or the public-API path is not reachable on the target (then record INV-7 NA with the reason).

## INV-8 — EDR / token refresh scoping *(applicability to be measured)*

- **Source.** EDR token-refresh endpoint (Tractus-X `edc-dataplane-tokenrefresh`): a refresh token is
  bound to its EDR and party; refreshing must not widen scope or cross parties.
- **Invariant.** A refresh request must return a token no broader than the original EDR's scope, and
  only to the party the EDR was issued to.
- **Preconditions.** A reachable token-refresh endpoint and an EDR with a refresh token for party A.
- **Assertion.** A refresh presented by party B, or a refresh that attempts to widen scope, is refused.
- **Positive control.** A's in-scope refresh succeeds and returns a same-scope token.
- **Sanity configuration (PASS by construction).** In-scope refresh by A succeeds; cross-party refresh
  refused → PASS.
- **Mutation configuration (must FAIL — admission).** A labelled config that skips the refresh-scope/owner
  check: a cross-party refresh then succeeds → FAIL.
- **Applicability.** The `edc-runtime-memory` target may not expose the token-refresh path. If it is
  **not reachable** on a current target, INV-8 is recorded **NA** with the reason and is not admitted
  there (no vacuous PASS).

---

## Mapping to KC1 and to the handshake

| Invariant | KC1 CVE oracle | Validated where |
|---|---|---|
| INV-1 catalogue visibility | CVE-2024-9202 (FAIL 0.6.2/0.6.3/0.9.0 → PASS 0.9.1) | KC1 ladder + current targets |
| INV-2 vault scoping | CVE-2024-4536 (FAIL 0.6.2 → PASS 0.6.3+) | KC1 ladder + current targets |
| INV-3 token validity | CVE-2024-8642 (path removed ≥0.9.0) | likely INVALID/NA on current targets (reachability) |
| INV-4 agreement-bound transfer | (spec-derived; no single CVE) | sanity + mutation + current targets |
| INV-5 issuer trust | (DCP-derived; = handshake negative control) | sanity + mutation (handshake) + current targets |
| INV-6 contract-policy at negotiation | (spec-derived) | sanity + mutation + current targets |
| INV-7 data-plane audience/EDR binding | (spec-derived) | sanity + mutation + current targets (if reachable) |
| INV-8 EDR refresh scoping | (spec-derived) | sanity + mutation + current targets (if reachable) |

INV-5's sanity check is the **negative control required for the phase-2 handshake** (a credential
from an untrusted issuer must be rejected): standing it up proves the handshake is a real trust
decision, not an accept-all.

## Out of this frozen set (would need an amendment to add)

Candidate further invariants still **not** frozen (each needs a dated amendment + separate report if
added): DID/key-rotation handling, presentation replay / nonce binding, status-list (revocation)
honouring. Adding any of these after results exist risks post-hoc invariants, so they are deliberately
excluded from the frozen baseline. *(Amendment A1 promoted contract-policy-at-negotiation → INV-6,
data-plane audience/EDR binding → INV-7, and EDR refresh scoping → INV-8.)*

## Amendments

- **A1 — 2026-10-26 — pre-results: detection power + coverage.** No test had run against any current
  target when this was made, so it is not post-hoc. (1) **Detection power:** every invariant now carries
  a **mutation configuration** on which its test must return FAIL, and the admission rule requires FAIL
  on the mutation *and* PASS on the sanity config (else INVALID). (2) **Coverage:** promoted three
  deferred invariants into the frozen set — **INV-6** (contract-policy at negotiation), **INV-7**
  (data-plane public-API audience/EDR binding), **INV-8** (EDR refresh scoping, applicability to be
  measured) — because INV-1/2 are fixed classes and INV-3 is likely NA, so without these only INV-4/5
  could find anything. (3) **INV-4 cross-party** requires a **third participant** with its own
  IdentityHub identity; added to the step-2 handshake plan. Mutation configs are labelled test-only,
  never used for a current-release verdict, and encode the spec rule (no finding).

- **A2 — 2026-11-05 — INV-6 oracle made falsifiable (release-bound negotiation constraint).**
  User-approved redesign (chosen option: "release-bound probe"), 2026-11-05. No current-release INV-6
  verdict had been admitted into any tracked artifact when this was made.
  - **Problem (Review 18 W1).** INV-6 as first built (Review 16) made the admission gate's sanity
    *deny-leg* (bound policy, deny party B, same build+config) the **same measurement** as the
    current-release verdict (bound policy, deny B → does B terminate?). Admission and verdict were not
    independent: a genuine current FAIL was indistinguishable from a failed admission and collapsed to
    INVALID, masking the finding. INV-6 was therefore non-falsifiable.
  - **Fix — admission no longer measures the deny case.** It rests on:
    1. **Precondition (from pinned source, not a pilot fixture):** the *release itself* registers and
       binds a `Permission` constraint to the contract-negotiation scope.
       - *Tractus-X 0.13.0:* **Membership** — `edc-extensions/cx-policy/src/main/java/org/eclipse/tractusx/edc/policy/cx/CxPolicyExtension.java:183`
         registers `MembershipCredentialConstraintFunction` for `ContractNegotiationPolicyContext`
         (leftOperand `https://w3id.org/catenax/2025/9/policy/Membership`;
         `.../membership/MembershipCredentialConstraintFunction.java:43,51`). **BusinessPartnerNumber** —
         `edc-extensions/bpn-validation/bpn-validation-core/src/main/java/org/eclipse/tractusx/edc/validation/businesspartner/BusinessPartnerNumberValidationExtension.java:82`
         binds the BPN permission function to `NEGOTIATION_SCOPE` ("contract.negotiation"), registered at `:92–93`.
    2. **Sanity (admit case; PASS by construction):** an offer whose release-bound negotiation constraint
       party B *satisfies* → B's negotiation **FINALIZES**; positive control A **FINALIZES**. No deny case
       is measured in sanity.
    3. **Mutation (must FAIL — admission):** a **labelled, test-only classpath add-on** (same add-on
       mechanism as the DSP-TCK baseline) that overrides the release's negotiation constraint function for
       the probed leftOperand with a permissive stand-in, so the deny offer's constraint is silently
       satisfied → B **FINALIZES** a forbidden agreement → FAIL. The add-on is **never** on a
       current-release classpath; its jar sha256 is recorded per mutation cell.
  - **Verdict (current release, pristine image, no add-on):** the deny offer against the unmodified
    release: B **TERMINATES** → PASS (invariant held); B **FINALIZES** → FAIL (finding). Positive control
    A **FINALIZES** on every cell. This is a measurement **distinct** from both sanity (admit case) and
    mutation (unbound deny), so a current FAIL is reportable with valid admission.
  - **Target coverage.** The probe requires the release to ship a negotiation-scope constraint.
    Tractus-X 0.13.0 does (above). **Vanilla EDC 0.18.1** registers the negotiation scope
    (`core/control-plane/control-plane-contract/src/main/java/org/eclipse/edc/connector/controlplane/contract/ContractCoreExtension.java:105`)
    but ships **no** `Permission` constraint function bound to it (no
    `registerFunction(ContractNegotiationPolicyContext, …, Permission, …)` in released core; the CEL
    policy-core extension is not on the assembled DCP connector classpath). With nothing release-bound to
    probe, INV-6 on vanilla is recorded **INVALID:no-release-bound-negotiation-constraint** (never a
    vacuous PASS; the former `pilot08Member` fixture is retired as an admission basis). **INV-6 is
    therefore Tractus-X-only**, joining INV-4/INV-7 (user direction "Invest, Tractus-X only", 2026-11-04).
  - This amendment changes INV-6's oracle mechanics only; it adds no invariant and encodes no finding.

- **A3 — 2026-11-06 — INV-4 delivery + admission (DSP client fixture; defense-in-depth).** User-approved
  (chosen option: "admit per Review 17"), 2026-11-06. No current-release INV-4 verdict had been admitted
  into any tracked artifact when this was made. Tractus-X only.
  - **Delivery (why a client fixture is needed).** The provider binds a transfer to a valid agreement for
    the requesting counterparty on the DSP transfer-request path. EDC's honest consumer refuses to even
    emit a transfer for an agreement it does not hold locally
    (`TransferProcessServiceImpl.initiateTransfer` → badRequest when
    `contractNegotiationStore.findContractAgreement(contractId) == null`), so the attack can only be
    delivered to the provider's boundary by a **DSP client fixture** on the attacker (B) that removes that
    client-side precondition. B authenticates with its **own** legitimately-issued DCP token; A's token/VP
    and private keys are never touched; the provider under test keeps **all** checks on and is pristine for
    the verdict. This is a TCK-style negative conformance test (SCOPE's "DSP client fixture"), not a bypass
    of the provider.
  - **Mechanics — layered enforcement (from pinned source).** On the DSP transfer-request path the release
    resolves the cited agreement at `TransferProcessProtocolServiceImpl.fetchNotifyRequestContext` →
    `findAgreement`, a **participant-scoped** query (`queryByParticipantContextId(...) + agreementId`) whose
    miss yields a DSP `TransferError` with status **404**; the consumer-identity check
    `ContractValidationService.validateAgreement` (`ContractValidationServiceImpl`: the agent identity must
    be the agreement's consumer or provider) is a **separate, later** step whose failure is a **409**. The
    two are **independent layers**, so a labelled add-on that neutralizes only `validateAgreement` cannot by
    itself realize the INV-4 violation. This is source-structural only; **no run observation is recorded in
    tracked files** — any observed behaviour lives under `private/kc2/`.
  - **Admission tier.** Because the enforcement is layered, a single-check A1 mutation (neutralize one check
    → violation) is not available. INV-4 is therefore admitted at a **distinct, weaker tier than A1**: the
    **positive control** (A's own transfer reaches STARTED, in both the sanity and current cells) must hold,
    and the **assertion** is that B's DSP transfer citing A's agreement is refused. This is **not** a
    substitute for an A1 mutation FAIL; the report names INV-4's admission tier explicitly and separately
    from the A1-admitted invariants. The `validateAgreement`-neutralizing add-on is retained only as a
    labelled mechanics probe (its batch cell returns `NA` with the layering reason), never as an A1 gate;
    the batch admits this A3 path only for the allow-listed (invariant, target) carrying that specific
    reason (`60_phase3_batch.sh`).
  - **Verdict (oracle).** PASS = the assertion holds with the positive control intact; FAIL = B's
    foreign-agreement transfer is accepted; INVALID = the attack was not delivered or the positive control
    fails.
  - **Preferred upgrade (Review 20 Y3).** A two-layer mutation add-on that neutralizes **both** provider
    checks (restoring an A1 mutation FAIL with A's positive control intact, never on a current-release
    classpath) would supersede this weaker tier; it is pending the user's decision and the timebox.
  - This amendment refines INV-4's delivery and admission mechanics only; it adds no invariant and records no
    finding or run observation.

## Scope limitation (D13, 2026-10-26)

KC2's DCP handshake uses MembershipCredentials **issued directly** (issuer-signed VC stored into each
holder's IdentityHub), **not** obtained through the DCP **issuance protocol**. The issuance protocol is
therefore **out of scope** for KC2; the paper must state this. Credentials are nonetheless realistic
(correct `MembershipCredential` type, holder DID as subject, real issue/expiry, resolvable issuer
did:web), so an INV-5 / handshake verdict reflects the verifier's authorization logic, not a malformed
credential.

**Further testbed deviations (Review 14 T1/T4; not changes to the frozen set):**
- **Holder-side scope-alias adapter.** The holder IdentityHub is vanilla EDC IdentityHub 0.17.0 plus a test-fixture transformer accepting the Tractus-X scope alias (DECISIONS D11 amendment 2, fix 4) — mirroring Tractus-X's own DCP test runtime. It affects only how a presentation query selects stored credentials; the verifier's checks (VP signature, issuer trust, token claims) are untouched. Applied only to targets that need it.
- **did:web over HTTP.** The testbed resolves `did:web` over plain HTTP on the internal network (`edc.iam.did.web.use.https=false`), since no TLS PKI is available offline. Transport only; DID-document contents and every authorization decision are unaffected.
