# chalk@6.0.0 Recipe Evidence

## Source verification

- **Repository:** https://github.com/chalk/chalk.git
- **Ref:** v6.0.0 (annotated tag)
- **Commit SHA:** 661317e6f91fe7c90306c2c48ea9354562ee9146
- **Package directory:** . (repository root)

## Tier classification: A

**Rationale:** chalk is a pure JavaScript package with no native dependencies, no platform-specific optionalDependencies, and no build steps required.

**Facts inspection:**
- `has_native_indicators`: false
- `has_platform_optional_deps`: false
- `has_build_step`: false
- `has_lifecycle_scripts`: false
- No `binding.gyp` or native addons

## Build strategy

**Pack-only recipe:**
1. Clone repository at tag v6.0.0
2. Verify commit SHA matches expected value
3. Run `npm pack --ignore-scripts` to create tarball
4. Verify tarball contains expected members

**No build step required:** chalk ships pre-built JavaScript source in the repository.
The package uses ESM exports with complex conditional patterns, but this does not require a build step.

## Files inspected

- `package.json`: Verified exports, no build scripts, no native dependencies
- `source/index.js`: Main entry point for ESM module

## Smoke test strategy

1. Verify tarball exists and contains required files
2. Extract and verify package.json name and version
3. Install package locally and test basic import functionality
4. Verify chalk can style text (basic API test)

## Could not verify

As noted in the trusted facts bundle:
- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified

These gaps are carried forward from the fact collection phase and do not block recipe drafting.
