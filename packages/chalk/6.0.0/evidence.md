# Recipe Evidence: chalk@6.0.0

## Package Identity

- **Name:** chalk
- **Version:** 6.0.0
- **Upstream:** https://github.com/chalk/chalk.git
- **Source Ref:** v6.0.0 (annotated tag)
- **Commit:** 661317e6f91fe7c90306c2c48ea9354562ee9146

## Tier Classification: A

**Rationale:** Pure JavaScript package with no native code, no build step, and no platform-specific dependencies.

**Evidence from facts:**
- `has_native_indicators: false`
- `has_platform_optional_deps: false`
- `has_build_step: false`
- `has_lifecycle_scripts: false`
- No `binding.gyp` or native addons
- No platform-specific optionalDependencies

The package was classified as `tier_a_eligible: false` with reason code `COMPLEX_EXPORTS` due to conditional exports in package.json, but this does not affect the tier classification—it's still pure JS (Tier A).

## Build Strategy

**Pack-only** (no build step required):
1. Clone repository at tag v6.0.0
2. Run `npm pack --quiet --ignore-scripts` directly from checkout
3. Move packed tarball to output directory

No `npm install` or build step is required because:
- `facts.upstream.has_build_step: false`
- `facts.upstream.has_lifecycle_scripts: false`
- Package sources are already in distributable form in the git tag

## Repository Structure

- Package directory: `.` (root of repository)
- Main entry point: `source/index.js` (per chalk repository structure)
- Package type: ESM (type: "module" in package.json)

## Files Inspected

- Repository: https://github.com/chalk/chalk (read-only; network blocked in sandbox)
- Facts bundle: `/sandbox/workspace/recipe-input.json`
- Examples: `semver@7.7.2` (similar Tier A pack-only pattern)

## Verification Plan

The smoke test verifies:
1. Tarball exists at expected output path
2. Required members present: `package/package.json`, `package/source/index.js`
3. Package name and version match manifest
4. Package is installable (npm install test)
5. ESM module structure is intact

## Could Not Verify

Carried verbatim from facts.could_not_verify:
- "npm provenance attestation present but not cryptographically verified"
- "Source association is tag_only (tag->commit only); tarball build provenance not verified"

These are acceptable limitations for the current recipe phase.

## Confidence: 0.90

High confidence because:
- Clear Tier A classification (no native code)
- No factory blockers
- Straightforward pack-only build strategy
- Tag matches version exactly
- Similar to canonical examples (lodash, semver)

Minor uncertainty due to:
- ESM-only package (newer pattern than CommonJS examples)
- Complex exports structure (though this doesn't affect tier)

Assisted-by: Claude Sonnet 4.5 <noreply@anthropic.com>
