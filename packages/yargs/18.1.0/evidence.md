# Recipe evidence: yargs@18.1.0

## Source

- Repository: https://github.com/yargs/yargs.git
- Tag: v18.1.0 (lightweight tag)
- Commit: 8878a894111e3fe7c98d84af546c0f34fa017492
- Package directory: `.` (repo root)

## Tier classification: A

- **No native compilation**: `has_native_indicators: false`, no `binding.gyp`, no `.node` files
- **No platform optionals**: `has_platform_optional_deps: false`
- **Has build step**: `has_build_step: true` with `prepare` lifecycle script
- **Build type**: TypeScript/ESM transpilation (pure JS output)
- **Conclusion**: Tier A (build step is JS-only transpilation, not native compilation)

## Build strategy

1. Clone at tag `v18.1.0`
2. Install dependencies: `npm install --include=dev --ignore-scripts`
   - Factory contract specifies this install command when `has_build_step: true`
   - `--include=dev` required because `NODE_ENV=production` in npm-builder omits devDependencies
   - TypeScript and build tools are typically devDependencies
3. Run build: `npm run prepare`
   - Upstream lifecycle script that compiles TypeScript to ESM
4. Pack: `npm pack --quiet`
   - Standard npm pack of the built sources

## Key files inspected

- `package.json`: main entry, scripts, dependencies
- Facts indicate main entry status: `complex_exports` (ESM with exports field)
- Based on facts and Tier A classification, main entry is likely `index.mjs`

## Factory contract compliance

- Uses `facts.factory.install_command` verbatim
- No blockers (`facts.factory.blockers: []`)
- Package dir is `.` (root checkout sufficient)

## Smoke test strategy

- Verify tarball contains `package/package.json` and `package/index.mjs`
- Extract packed name and version match manifest
- Install tarball and test `require('yargs')` returns function
- No CLI test needed (`has_cli: false` in facts)

## Could not verify (from facts)

Carried forward from trusted facts bundle:
- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified
- Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

Assisted-by: Claude
