# Evidence for node-fetch@3.3.2

## Source resolution

- **Repository**: https://github.com/node-fetch/node-fetch.git
- **Tag**: v3.3.2 (lightweight)
- **Commit**: 8b3320d2a7c07bce4afc6b2bf6c3bbddda85b01f
- **Package directory**: `.` (repo root)

## Tier classification: A

**Rationale**: Pure ESM JavaScript package with no native dependencies, no build step required, and no platform-specific binaries.

From facts analysis:
- `has_native_indicators`: false
- `has_build_step`: false
- `has_platform_optional_deps`: false
- `runtime`: ESM
- `main_entry`: src/index.js

## Version mismatch issue

The upstream repository has a known issue where the package.json in the v3.3.2 tag contains version "3.1.1" instead of "3.3.2".
This is documented in the facts as:
```
PACK_NAME_VERSION_MISMATCH: packed node-fetch@3.1.1 != expected node-fetch@3.3.2
```

### Solution implemented

The build entrypoint patches the package.json version field before packing:
```bash
jq --arg version "${VERSION}" '.version = $version' package.json > package.json.tmp
mv package.json.tmp package.json
```

This approach:
- Preserves all other package.json metadata
- Ensures the packed tarball has the correct version
- Matches the npm registry version (3.3.2)

## Build approach

**Strategy**: Pack-only with version patch

1. Clone repository at tag v3.3.2
2. Patch package.json version field
3. Pack with `npm pack`
4. Verify tarball structure and version

No build step or dependency installation required - the source tree is ready to pack.

## Verification gaps

From facts.could_not_verify:
- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified

## Files inspected

- package.json (version field requires patching)
- src/index.js (main entry point, ESM)

Assisted-by: Claude
