# Story: Pulp npm package attestations (Sigstore bundles / in-toto)

**Audience:** Pulp / pulp_npm maintainers
**Requesting consumers:** Calunga / Lightwell npm release pipelines (Konflux)
**Analogy:** [pulp_python attestation hosting (PEP 740)](https://pulpproject.org/pulp_python/docs/user/guides/attestation/) — same *role* (package-bound signed metadata), different envelope (Sigstore bundle, not PEP 740)
**Status:** Draft for implementation planning (revised: bundle format + client-facing serving made MVP goals)

> **Revision note (2026-11):** the original draft chose raw cosign DSSE envelopes,
> REST-only serving, and sha256 subjects, with npm CLI compatibility deferred.
> Review showed that npm clients consume **Sigstore bundles** only — a raw DSSE
> envelope cannot be served to any npm tooling without re-wrapping later — and
> that a Sigstore bundle already *contains* the DSSE envelope, so storing bundles
> satisfies every original DSSE goal at zero extra cost. This revision flips
> those three decisions; producer/REST ergonomics are unchanged.

---

## Summary

Add first-class **package attestation** support to `pulp_npm`: store **Sigstore
bundles** (`application/vnd.dev.sigstore.bundle+json`, v0.1/v0.2) wrapping
DSSE/in-toto statements, associated with an npm package content unit (tarball),
and serve them through the **npm client-facing contract** so `npm audit
signatures` (and pnpm provenance verification) works against Pulp-hosted
registries unchanged.

MVP is **not** limited to SLSA provenance. Pulp should accept an **allowlist**
of in-toto `predicateType` values so the same storage path can hold:

- SLSA provenance — `https://slsa.dev/provenance/v1`
- Verification Summary Attestation (VSA) — see [in-toto VSA predicate](https://github.com/in-toto/attestation/blob/main/spec/predicates/vsa.md)
- Additional predicate types later via config/allowlist expansion (no new content type per predicate)

Calunga's first producer will upload SLSA provenance; other predicates (e.g.
VSA) must upload through the same API without a redesign.

Today npm packages upload via `content/npm/packages/` (and optional labels).
There is **no** npm attestation content type.

## The client contract (why bundle format + serving matter)

npm's attestation flow is defined **behaviorally** by the official clients,
not by a spec document:

| Client piece | Location | Role |
| --- | --- | --- |
| `npm/cli` `lib/utils/verify-signatures.js` | [npm/cli](https://github.com/npm/cli) | `npm audit signatures` engine; gets keys via Sigstore TUF, falls back to `GET /-/npm/v1/keys` |
| `npm/pacote` `lib/registry.js` | [npm/pacote](https://github.com/npm/pacote) | **The de facto spec**: reads `dist.attestations.url`, re-fetches its *pathname* against the configured registry host, verifies each Sigstore bundle |
| `npm/cli` `workspaces/libnpmpublish/lib/{publish,provenance}.js` | [npm/cli](https://github.com/npm/cli) | Publish side: bundle attached as `{name}-{version}.sigstore` in `_attachments` |

> Note: the former [`npm/provenance`](https://github.com/npm/provenance) repo is
> **archived** (Dec 2024). The pacote source is now the closest thing to a
> registry specification; pnpm implements the same `dist.attestations` flow, so
> at least two independent package managers consume this contract.

What clients require of a registry:

1. **Packument pointer** — the per-version manifest must carry:
   ```json
   "dist": {
     "attestations": {
       "url": "/-/npm/v1/attestations/{name}@{version}",
       "provenance": { "predicateType": "https://slsa.dev/provenance/v1" }
     }
   }
   ```
   pacote uses only the **pathname** of `dist.attestations.url` and re-fetches it
   from whatever registry host it talks to — so mirror-friendly by construction.
2. **`GET /-/npm/v1/attestations/{name}@{version}`** returning:
   ```json
   { "attestations": [ { "predicateType": "...", "bundle": { /* sigstore bundle */ } } ] }
   ```
   A raw DSSE envelope without the bundle wrapper fails client parsing
   immediately (`bundle.dsseEnvelope.payload`, `bundle.verificationMaterial.tlogEntries`
   are destructured directly).
3. **`GET /-/npm/v1/keys`** returning `{ keys: [{ keyid, pemkey, expires }] }` —
   required for **keyed** (registry-signed / publish) attestations. Keyless
   Fulcio/Rekor provenance bundles are self-contained and skip this.
4. **Subject binding** — in-toto statement subject is the canonical PURL for `pkg:npm/{name}@{version}` (scoped names: `pkg:npm/%40scope/name@…`) with `digest.sha512` matching the tarball.

## Problem

| Ecosystem | Package upload | Attestations today |
|-----------|----------------|--------------------|
| Python (`pulp_python`) | packages + twine | `content/python/provenance/`, Simple + Integrity API, PEP 740 (provenance-shaped) |
| npm (`pulp_npm`) | `content/npm/packages/upload/` | **None** (compliance is labels / optional file-repo sidecars / Quay OCI) |

Without package-bound attestation content:

- Release pipelines cannot attach signed in-toto attestations (SLSA, VSA, …) to published `.tgz` units.
- Consumers cannot fetch package-bound attestations from Pulp with repo add/remove/sync semantics.
- `npm audit signatures` cannot verify anything served from Pulp — the npm
  analog of the Python Integrity API does not exist.

## Goals (MVP)

1. **Content type** for npm package attestations (prefer name like `NpmPackageAttestation`; avoid baking "provenance-only" into the type name). Content units are unique by digest of the stored bundle (immutable content).
2. **Associate** each attestation with an existing npm package content unit (by package PRN/href and/or tarball digest). The package must already be present in the **target repository version** when associating (no orphan attestations in a version that lacks the package).
3. **Upload APIs:**
   - Create attestation(s) for an **already-published** package (backfill / remediation).
   - Optionally attach attestation(s) **at package upload** time.
4. **Repository semantics:** attestations are repository content — add/remove/sync with the package (removing the package from a repo version removes its attestation associations in that version).
5. **Uniqueness:** at most **one attestation per `(package, predicateType)` per repository version**, enforced atomically on create/replace. **Different** `predicateType`s (e.g. SLSA + VSA) **coexist**. Same bundle digest re-upload is **idempotent** (reuse the existing content unit / association); a **different** bundle for the same `predicateType` creates a new unit and rewires the association.
6. **Retrieve** attestations for a package (REST required for MVP), filterable by `predicateType`.
7. **Format:** **Sigstore bundle** (`application/vnd.dev.sigstore.bundle+json`, v0.1 and v0.2) — the bundle contains the DSSE envelope, the signing certificate, and (for keyless) the tlog entry. Producers who only have a cosign DSSE envelope today can wrap it into a bundle at upload time or beforehand; Pulp stores and serves the bundle.
8. **Serve the npm client contract** (revised — was a non-goal):
   - Stamp `dist.attestations` (url + provenance predicateType) into served packuments for versions that have attestations.
   - Serve `GET /-/npm/v1/attestations/{name}@{version}` on distributions.
   - Serve `GET /-/npm/v1/keys` for keyed attestations (configurable; keyless-only registries may 404). **Keyed-signing registries must serve their public keys here** — for a non-npmjs registry, `npm audit signatures` finds no TUF target for the host and falls back to this endpoint; without it, keyed attestations fail with `EMISSINGSIGNATUREKEY`. `npm audit signatures` verifies both keyed and keyless bundles natively, so the two modes impose no client-side branching.
9. **Sync:** mirror attestations + `dist.attestations` pointers when syncing from an upstream npm-compatible registry. **Sync atomicity:** bundles and their packument pointers must become visible in the same repository-version commit — a packument pointer to a bundle that was not (yet) copied makes `npm audit signatures` fail for the mirrored package. The safest implementation derives pointers at serve time from committed associations (see open question 10), which makes this invariant hold by construction.
10. **Accept client verification as the conformance test:** a Pulp-published repo must pass `npm audit signatures` end-to-end (and ideally pnpm provenance verification) — not just curl-shaped response inspection. See acceptance criteria.

## Non-goals (MVP)

- **PEP 740** wrappers or Python Integrity API compatibility for npm.
- Cryptographic signature verification inside Pulp (store + associate + serve; clients verify with `npm audit signatures`, cosign, sigstore, slsa-verifier).
- Acting as a **Fulcio/Rekor participant** (issuing keyless attestations) — MVP producers bring pre-signed bundles, keyed or keyless.
- Open-ended "any bundle" dumping ground — use an **allowlist**, not "parseable only".
- Requiring rich Chains-enriched SLSA predicates (placeholders OK; richer predicates must still upload).
- Compliance metadata (`tl.compliance_level`, closure index OCI) — handled elsewhere.
- Implementing VSA *producers* in Calunga (Pulp only needs to *accept/store* VSA when uploaded).

## Proposed behavior (sketch for design)

Python used `provenance` for historical/PEP 740 reasons. For npm prefer an
`attestations` content API (name TBD with maintainers):

```text
POST .../content/npm/attestations/
  - file: <sigstore bundle> .sigstore / .json  (or JSON body)
  - package: <npm package pulp_href | prn>
  - repository: <npm repo href>   # optional if using modify flow
  # and/or package tarball digest

POST .../content/npm/packages/upload/  (enhancement)
  - existing package fields
  - attestation(s): one or more Sigstore bundle files  # optional in MVP if backfill-only ships first
```

**Attach-at-upload atomicity:** If attestations are accepted on the package upload path, treat package + all supplied attestations as one transaction: on **any** failure (validation **or** persistence after validation), **fail the whole upload**, roll back, and do not leave the package in the repository without the supplied attestations. Validate-then-create alone is insufficient unless writes are also transactional. Backfill-only creates only fail the attestation create.

Retrieve (minimum):

```text
GET .../content/npm/attestations/?package=<href>&repository_version=<rv>
GET .../content/npm/attestations/?package=<href>&predicate_type=<uri>&repository_version=<rv>
# or GET by attestation pulp_href
```

Client-facing (distributions):

```text
GET {distribution}/-/npm/v1/attestations/{name}@{version}   # bundle list
GET {distribution}/-/npm/v1/keys                            # keyed attestation keys
# packument: versions[v].dist.attestations = { url, provenance: { predicateType } }
```

**Uniqueness / immutability:** Content units are immutable (never mutate an existing unit in place). For a given `(package, predicateType)` in a repository version:

- **Identical bundle** (same content digest already stored and associated): **idempotent** success — do not create a duplicate unit.
- **Different bundle** (new digest, same `predicateType`): create a **new** unit and rewire the association (remove/replace the prior association in that repo version).
- **Different `predicateType`:** additional association; both remain.

Create/replace of the `(package, predicateType)` association must be **atomic** so concurrent uploads cannot leave two associations for the same pair in one repository version.

**Validation (MVP — fail closed):**

- Parseable Sigstore bundle: `mediaType` must be
  `application/vnd.dev.sigstore.bundle+json` with a `version` **parameter** of
  `0.1` or `0.2` (canonical bundles encode the version in the media type —
  `application/vnd.dev.sigstore.bundle+json;version=0.1` — and have no
  separate top-level `version` field); must contain `dsseEnvelope`.
- **Required:** `dsseEnvelope.signatures` is a non-empty array (structural guard only — presence of at least one signature object, not cryptographic validity).
- **Required:** `dsseEnvelope.payloadType` compatible with in-toto (`application/vnd.in-toto+json`).
- **Required:** `verificationMaterial` present, and `verificationMaterial.tlogEntries` array-valued — npm clients destructure these directly (pacote reads `tlogEntries[0].integratedTime` for keyed attestations; sigstore-js verification consumes tlog/ctlog entries), so a bundle without them breaks client verification even though the signature is otherwise well-formed.
- **Required:** decode the in-toto statement; `predicateType` must be on the **MVP allowlist**:
  - `https://slsa.dev/provenance/v1`
  - VSA predicate type URI as defined by [in-toto VSA](https://github.com/in-toto/attestation/blob/main/spec/predicates/vsa.md) (pin the exact string in implementation docs when implementing)
  - Allowlist must be **extensible** (setting / constant) so new predicate types do not need a new content type
- **Required:** reject if no subject matches the selected package: subject name equals the **canonical** PURL for `pkg:npm/{name}@{version}` — note that scoped names encode the scope (`pkg:npm/%40scope/name@1.0.0`, as produced by npm's `npa.toPurl`), so the comparison must use canonical PURL encoding, not raw string interpolation — and `digest.sha512` equals the package tarball's sha512. Accept **sha256 in addition** (not instead) when present — it costs nothing and keeps cosign `verify-blob-attestation` flows working without reshaping.
- **Required:** package is present in the target repository version (when associating into a repo).
- Still **out of scope:** cryptographic signature verification / trust-policy checks inside Pulp. Docs and client guidance must state that **hosting ≠ verification**; consumers verify with `npm audit signatures`, cosign, sigstore, or slsa-verifier.

Do **not** require specific SLSA `buildType` / builder IDs or deep validation of VSA predicate body fields beyond schema/allowlist membership — producer policy.

Authorization follows normal Pulp RBAC on repositories/content (write to associate; read visibility on retrieve). No special cross-tenant model beyond that.

## Acceptance criteria

1. Given an npm package in a repository, an authenticated client can upload a Sigstore bundle with an allowlisted `predicateType` and matching tarball subject and see a new attestation content unit linked to that package.
2. The same package can hold **both** an SLSA provenance attestation and a VSA attestation in one repository version.
3. Listing/filtering by `package` (and optionally `predicate_type`) returns the expected object(s); download returns stored bundle bytes/JSON.
4. **`npm audit signatures` passes end-to-end** against a Pulp distribution serving an attested package: packument carries `dist.attestations`, the `/-/npm/v1/attestations/{name}@{version}` endpoint returns the bundle(s), and the CLI reports the package as having a *verified* attestation. This is the conformance test for the client contract (the contract is behavioral — defined by pacote — not a spec document).
5. Re-upload of a **different** bundle for the **same** `predicateType` creates a **new** immutable unit and updates the repo association; re-upload of the **identical** bundle is **idempotent**.
6. Upload is **rejected** when the subject does not match the package tarball (name or digest), when `signatures` is empty, when the package is not in the target repository version, when `mediaType`/bundle version is unsupported, or when `predicateType` is not on the allowlist.
7. When attach-at-upload is implemented: any failure (validation or write) **fails the entire package upload** with rollback (no package left without the supplied attestations).
8. Attestations participate in repository add/remove/sync like other content; removing the package removes attestation associations in that version. **Syncing from an upstream npm registry mirrors both the bundles and the `dist.attestations` packument pointers.**
9. Documented API + `curl`/`pulp-cli` examples + the consumer verification procedure (`npm audit signatures` primary, cosign `verify-blob-attestation` fallback — see `docs/npm-attestation-verification.md` in this repo); functional tests/fixtures for bundles (SLSA and at least one non-SLSA allowlisted type, e.g. VSA), including idempotent re-upload, empty-`signatures` rejection, and raw-DSSE-without-bundle rejection.
10. Docs note: format is **Sigstore bundle (DSSE/in-toto inside)**, not PEP 740 and not bare DSSE; hosting does not imply signature verification.

## Consumer integration (out of scope for Pulp, for context)

After Pulp lands MVP:

1. Wire [`generate-and-sign-npm-attestations`](https://github.com/calungaproject/plumbing/blob/main/utils/scripts/generate-and-sign-npm-attestations) into [`calunga-push-npm-to-pulp`](https://github.com/konflux-ci/release-service-catalog/blob/development/pipelines/managed/calunga-push-npm-to-pulp/calunga-push-npm-to-pulp.yaml) (future managed task patterned on [`rh-sign-python-wheels`](https://github.com/konflux-ci/release-service-catalog/blob/development/tasks/managed/rh-sign-python-wheels/rh-sign-python-wheels.yaml); no `rh-sign-npm-packages` task exists yet). Producer output should be a **bundle**, not a bare `.att` — wrapping the cosign DSSE envelope into a Sigstore bundle at sign time.
2. Extend [`npm-pulp-upload`](https://github.com/calungaproject/plumbing/blob/main/utils/scripts/npm-pulp-upload) / [`npm-release-upload`](https://github.com/calungaproject/plumbing/blob/main/utils/scripts/npm-release-upload) (via [`upload-npm-pulp`](https://github.com/konflux-ci/release-service-catalog/blob/development/tasks/managed/upload-npm-pulp/upload-npm-pulp.yaml)) to POST bundles.
3. Optional later: enrich SLSA predicates from Tekton Chains ([`npm-fetch-chains-provenance`](https://github.com/calungaproject/plumbing/blob/main/utils/scripts/npm-fetch-chains-provenance)); upload VSA or other predicates from separate producers — **same Pulp API**.

## Open questions (design spike OK)

| # | Question | Notes / preference |
|---|----------|--------------------|
| 1 | Attach-at-upload in MVP, or backfill-only first? | Prefer both if cheap; attach-at-upload must be **atomic**. |
| 2 | REST + client endpoints together, or REST first? | Prefer together — client endpoints are the acceptance test. If split, client endpoints land in the **next** release, not "later." |
| 3 | ~~Raw DSSE vs Sigstore Bundle?~~ | **Resolved: Sigstore bundle.** DSSE-only was a dead end: no npm client can consume it, and the bundle contains the DSSE anyway. |
| 4 | ~~Subject digest sha256 vs sha512?~~ | **Resolved: sha512** (npm PURL subjects use sha512; that is what pacote checks). Accept sha256 **in addition** for cosign blob flows. |
| 5 | Endpoint naming | Prefer `content/npm/attestations/` (broader than `provenance/`) for REST. Client-facing paths are fixed by the npm contract (`/-/npm/v1/attestations/...`, `/-/npm/v1/keys`). |
| 6 | Allowlist mechanism | Constant vs settings; process to add predicates (e.g. SCITT, npm publish) without migrations. |
| 7 | Exact VSA `predicateType` URI | Pin to current in-toto VSA spec string at implementation time. |
| 8 | pulp CLI / content guards | Malformed bundle, non-allowlisted `predicateType`, subject mismatch fail closed. |
| 9 | Keyed-attestation key management | Who owns `/-/npm/v1/keys` content (registry-side signing keys)? Keyless-only MVP can defer. |
| 10 | Packument mutation vs derivation | Is `dist.attestations` stamped at publish time (stored in packument) or derived at serve time from repo-version associations? **Constraint either way:** backfilled attestations must become discoverable — stored pointers require packument update + cache invalidation whenever associations change; derived pointers (preferred) avoid that rewrite and make sync atomicity hold by construction. |

## References

- Python guide: https://pulpproject.org/pulp_python/docs/user/guides/attestation/
- **Client contract (authoritative, behavioral):**
  - npm/pacote `lib/registry.js` — attestation fetch + verify logic: https://github.com/npm/pacote/blob/main/lib/registry.js
  - npm/cli `lib/utils/verify-signatures.js` — `npm audit signatures` engine: https://github.com/npm/cli/blob/latest/lib/utils/verify-signatures.js
  - npm/cli `workspaces/libnpmpublish/lib/publish.js` — publish-time bundle attachment: https://github.com/npm/cli/blob/latest/workspaces/libnpmpublish/lib/publish.js
  - npm docs (prose): https://docs.npmjs.com/verifying-registry-signatures/ , https://docs.npmjs.com/generating-provenance-statements/
  - Note: https://github.com/npm/provenance is **archived** (Dec 2024) — do not cite it as the current contract.
- Sigstore bundle spec: https://github.com/sigstore/protobuf-specs (bundle v0.1/v0.2)
- DSSE: https://github.com/secure-systems-lab/dsse
- in-toto envelope: https://github.com/in-toto/attestation/blob/main/spec/v1/envelope.md
- SLSA provenance v1: https://slsa.dev/spec/v1.0/provenance
- VSA predicate: https://github.com/in-toto/attestation/blob/main/spec/predicates/vsa.md
- Producer stub (SLSA): https://github.com/calungaproject/plumbing/blob/main/utils/scripts/generate-and-sign-npm-attestations
- Consumer verification procedure (this repo): `docs/npm-attestation-verification.md`
- Related follow-ups: `docs/prod_followup.md`

## Suggested Jira title / description blurb

**Title:** pulp_npm: host package attestations as Sigstore bundles (in-toto allowlist) with npm client-contract serving

**Description:** Implement npm package attestation content (prefer `attestations` over provenance-only naming) storing **Sigstore bundles** (v0.1/v0.2; DSSE/in-toto inside) linked to npm packages by PURL subject (`pkg:npm/{name}@{version}`, sha512). MVP allowlist includes SLSA provenance v1 and VSA; uniqueness is one attestation per (package, predicateType) per repo version. Serve the npm client contract on distributions — `dist.attestations` packument pointers, `GET /-/npm/v1/attestations/{name}@{version}`, `GET /-/npm/v1/keys` — and mirror bundles + pointers on sync. Conformance test: `npm audit signatures` verifies an attested package served from Pulp. Non-goal: crypto verify inside Pulp. Tracking: PULP-2400.
