#!/usr/bin/env bash
# Tier A smoke test: verify ws tarball structure and basic syntax.
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

[[ -f "${MAIN_PATH}" ]] || {
    echo "[verify.smoke] Main tarball not found: ${MAIN_PATH}" >&2
    exit 1
}

echo "[verify.smoke] Checking tarball structure"

# Assert required members exist
required_members=(
    "package/package.json"
    "package/index.js"
    "package/lib/websocket.js"
    "package/lib/receiver.js"
    "package/lib/sender.js"
)

for member in "${required_members[@]}"; do
    tar -xOf "${MAIN_PATH}" "${member}" >/dev/null 2>&1 || {
        echo "[verify.smoke] Missing required member: ${member}" >&2
        echo "Tarball listing:" >&2
        tar tf "${MAIN_PATH}" >&2 || true
        exit 1
    }
done

# Verify package.json metadata
EXTRACT_DIR="$(mktemp -d)"
trap "rm -rf ${EXTRACT_DIR}" EXIT

tar -xzf "${MAIN_PATH}" -C "${EXTRACT_DIR}"

pkg_name="$(jq -r .name "${EXTRACT_DIR}/package/package.json")"
pkg_version="$(jq -r .version "${EXTRACT_DIR}/package/package.json")"

[[ "${pkg_name}" == "ws" ]] || {
    echo "[verify.smoke] Wrong package name: ${pkg_name}" >&2
    exit 1
}

[[ "${pkg_version}" == "${VERSION}" ]] || {
    echo "[verify.smoke] Version mismatch: ${pkg_version} != ${VERSION}" >&2
    exit 1
}

# Syntax check main entry point
echo "[verify.smoke] Syntax check index.js"
node --check "${EXTRACT_DIR}/package/index.js"

# Syntax check lib files
echo "[verify.smoke] Syntax check lib/websocket.js"
node --check "${EXTRACT_DIR}/package/lib/websocket.js"

echo "[verify.smoke] ✓ All checks passed for ws@${VERSION}"
