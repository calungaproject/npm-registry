# ws@8.21.3 Recipe Evidence

## Source

- **Repository:** https://github.com/websockets/ws.git
- **Tag:** `8.21.3` (lightweight)
- **Commit SHA:** `c791e707eab3c13dd9a261d2479c3cc4a49a6fed`
- **Tag matches version:** Yes

## Tier Classification: A

**Rationale:** Pure JavaScript WebSocket implementation with no native dependencies.

**Supporting evidence:**
- No `binding.gyp` or native build indicators
- No platform-specific `optionalDependencies`
- No build step required (`has_build_step: false`)
- No lifecycle scripts that compile native code (`has_lifecycle_scripts: false`)
- Published tarball contains only JavaScript sources

**Classification note from facts:**
- Marked as `tier_a_eligible: false` due to `COMPLEX_EXPORTS` (complex or conditional root exports)
- However, this is still Tier A because it has no native components
- The complex exports structure doesn't change the tier; it only affects entrypoint analysis

## Build Strategy

**Pattern:** Pack-only (Tier A minimal)

1. Clone at tag `8.21.3`
2. Verify commit SHA matches expected `c791e707...`
3. Run `npm pack --ignore-scripts` from repository root
4. No build step needed - sources are already in distributable form

## Key Files Verified

- `package/index.js` - Main entry point
- `package/lib/websocket.js` - Core WebSocket implementation
- `package/lib/receiver.js` - WebSocket receiver
- `package/lib/sender.js` - WebSocket sender

## Verification from Facts

- **Tarball integrity:** `sha512-201TZ/kPWxoPr/OKWjquZR1SWKXcvxdH+e1xrx89b3YbmzLMFCLfnaG1HFIgWzJOEWZ7MvpK++odZufgYR50Rw==`
- **Source tarball SHA256:** `65ae12b5c0e0a73d7b7df1655e0dc7316860e6467cf8cd355b9309f96ea93f33`
- **Upstream npm version:** `8.21.3`

## Could Not Verify

Per facts bundle:
- npm provenance attestation present but not cryptographically verified
- Source association is tag_only (tag->commit only); tarball build provenance not verified
