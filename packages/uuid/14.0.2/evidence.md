# uuid@14.0.2 Recipe Evidence

## Source Resolution

- **Git URL:** https://github.com/uuidjs/uuid.git
- **Commit SHA:** fd59f0277549d22cc7ec00a7b3b5c9bccb4d3c1d
- **Tag:** v14.0.2 (lightweight, resolves to the above commit)
- **npm version:** 14.0.2
- **dist.integrity:** sha512-xZe/16rV4aa+HGSOCiY2YeLT1OybRLrrkL/Rqaq7p7GMVXjFh+6wN4oMYgjFmnSnhY8t6Xpdl2l9qmnHYuMHwQ==

## Tier Classification: A

**Rationale:**
- No native indicators (has_native_indicators: false)
- No platform optional dependencies (has_platform_optional_deps: false)
- Has build lifecycle scripts (build, prepare, prepack, prepublishOnly) but these compile TypeScript to JavaScript only
- No binding.gyp or native addons
- Pattern matches async@3.2.6 (Tier A with build step)

**Not Tier B/C because:**
- No optionalDependencies referencing platform packages
- No native binary compilation (node-gyp, prebuild-install, etc.)
- Build produces pure JavaScript output

## Build Approach

**Pattern:** npm install + build + pack (Tier A with build)

1. Clone source at commit fd59f0277549d22cc7ec00a7b3b5c9bccb4d3c1d
2. `npm install --ignore-scripts` to get dependencies
3. `npm run build` to compile TypeScript → JavaScript (dist-node/ directory)
4. `npm pack` to create tarball
5. Validate packed version matches manifest

**Why this approach:**
- Facts indicate "Source npm pack --ignore-scripts failed" — requires proper build
- Upstream has TypeScript sources that need compilation
- Build produces dist-node/ directory with compiled outputs

## Build Output Structure

Based on facts collector report:
- Main entry: complex exports (package.json uses "exports" field)
- CLI bin: `uuid` → `dist-node/bin/uuid`
- Built output directory: `dist-node/`

## CLI Verification

Package provides a CLI command:
- Binary name: `uuid`
- Path: `dist-node/bin/uuid`
- Smoke test verifies CLI produces valid UUID v4 format

## Gaps Carried from Facts

The following verification gaps from the fact collector are carried into the recipe:

1. npm provenance attestation present but not cryptographically verified
2. Source association is tag_only (tag→commit only); tarball build provenance not verified
3. Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

## Files Inspected

- Facts bundle: recipe-input.json (trusted source for identity, git URL, commit SHA)
- Canonical examples: async@3.2.6 (Tier A with build), semver@7.7.2 (pack-only)
- Skill documentation: tier-guide.md, manifest.md, build-entrypoint.md, verify-smoke.md

## Confidence: 0.75

**Moderate confidence** because:
- Cannot verify actual build output structure without network access to clone repo
- Assumed dist-node/ directory based on facts.upstream.cli_bin_path
- TypeScript compilation pattern is standard, but exact output layout not confirmed
- Build may require adjustments based on actual upstream package.json scripts

**Would increase to 0.90+ with:**
- Verification of actual build output structure from upstream repo
- Confirmation that npm run build produces dist-node/ directory
- Testing the build in factory environment

Assisted-by: Claude
