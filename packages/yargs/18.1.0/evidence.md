# Recipe evidence: yargs@18.1.0

## Source verification

- **Repository:** https://github.com/yargs/yargs.git
- **Tag:** v18.1.0 (lightweight tag)
- **Commit:** 8878a894111e3fe7c98d84af546c0f34fa017492
- **Registry version:** 18.1.0
- **Registry integrity:** sha512-2rAgRKu54VsHkqI0/tYkmluGXHD4KW7yZoycuqDQ15QOTnc2VVfy0nN/1eMhnQLO00A+dwtK20xuCnc1YGeUyg==

## Tier classification: A

yargs@18.1.0 is classified as **Tier A** because:

1. **No native code indicators:** The package does not contain `binding.gyp`, `.node` files, or node-gyp compilation
2. **No platform-specific optional dependencies:** The package does not use `optionalDependencies` for platform binaries
3. **Pure JavaScript with build step:** The package has a `prepare` lifecycle script that runs build tooling, but produces only JavaScript output
4. **Single package output:** Only one npm tarball is needed (no separate platform packages)

## Build approach

Based on inspection of the facts bundle:

- The package has `has_build_step: true` and `has_lifecycle_scripts: true`
- The upstream package uses a `prepare` script for build orchestration
- No native compilation is involved (verified by `has_native_indicators: false`)

Build pattern selected: **Tier A with build step** (similar to async@3.2.6)

Steps:
1. Clone repository at tag v18.1.0
2. Verify commit SHA matches expected value
3. Run `npm install --ignore-scripts` to install build dependencies
4. Pack the module with `npm pack --ignore-scripts`
5. Verify tarball contents and version

## Files inspected

From the facts bundle:
- `package.json` fields: `main_entry_status: "complex_exports"` indicates modern exports
- Primary entry point appears to be `index.mjs` based on common yargs patterns
- No CLI binary indicators in the facts (`has_cli: false`)

## Smoke test strategy

Verify:
1. Tarball exists at expected path
2. Core files present: `package/package.json`, `package/index.mjs`
3. Package metadata matches manifest (name, version)
4. Module can be required/imported successfully
5. Basic API validation (yargs constructor)

## Could not verify (from facts)

The following items from the facts bundle could not be fully verified during collection:

1. npm provenance attestation present but not cryptographically verified
2. Source association is tag_only (tag->commit only); tarball build provenance not verified
3. Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

These are documented as known gaps but do not prevent recipe drafting, as:
- The git tag and commit SHA provide reproducible source pinning
- The registry tarball integrity hash is verified
- The factory build will produce the tarball from git source directly

Assisted-by: Claude
