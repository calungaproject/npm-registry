# uuid@14.0.2 recipe evidence

## Source identification

- **Repository:** https://github.com/uuidjs/uuid.git
- **Tag:** v14.0.2 (lightweight tag)
- **Commit:** fd59f0277549d22cc7ec00a7b3b5c9bccb4d3c1d
- **Tag resolution:** verified via facts collector

## Tier classification: A

**Rationale:**

- No native code (no `binding.gyp`, no `.node` files)
- No platform-specific optional dependencies
- Build scripts are for TypeScript compilation only (build, prepare, prepack, prepublishOnly)
- Produces pure JavaScript artifacts in `dist-node/` directory
- Has CLI bin (`uuid` → `dist-node/bin/uuid`)

Despite having build lifecycle scripts, this is **Tier A** because the build step only transpiles TypeScript to JavaScript and does not involve native compilation or platform-specific binaries.

## Build approach

**Pattern:** Build then pack (TypeScript compilation)

1. Clone repository at tag `v14.0.2`
2. Run `npm install --ignore-scripts` to install build dependencies
3. Run `npm run build` to compile TypeScript sources to `dist-node/`
4. Run `npm pack` to create distributable tarball
5. Verify presence of `dist-node/index.js` and `dist-node/bin/uuid`

## Files inspected

- Upstream `package.json`: contains `"type": "module"`, build scripts, exports configuration
- Build output directory: `dist-node/` (for Node.js CommonJS/ESM builds)
- CLI binary: `dist-node/bin/uuid`

## Verification gaps carried forward

From facts collector:

- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag→commit only); tarball build provenance not verified
- Source npm pack --ignore-scripts failed; packed layout taken from the integrity-verified registry tarball

## Confidence

High confidence (0.9) — standard TypeScript build pattern with clear build outputs and no native dependencies.

Assisted-by: Claude
