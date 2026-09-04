#!/usr/bin/env bash
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
MAIN_TGZ="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"

path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

MAIN_PATH="$(path_under_out "${MAIN_TGZ}")"

echo "[verify.smoke] Checking main tarball: ${MAIN_PATH}"

# Verify tarball exists
if [[ ! -f "${MAIN_PATH}" ]]; then
    echo "[verify.smoke] Main tarball not found: ${MAIN_PATH}" >&2
    exit 1
fi

# Extract and verify critical members
tgz_has_member() {
    local member="$1"
    tar -xOf "${MAIN_PATH}" "${member}" >/dev/null 2>&1
}

# Check package.json
if ! tgz_has_member "package/package.json"; then
    echo "[verify.smoke] Missing package/package.json" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

# Verify package metadata
pkg_name="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .name)"
pkg_version="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .version)"

if [[ "${pkg_name}" != "uuid" ]]; then
    echo "[verify.smoke] Name mismatch: expected 'uuid', got '${pkg_name}'" >&2
    exit 1
fi

if [[ "${pkg_version}" != "${VERSION}" ]]; then
    echo "[verify.smoke] Version mismatch: expected ${VERSION}, got ${pkg_version}" >&2
    exit 1
fi

# Verify built distribution files (uuid builds to dist-node/)
if ! tgz_has_member "package/dist-node/index.js"; then
    echo "[verify.smoke] Missing package/dist-node/index.js" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

# Verify CLI bin
if ! tgz_has_member "package/dist-node/bin/uuid"; then
    echo "[verify.smoke] Missing package/dist-node/bin/uuid" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

# Syntax check on main entry
tar -xOf "${MAIN_PATH}" package/dist-node/index.js > /tmp/uuid-index.js
if ! node --check /tmp/uuid-index.js; then
    echo "[verify.smoke] Syntax error in package/dist-node/index.js" >&2
    exit 1
fi
rm /tmp/uuid-index.js

echo "[verify.smoke] All checks passed for uuid@${VERSION}"

Assisted-by: Claude
