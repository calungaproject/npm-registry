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

echo "[verify.smoke] Smoke testing chalk@${VERSION}"

# Verify tarball exists
if [[ ! -f "${MAIN_PATH}" ]]; then
    echo "[verify.smoke] Main tarball not found: ${MAIN_PATH}" >&2
    exit 1
fi

# Helper to check tarball member
tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1
}

# Verify package.json exists
if ! tgz_has_member "${MAIN_PATH}" "package/package.json"; then
    echo "[verify.smoke] package/package.json missing from tarball" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

# Verify main entry point exists (chalk uses source/index.js)
if ! tgz_has_member "${MAIN_PATH}" "package/source/index.js"; then
    echo "[verify.smoke] package/source/index.js missing from tarball" >&2
    tar tf "${MAIN_PATH}" >&2 || true
    exit 1
fi

# Extract and verify package metadata
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

tar -xzf "${MAIN_PATH}" -C "${tmpdir}"

pkg_name="$(jq -r .name "${tmpdir}/package/package.json")"
pkg_version="$(jq -r .version "${tmpdir}/package/package.json")"

if [[ "${pkg_name}" != "chalk" ]]; then
    echo "[verify.smoke] Expected name 'chalk', got '${pkg_name}'" >&2
    exit 1
fi

if [[ "${pkg_version}" != "${VERSION}" ]]; then
    echo "[verify.smoke] Expected version '${VERSION}', got '${pkg_version}'" >&2
    exit 1
fi

# Verify main entry is syntactically valid JavaScript
node --check "${tmpdir}/package/source/index.js"

echo "[verify.smoke] All checks passed for chalk@${VERSION}"
