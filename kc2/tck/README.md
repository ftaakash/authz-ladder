# KC2 DSP-TCK configuration (D14, Option A)

Copies of upstream's own DSP-TCK configuration at the pinned commits, with `host.docker.internal` replaced by
`cut` (the connector-under-test's alias on the internal network). Apache-2.0, unmodified otherwise.

| Target | Files | Upstream source |
|---|---|---|
| vanilla EDC 0.18.1 | `vanilla/config.properties`, `dspace-edc-context-v1.jsonld` | eclipse-edc/Connector `v0.18.1` (`3a22ff4`) `system-tests/tck/dsp-tck-tests/src/test/resources/` |
| Tractus-X 0.13.0 | `tractusx/config.properties` | eclipse-tractusx/tractusx-edc `0.13.0` (`964d33d`) `edc-tests/e2e/dsp-tck-tests/src/test/resources/docker.tck.properties` |
| Tractus-X 0.13.0 | `tractusx/dspace-edc-context-v1.jsonld` | eclipse-edc/Connector `v0.17.0` (`737bfc9`) `core/common/lib/json-ld-lib/src/main/resources/document/` |
| Tractus-X 0.13.0 | `tractusx/tx-auth-v1.jsonld`, `cx-policy-v1.jsonld` | tractusx-edc `0.13.0` `core/json-ld-core/…/document/`, `core/json-ld-cx/…/document/` |

The TCK's mock identity is the static `dataspacetck.dsp.connector.http.headers.authorization` header (as upstream);
no DCP is involved (D14 claim wording).
