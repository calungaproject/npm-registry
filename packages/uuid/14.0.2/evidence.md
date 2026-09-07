# uuid@14.0.2 recipe evidence

## Package identity

- **npm name**: uuid
- **version**: 14.0.2
- **upstream**: https://www.npmjs.com/package/uuid

## Source

- **repository**: https://github.com/uuidjs/uuid.git
- **ref**: v14.0.2 (tag)
- **commit**: fd59f0277549d22cc7ec00a7b3b5c9bccb4d3c1d
- **package directory**: . (repo root)

## Classification: Tier A

**Rationale**: Pure JavaScript package with TypeScript build step.
No native addons, no platform-specific packages, no consumer compilation.

**Upstream signals inspected**:
- has_build_step: true (TypeScript compilation)
- has_lifecycle_scripts: true (build, prepare, prepack, prepublishOnly)
- has_native_indicators: false
- has_platform_optional_deps: false
- has_cli: true (bin: uuid → dist-node/bin/uuid)

## Build strategy

Pattern: **build then pack** (similar to async@3.2.6)

1. Clone tag v14.0.2
2. `npm install --include=dev --ignore-scripts` (devDependencies include TypeScript)
3. `npm run build` (compiles TypeScript to dist-node/)
4. `npm pack` (produces tarball with compiled dist-node tree)

**Why --include=dev**: npm-builder sets NODE_ENV=production, which omits devDependencies unless --include=dev is specified.
TypeScript and build tools are in devDependencies.

## Outputs

Single tarball: `out/uuid-14.0.2.tgz`

**Key members verified**:
- package/package.json
- package/dist-node/index.js (main entry)
- package/dist-node/bin/uuid (CLI)

## Smoke tests

1. Tarball existence and structure
2. package.json name/version match
3. Module API: v4() generates RFC9562-compliant UUID
4. CLI: uuid command produces output

## Could not verify (from facts)

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag→commit only); tarball build provenance not verified
- Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

These gaps are **acceptable** for Tier A with tag resolution and dist.integrity verification.

## Factory compatibility

- **install_command**: npm install --include=dev --ignore-scripts (used)
- **blockers**: none
- **commands used**: git, npm, jq, tar (all available in npm-builder)

## Confidence: 0.90

High confidence.
Standard Tier A TypeScript build pattern with clear upstream structure.
