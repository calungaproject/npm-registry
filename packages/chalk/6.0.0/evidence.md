# Recipe evidence: chalk@6.0.0

## Source verification

- **Repository**: https://github.com/chalk/chalk.git
- **Tag**: v6.0.0 (annotated)
- **Commit**: 661317e6f91fe7c90306c2c48ea9354562ee9146
- **Package directory**: `.` (repo root)
- **Tarball integrity**: sha512-2uNTXIuTTxk7ciZgAU1BQcgnchcG0xXnrs6jzkQfj9SsRa9M2s5zE8WT96hS6KmG4MzWHSrvH43DF1m4XRkrFg==

## Tier classification: A

**Rationale**: chalk@6.0.0 is a pure JavaScript package with no native dependencies or build requirements.

**Upstream signals inspected**:
- `has_build_step`: false
- `has_lifecycle_scripts`: false
- `has_native_indicators`: false
- `has_platform_optional_deps`: false
- No `binding.gyp` or native addon files
- No platform-specific optional dependencies

**Classification reason code**: COMPLEX_EXPORTS - "complex or conditional root exports; entrypoint is not unambiguous"

Note: The COMPLEX_EXPORTS flag indicates chalk uses conditional exports in package.json, but this does not affect the tier classification.
Tier A is still correct because there are no native binaries or build steps required.

## Build strategy

**Pattern**: Pack-only (Tier A minimal)

**Steps**:
1. Clone repository at tag v6.0.0
2. Run `npm pack` from repo root
3. Move tarball to output directory
4. Verify tarball structure and version

**No build step needed**: chalk ships pre-written JavaScript source code.
The package uses ESM with conditional exports but does not require compilation or transpilation.

## Factory constraints

- **Blockers**: none
- **Install command**: not needed (pack-only)
- **Node environment**: NODE_ENV=production (default, no impact for pack-only)

## Verification strategy

**Smoke test assertions**:
1. Tarball exists at expected path
2. `package/package.json` present with correct name and version
3. `package/source/index.js` (main entry point) exists
4. Main entry is syntactically valid JavaScript (`node --check`)

## Could not verify

Per trusted facts bundle:
- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag→commit only); tarball build provenance not verified

These gaps are documented in the result JSON and carried forward from the facts bundle.

Assisted-by: Claude
