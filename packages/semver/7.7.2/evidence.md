# Evidence: semver@7.7.2

## Source verification

- **Repository:** https://github.com/npm/node-semver.git
- **Ref:** 281055e7716ef0415a8826972471331989ede58c (commit SHA from tag v7.7.2)
- **Tag:** v7.7.2 (lightweight tag)
- **Resolution:** tag_only (tag resolves to commit)

## Tier classification: A

**Rationale:** Pure JavaScript package with no native dependencies, no build step required beyond npm pack, and no platform-specific optional dependencies.

**Evidence from facts:**

- `has_build_step: false`
- `has_native_indicators: false`
- `has_platform_optional_deps: false`
- `runtime: CommonJS`
- `main_entry: index.js` (status: ok)
- `has_cli: true` (bin/semver.js)

## Files inspected

- `package.json` at commit 281055e7716ef0415a8826972471331989ede58c
- `index.js` (main entry point)
- `bin/semver.js` (CLI entry point)

## Build approach

**Strategy:** pack-only (Tier A minimal)

1. Clone repository at specified commit SHA
2. Verify commit SHA matches expected value
3. Run `npm pack --ignore-scripts` from repository root
4. Verify packed tarball contains required members:
   - `package/package.json`
   - `package/index.js`
   - `package/bin/semver.js`
5. Verify packed version matches manifest version

No build step required — the repository is already in publishable state at the tag.

## Smoke test approach

1. Verify tarball exists and contains all required members
2. Verify package name and version in packed package.json
3. Install tarball locally and test module API (require and basic function call)
4. Test CLI functionality

## Could not verify (from facts)

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified

## Confidence

High confidence (0.95) — straightforward Tier A package with clear structure, verified by facts collector, matches canonical lodash pattern.

Assisted-by: Claude
