# Verifying npm package attestations from Lightwell Pulp

Consumer procedure for verifying the origin and integrity of npm packages
published to Lightwell's Pulp npm repositories — the npm analog of the Python
wheel provenance procedure (PEP 740 + cosign). Companion to
[story-pulp-npm-package-attestations.md](./story-pulp-npm-package-attestations.md).

Two paths:

1. **`npm audit signatures` (primary)** — the native client flow. Works as soon
   as Pulp serves the npm client contract (`dist.attestations` packument
   pointers, `/-/npm/v1/attestations/{name}@{version}`, `/-/npm/v1/keys`).
   Verifies bundle signatures, trust root (Sigstore TUF), subject/PURL/sha512
   binding to the installed tarball, and transparency-log inclusion — no manual
   steps.
2. **cosign out-of-band (fallback)** — for verifying a downloaded tarball
   without an install tree, mirroring the documented Python wheel flow.

## Before you begin

You have access to the Lightwell npm repository on packages.redhat.com. For more
information, see Lightwell Network repository access and Create a Lightwell
Network service account.

npm requires the credentials as basic auth (e.g. via `~/.npmrc`
`//packages.redhat.com/.../:_authToken=` or `_auth`).

## Procedure — npm audit signatures (primary)

Set shell variables:

```bash
REPOSITORY='<repository>'   # e.g. validated
```

Install the packages against the Lightwell registry, then audit:

```bash
npm install --registry \
  "https://packages.redhat.com/api/npm/lightwell/npm/${REPOSITORY}/"

npm audit signatures --registry \
  "https://packages.redhat.com/api/npm/lightwell/npm/${REPOSITORY}/"
```

**Lockfile caveat:** `--registry` does not rewrite `resolved` URLs already
recorded in an existing package-lock.json — a locked install can still pull
tarballs from npmjs. Either regenerate the lockfile against Lightwell
(`rm package-lock.json && npm install --registry …`) or configure the registry
in `.npmrc` (`@scope:registry=` / `registry=`) before locking, and verify the
lockfile's `resolved` URLs point at the Lightwell registry before auditing.

Expected output for an attested package:

```text
audited N packages in Xs

N packages have a verified attestation
```

Add `--json --include-attestations` to see the verified Sigstore bundles.

Notes:

- `npm audit signatures` verifies the tree **installed** in the current project,
  so it covers every dependency resolved from the Lightwell registry.
- Keyed (registry-signed / publish) attestations additionally require
  `/-/npm/v1/keys` on the registry; keyless Fulcio/Rekor provenance is
  self-contained.
- pnpm users: pnpm's provenance verification consumes the same
  `dist.attestations` flow.

## Procedure — cosign out-of-band (fallback)

Set shell variables for the tarball to verify:

```bash
TARBALL='<filename>.tgz'          # e.g. express-4.22.1.tgz
PACKAGE='<name>'                  # e.g. express
VERSION='<version>'               # e.g. 4.22.1
REPOSITORY='<repository>'         # e.g. validated
```

Download the Red Hat RELEASE3 public key from the Red Hat Product Signing Keys
page and extract the PEM public-key block:

```bash
curl -fsSLo release3.txt \
  https://security.access.redhat.com/data/63405576.txt
sed -n '/-----BEGIN PUBLIC KEY-----/,$p' release3.txt > release3.pub
```

Download the tarball (adjust the content path to your repository layout; the
credentials mirror the `.npmrc` basic auth used by npm):

```bash
curl -fsSLO \
  --user "${LIGHTWELL_USERNAME}:${LIGHTWELL_TOKEN}" \
  "https://packages.redhat.com/api/pulp-content/lightwell/npm/${REPOSITORY}/${TARBALL}"
```

Download the attestation bundles. npm attestations are Sigstore bundles; the
DSSE envelope inside is what cosign consumes — extraction only, no reshaping
(unlike the Python PEP 740 flow). Scoped package names must be URL-encoded
(the `/` in `@scope/name` becomes `%2F`):

```bash
PACKAGE_ENCODED=$(printf '%s' "${PACKAGE}" | jq -sRr @uri)

curl -fsSLo "${TARBALL}.attestations.json" \
  --user "${LIGHTWELL_USERNAME}:${LIGHTWELL_TOKEN}" \
  "https://packages.redhat.com/api/npm/lightwell/npm/${REPOSITORY}/-/npm/v1/attestations/${PACKAGE_ENCODED}@${VERSION}"

jq '.attestations[]
    | select(.predicateType == "https://slsa.dev/provenance/v1")
    | .bundle.dsseEnvelope' \
  "${TARBALL}.attestations.json" > "${TARBALL}.dsse.json"
```

Verify the RELEASE3 signature and the tarball digest binding in the SLSA
statement with cosign. **This fallback verifies *keyed* (RELEASE3-signed)
attestations**, which is how Lightwell signs its npm content:

```bash
cosign verify-blob-attestation \
  --insecure-ignore-tlog \
  --type https://slsa.dev/provenance/v1 \
  --key release3.pub \
  --signature "${TARBALL}.dsse.json" \
  "${TARBALL}"
```

> **Keyless footnote:** bundles signed keylessly (Fulcio certificate + Rekor
> transparency-log entry — the format upstream `npm publish --provenance`
> produces, so they can appear when mirroring upstream registries) will **not**
> verify against the RELEASE3 key. `npm audit signatures` handles both keyed
> and keyless modes with no branching, so use the primary procedure for those.
> If you must verify a keyless bundle out-of-band with cosign, pass the full
> bundle instead of the extracted envelope:
> `cosign verify-blob-attestation --bundle <bundle.json> --type https://slsa.dev/provenance/v1 <tarball>`.

### Caveat: sha256 vs sha512 subject digests

npm statements bind the subject with `digest.sha512` (pacote checks sha512
against the tarball integrity). `cosign verify-blob-attestation` computes the
blob's **sha256** and matches it against statement subjects, so a sha512-only
subject can fail with "no matching subjects" — this applies to both the keyed
(envelope) and keyless (bundle) cosign invocations above. Two mitigations:

- **Producer-side (required):** the signing pipeline emits **both** sha256 and
  sha512 digests in the statement subject. Pulp accepts both (see the story
  doc's validation rules). This is the only sound fix — the signature covers
  the statement, so a consumer cannot inject a sha256 into a signed payload
  after the fact without invalidating it.

If the statement is sha512-only, use `npm audit signatures` (which checks
sha512, matching pacote) rather than cosign `verify-blob-attestation`.

### cosign v3 note

cosign v3's move away from bare-DSSE storage affects **OCI registry storage**
(OCI layers → Sigstore bundles). `cosign verify-blob-attestation` still accepts
a DSSE envelope as `--signature` input in v3, and npm's native format is the
Sigstore bundle with DSSE inside — so the same published artifact serves both
`npm audit signatures` and this cosign procedure. No dual format needed.
