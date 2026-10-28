# Tractus-X 0.13.0 DSP-TCK stand-ins — upstream source vs. this reproduction (Review 15 U3, 2026-10-29)

Upstream: eclipse-tractusx/tractusx-edc tag `0.13.0` = `964d33d7ed942369f624aacbc45037a1f79fc7be`,
`edc-tests/e2e/dsp-tck-tests/src/test/java/org/eclipse/tractusx/edc/tests/tck/dsp/EdcCompatibilityPostgresTest.java`
(stand-ins at lines 76–130, injected with `EmbeddedRuntime.registerServiceMock`).
Reproduction: `kc2/tck-tx/src/main/java/pilot08kc2tck/Kc2TxTckFixtureExtension.java`, `Kc2TxTckPolicyArchiveExtension.java`.

| Service | Upstream behaviour (source) | Reproduction | Semantic difference |
|---|---|---|---|
| `BdrsClient` | `new MockBdrsClient(s -> s, s -> s)` (`edc-tests/e2e-fixtures/.../MockBdrsClient.java`: `resolveDid = didResolver.apply`, `resolveBpn = bpnResolver.apply`) → identity both ways | `TckPassThroughBdrsClient`: `resolveDid(bpn) = bpn`, `resolveBpn(did) = did` | none |
| `AgreementsBpnsStore` | `save` → `StoreResult.success()`; `findByAgreementId(id)` → entry(id, providerBpn = BPN, consumerBpn = BPN), `BPN = "BPNL0000" + "participantContextId"` | `TckAgreementsBpnsStore`: same, BPN from `pilot08.kc2.tck.bpn` = `BPNL0000participantContextId` (set by `50_tck_baseline.sh`) | none (same value) |
| `PolicyArchive` | `findPolicyForContract` → `Policy(assigner = assignee = "TCK_PARTICIPANT")`; `getAgreementIdForContract(id)` → `id` | `TckPolicyArchive`: same | none |
| `DataspaceProfileContextRegistry` | `spy(new DataspaceProfileContextRegistryImpl())` with `getIdExtractionFunction(any)` → `ct -> ct.getStringClaim("client_id")` | `TckClientIdProfileContextRegistry extends DataspaceProfileContextRegistryImpl`, overriding only `getIdExtractionFunction` → same function | none (subclass override ≡ partial-mock override; all other methods are the real impl in both) |

**What differs is mechanism only, not policy semantics:**
1. *Injection mechanism.* Upstream replaces services in-process via `registerServiceMock`; here they are EDC `@Provider`s.
   Each stand-in is a **named class** so the boot log names the winner, and the `PolicyArchive` stand-in is **ordered
   deterministically** (its extension injects `ContractNegotiationObservable`, provided only by the extension that provides the
   real `PolicyArchive`). `50_tck_baseline.sh` asserts the winners (IdentityService → `NoopIdentityService`, PolicyArchive →
   `TckPolicyArchive`, BdrsClient → `TckPassThroughBdrsClient`) before recording results. `AgreementsBpnsStore` and
   `DataspaceProfileContextRegistry` replace `@Provider(isDefault = true)` services, which is deterministic.
2. *Not a stand-in, but a runtime difference:* upstream's connector-under-test is the PostgreSQL/HashiCorp runtime
   (`:edc-tests:runtime:runtime-dsp` → `runtime-postgresql`); here it is the **in-memory release image binary**
   (`tractusx/edc-runtime-memory:0.13.0`), i.e. the KC2 target itself. Stores differ (memory vs. SQL); protocol code is the same.
3. *TCK version:* 1.0.2 here vs. 1.0.0 pinned upstream.

Conclusion: no semantic change to any stand-in, so the Tractus-X TCK result is **not** marked UNVERIFIED on that ground.
