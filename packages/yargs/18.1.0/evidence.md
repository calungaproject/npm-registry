# yargs@18.1.0 Recipe Evidence

## Package Classification

**Tier:** A (pure JavaScript with build step)

**Rationale:**
- No native code indicators (no binding.gyp, no .node files)
- No platform-specific optional dependencies
- Has a `prepare` lifecycle script that compiles TypeScript
- Similar to async@3.2.6 pattern (build then pack)

## Source Verification

- **Repository:** https://github.com/yargs/yargs.git
- **Tag:** v18.1.0
- **Commit SHA:** 8878a894111e3fe7c98d84af546c0f34fa017492
- **Package directory:** . (repo root)

Tag v18.1.0 is a lightweight tag that resolves to the commit above.

## Build Approach

1.
Clone the repository at tag v18.1.0
2.
Run `npm install --include=dev --ignore-scripts`
   - `--include=dev` required because npm-builder sets NODE_ENV=production
   - TypeScript and build tools are in devDependencies
   - `--ignore-scripts` prevents prepare from running during install
3.
Run `npm run compile` to build TypeScript sources
   - This is the prepare script that creates index.mjs and index.cjs
4.
Run `npm pack` to create the tarball

## Expected Outputs

Main tarball: `out/yargs-18.1.0.tgz`

Key files in tarball:
- `package/package.json`
- `package/index.mjs` (ESM entry point)
- `package/index.cjs` (CommonJS entry point)

## Smoke Test Strategy

1.
Verify tarball exists and contains required files
2.
Check package.json name and version match manifest
3.
Syntax check both index.mjs and index.cjs with `node --check`
4.
Test module loading with `require('yargs')`

## Factory Contract Compliance

- Uses trusted install command from facts.factory
- No factory blockers present
- Package directory is repo root (no monorepo complexity)
- Build runs in npm-builder image (has node, npm, git, jq, tar)

## Could Not Verify (from facts)

These gaps are carried forward from the fact bundle and do not affect recipe confidence:

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified
- Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

## Confidence Assessment

**Confidence:** 0.85 (high)

This is a straightforward Tier A package with a well-understood build pattern.
The recipe follows the async@3.2.6 canonical example for TypeScript packages.
No unusual dependencies, install scripts, or native components.
