# KC2 step 2 — DCP handshake plan (to a 200 catalogue)

Wiring derived from the Tractus-X 0.13.0 source (`edc-tests` RemoteParticipant/DataspaceIssuer),
IdentityHub 0.17.0 and the BDRS 0.6.0 server. Local testbed only; no findings here (infra design).

## Topology (internal network `pilot08k2_dsp`)

```
provider (TX edc-runtime-memory 0.13.0)  ──STS/creds──▶  provider-ih (IdentityHub 0.17.0)
consumer (TX edc-runtime-memory 0.13.0)  ──STS/creds──▶  consumer-ih (IdentityHub 0.17.0)
third    (TX edc-runtime-memory 0.13.0)  ──STS/creds──▶  third-ih    (IdentityHub 0.17.0)   # INV-4 cross-party
issuer   (IssuerService 0.17.0, trusted) ── issues MembershipCredential ──▶ each IdentityHub
bdrs     (tractusx/bdrs-server-memory 0.6.0)  ── BPN→DID directory ──▶ all connectors
```
Each connector delegates identity to **its own** IdentityHub: the IdentityHub runs the remote **STS**
(mints the self-issued token) and the **credential/presentation service** (returns the VP holding the
MembershipCredential). The provider, on an inbound request, resolves the counterparty DID (did:web via
that counterparty's IdentityHub), calls the counterparty credential service for the VP, and checks the
MembershipCredential issuer ∈ its trusted-issuer list; BDRS maps BPN↔DID.

## Connector config (per connector, from RemoteParticipant.getConfig)

- `edc.participant.id`, `edc.api.auth.key`
- web contexts: default/management/protocol(dsp)/control/public ports+paths
- `edc.iam.issuer.id` = this participant's DID (`did:web:<id>-ih%3A<didport>:<id>`)
- `edc.iam.did.web.use.https=false`
- Remote STS: `edc.iam.sts.oauth.token.url` = `http://<id>-ih:7083/api/sts/token`,
  `edc.iam.sts.oauth.client.id` = this DID, `edc.iam.sts.oauth.client.secret.alias` = vault alias of the
  **known** STS client secret (same value the seed extension set in the IdentityHub STS account).
- Credential service: `tx.edc.iam.dcp.credentialservice.url` = this IdentityHub's presentation endpoint.
- BDRS: `tx.edc.iam.dcp.bdrs.server.url` = `http://bdrs:8080/api/directory` (confirm path vs client).
- Trusted issuer: `edc.iam.trusted-issuer.issuer.id` = issuer DID (**negative control** = an *untrusted*
  issuer DID omitted from this list — INV-5).
- Transfer proxy token signer/verifier key aliases; vault seeded via `TX_EDC_VAULT_SECRETS` / `EDC_VAULT_SECRETS`.

## Seeding status

- **DONE** participant context + Ed25519 keypair + did:web publication (Kc2SeedExtension).
- **DONE** known STS client secret set in the IdentityHub STS account (seed extension, from
  `pilot08.kc2.seed.sts.client.secret`) so the connector can authenticate to STS.
- **TODO (the crux)** each IdentityHub must hold its participant's **MembershipCredential**, issued by the
  trusted issuer, so the credential service can return a VP. Two routes (user decision — fidelity vs effort):
  - **Route I (issuer-signed VC stored via the IdentityHub VC admin API).** The issuer signs a
    MembershipCredential JWT with its key (EDC's own JWT/VC libs — this is exactly what the Tractus-X e2e
    `DataspaceIssuer` fixture does) and it is stored as a `VerifiableCredentialResource` in each holder's
    IdentityHub. Faster; uses the real issuer key + official libs; skips the DCP issuance *protocol*.
  - **Route II (full DCP issuance protocol via IssuerService).** Register each holder at the IssuerService,
    define an attestation + credential definition, run the holder credential-request → issuance-process →
    credential-offer → store. Most faithful; much heavier (issuer onboarding machinery).

## Negative control (INV-5) and cross-party (INV-4)

- **Untrusted-issuer negative control:** a second issuer J (not in the provider's trusted list) issues a
  MembershipCredential to the consumer; with that credential the consumer must be **refused** at the DSP
  boundary (no 200). Mutation-config check for INV-5 is the provider *also* trusting J (then accepted).
- **Third participant** `third` + `third-ih`: gives INV-4 its cross-party case (party B reusing A's agreement).

## Done when

A DCP-authenticated **200 catalogue** consumer→provider with real DCP tokens, recorded in a smoke CSV.
Per Review 12 R6 the handshake smoke + all later verdicts route to `private/kc2/` (gitignored); tracked
files state only that the positive control passed, with no finding content. Re-run isolation with the
full stack up; keys/credentials stay under gitignored paths.

## Smoke-output routing (Review 13 S3)

- **Tracked** `kc2/env/handshake-smoke.csv` holds **infrastructure rows only**: service readiness, the
  DCP-authenticated **200 catalogue with the trusted issuer** (the positive control that the stack
  works), and did:web / BDRS resolution.
- **Private** (`kc2_private_out` → `private/kc2/`, gitignored) holds everything that is an **invariant
  assertion on a current release**: the untrusted-J refusal (INV-5), the third-participant cross-party
  check (INV-4), and every sanity-vs-mutation admission row. When unsure, treat a row as private.

## Status (2026-10-27)

- **Tractus-X 0.13.0: DCP-authenticated 200 catalogue reached** (consumer→provider), after the four interop
  fixes in DECISIONS D11 amendment 2. Infra rows in `kc2/env/handshake-smoke.csv`.
- **Remaining for step 2:** vanilla EDC 0.18.1 target (own launcher with the DCP modules) to a 200;
  third participant; untrusted-issuer (INV-5) negative control — **private only**; isolation re-run with
  every service up.
- 2026-10-27: **three participants** (provider, consumer, third — each its own IdentityHub identity) all
  reach the DCP-authenticated 200 catalogue with the trusted issuer (`handshake-smoke.csv` 15/15, clean
  `1240aed`); isolation re-measured with the full stack up (8/8). The **untrusted-issuer negative control
  (INV-5) has been run; its observations and verdict are held in `private/kc2/`** (pre-TCK, not counted).
  Remaining: vanilla EDC 0.18.1 target.
