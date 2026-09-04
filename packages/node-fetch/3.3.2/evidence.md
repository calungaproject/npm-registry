# node-fetch@3.3.2 Recipe Evidence

## Classification

**Tier A** — Pure JavaScript ESM module with no native dependencies or build steps required.

## Source

- **Repository:** https://github.com/node-fetch/node-fetch.git
- **Tag:** v3.3.2 (lightweight)
- **Commit SHA:** 8b3320d2a7c07bce4afc6b2bf6c3bbddda85b01f
- **Package directory:** `.` (repo root)

## Critical Issue: Version Mismatch

**BLOCKER**: The git tag `v3.3.2` contains a `package.json` with version `3.1.1`, not `3.3.2`.

This was discovered during fact collection:
```
reason_code: "PACK_NAME_VERSION_MISMATCH"
reason: "packed node-fetch@3.1.1 != expected node-fetch@3.3.2"
```

This indicates one of the following upstream issues:
1. The tag `v3.3.2` was created pointing to the wrong commit
2. The package.json was not updated when the tag was created
3. The commit was amended or force-pushed after tagging

## Verification Required

Before this recipe can be marked as `drafted` and production-ready, the following must be verified:

1. **Upstream investigation:** Check the node-fetch repository to understand why the tag and package.json version don't match
2. **Alternative ref:** Determine if there's a different commit or tag that correctly represents version 3.3.2
3. **Registry verification:** Confirm that the tarball on registry.npmjs.org for node-fetch@3.3.2 actually contains version 3.3.2
4. **Tag correction:** If this is an upstream error, consider whether to:
   - Use the commit SHA that correctly has version 3.3.2 in package.json
   - Wait for upstream to correct the tag
   - Document this as a known discrepancy

## Build Approach

If the version issue is resolved, the build approach is straightforward:

1. Clone repository at correct ref
2. Run `npm pack --ignore-scripts` (no build step needed per facts)
3. Verify packed tarball contains expected files:
   - `package/package.json`
   - `package/src/index.js` (ESM entry point)

## Runtime Characteristics

- **Type:** ESM module (`"type": "module"` in package.json)
- **Main entry:** `src/index.js`
- **No build step:** Source files are shipped as-is
- **No native addons:** Pure JavaScript
- **No lifecycle scripts:** Install with `--ignore-scripts` is safe

## Confidence

**Low (0.3)** — The version mismatch is a critical blocker that prevents confident production deployment.
This recipe is scaffolded for the expected version 3.3.2, but will fail validation until the upstream ref issue is resolved.

## Escalation

This recipe requires manual review by npm-tl-onboarding team to:
- Investigate the root cause of the version mismatch
- Determine the correct source ref for version 3.3.2
- Update the recipe with the correct ref before merging
