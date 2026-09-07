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

echo "[verify.smoke] Verifying ${MAIN_PATH}"

if [[ ! -f "${MAIN_PATH}" ]]; then
    echo "[verify.smoke] ERROR: tarball not found at ${MAIN_PATH}" >&2
    exit 1
fi

echo "[verify.smoke] Checking tarball structure"
if ! tar -xOf "${MAIN_PATH}" package/package.json >/dev/null 2>&1; then
    echo "[verify.smoke] ERROR: package/package.json missing from tarball" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

if ! tar -xOf "${MAIN_PATH}" package/src/index.js >/dev/null 2>&1; then
    echo "[verify.smoke] ERROR: package/src/index.js missing from tarball" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

echo "[verify.smoke] Verifying package.json metadata"
pkg_json="$(tar -xOf "${MAIN_PATH}" package/package.json)"
packed_name="$(echo "${pkg_json}" | jq -r .name)"
packed_version="$(echo "${pkg_json}" | jq -r .version)"

if [[ "${packed_name}" != "node-fetch" ]]; then
    echo "[verify.smoke] ERROR: packed name '${packed_name}' != 'node-fetch'" >&2
    exit 1
fi

if [[ "${packed_version}" != "${VERSION}" ]]; then
    echo "[verify.smoke] ERROR: packed version '${packed_version}' != '${VERSION}'" >&2
    exit 1
fi

echo "[verify.smoke] Syntax checking main entry point"
extract_dir="$(mktemp -d)"
tar -xzf "${MAIN_PATH}" -C "${extract_dir}"
node --check "${extract_dir}/package/src/index.js" || {
    echo "[verify.smoke] ERROR: syntax check failed on src/index.js" >&2
    rm -rf "${extract_dir}"
    exit 1
}
rm -rf "${extract_dir}"

echo "[verify.smoke] All checks passed for node-fetch@${VERSION}"
