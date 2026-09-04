# zod@4.5.4 recipe evidence

## Source verification

- Repository: https://github.com/colinhacks/zod.git
- Tag: v4.5.4 (lightweight)
- Commit: e8e206fa33ac5fe7ce20a2beb12d57b1cb3df653
- Tarball integrity verified: sha512-sC95tT5iHHH9gtpj6A81kh+NEaRAUFN+qlUPDUbRfOMvNf5QCBqsb3WgvnpVtK5Y+4UfA6KqufotuTvMGiTlsA==

## Tier classification

**Tier A** — Pure TypeScript library with build step

### Rationale

- No native bindings (`binding.gyp` absent)
- No platform-specific optional dependencies
- No `.node` files in published tarball
- Build step only compiles TypeScript to JavaScript and generates type definitions
- Upstream has `build` and `prepublishOnly` lifecycle scripts

### Upstream structure

- Source: TypeScript under `src/`
- Build output: JavaScript + type definitions under `lib/`
- Build command: `npm run build` (executes TypeScript compiler)
- Main entry: `lib/index.js`

## Build approach

1. Clone tag `v4.5.4` from upstream
2. Install dependencies with `npm install --ignore-scripts`
3. Run `npm run build` to compile TypeScript
4. Pack with `npm pack`

## Verification

- Tarball contains `package/lib/index.js` (compiled entry)
- Tarball contains `package/lib/index.d.ts` (type definitions)
- Package name and version match manifest
- Module can be required and exports expected API (`z.string()`, etc.)

## Could not verify

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag→commit only); tarball build provenance not verified

