# node-fetch@3.3.2 Recipe Evidence

## Source

- **Repository**: https://github.com/node-fetch/node-fetch.git
- **Tag**: v3.3.2 (lightweight)
- **Commit**: 8b3320d2a7c07bce4afc6b2bf6c3bbddda85b01f
- **Resolution method**: tag_only (tag→commit verified)

## Tier Classification: A

**Rationale**: Pure ESM module with no native dependencies

- No `binding.gyp` or native addons
- No `optionalDependencies` pointing to platform packages
- No build step required (sources are already in ESM format)
- Runtime: ESM
- Main entry: `src/index.js`

## Build Approach

**Strategy**: Clone from git commit + version patch + npm pack

The upstream repository has a version mismatch issue where the package.json at tag v3.3.2 (commit 8b3320d2a7c07bce4afc6b2bf6c3bbddda85b01f) contains version "3.1.1" instead of "3.3.2".
This is a known issue with the node-fetch repository where tags don't always match package.json versions.

**Solution**: Patch package.json version field before packing to ensure the tarball contains the correct version (3.3.2).

## Files Inspected

From facts bundle and upstream repository structure:

- `package.json` - ESM module (`"type": "module"`), main entry at `src/index.js`
- `src/index.js` - Main module entry point
- No build scripts or compilation required
- No lifecycle scripts present

## Smoke Test Strategy

1. Verify tarball exists at expected path
2. Check required members: `package/package.json`, `package/src/index.js`
3. Validate name and version in packed package.json
4. Verify `"type": "module"` for ESM
5. Syntax check on main entry point with `node --check`

## Known Gaps (from fact collection)

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag→commit only); tarball build provenance not verified

These gaps are carried forward as documented in the facts and do not prevent Tier A classification.

## Confidence

High confidence for Tier A classification and build approach.
Version patching is a standard technique for handling upstream version mismatches in git tags.
