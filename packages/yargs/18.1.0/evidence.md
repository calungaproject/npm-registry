# yargs@18.1.0 Recipe Evidence

## Package Identity

- **Package:** `yargs@18.1.0`
- **Upstream:** https://github.com/yargs/yargs
- **Source ref:** `v18.1.0` (tag)
- **Commit SHA:** `8878a894111e3fe7c98d84af546c0f34fa017492`
- **Registry integrity:** `sha512-2rAgRKu54VsHkqI0/tYkmluGXHD4KW7yZoycuqDQ15QOTnc2VVfy0nN/1eMhnQLO00A+dwtK20xuCnc1YGeUyg==`

## Classification: Tier A

### Rationale

yargs is a **pure JavaScript** command-line argument parser library with the following characteristics:

- No native dependencies or platform-specific code
- No `binding.gyp` or compiled native addons
- No `optionalDependencies` for platform packages
- Has a build step (`prepare` script) that compiles TypeScript to JavaScript
- Build produces CommonJS and ESM outputs in `build/` directory

### Build indicators from facts

- `has_build_step`: true (prepare script runs TypeScript compiler)
- `has_native_indicators`: false
- `has_platform_optional_deps`: false
- `has_lifecycle_scripts`: true (prepare script only)

## Build Strategy

Following the **Tier A with build step** pattern (similar to `async@3.2.6`):

1. Clone repository at tag `v18.1.0`
2. Verify commit SHA matches expected `8878a894111e3fe7c98d84af546c0f34fa017492`
3. Install dependencies with `npm install --include=dev --ignore-scripts`
   - `--include=dev` required because npm-builder sets `NODE_ENV=production`
   - TypeScript and build tools are in devDependencies
4. Run build: `npm run compile` (prepares TypeScript → JavaScript output)
5. Pack: `npm pack --ignore-scripts`
6. Move packed tarball to output directory

## Files Inspected

Based on upstream repository structure and npm registry tarball:

- `package.json` - defines build scripts and package metadata
- `index.mjs` - ESM entry point
- `build/index.cjs` - CommonJS entry built from TypeScript sources
- TypeScript sources compiled during build step

## Smoke Test Strategy

Verify:
1. Tarball exists at expected path
2. Required package structure members present:
   - `package/package.json`
   - `package/index.mjs` (ESM entry)
   - `package/build/index.cjs` (built CommonJS output)
3. Package name and version match manifest
4. Module can be imported and basic API works (parse command-line arguments)

## Commands Used (npm-builder allowlist)

All commands are available in the npm-builder factory image:

- `git` - clone repository
- `npm` - install, build, pack
- `jq` - parse manifest JSON
- `tar` - inspect tarball contents
- `node` - smoke test module API
- `mkdir`, `rm`, `mv`, `chmod` - file operations

## Could Not Verify (from facts)

Carrying forward from trusted facts:

1. npm provenance attestation present but not cryptographically verified
2. Source association is tag_only (tag->commit only); tarball build provenance not verified
3. Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

These are informational gaps, not blockers for Tier A classification.

## Confidence: 0.9

High confidence in this recipe because:

- Clear Tier A classification (no native code, pure JS/TS build)
- Standard TypeScript build pattern well-supported in npm-builder
- No factory blockers
- Build commands are well-documented in upstream package.json
- Similar to canonical `async@3.2.6` example
