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

tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1
}

dump_tgz_listing() {
    local tgz="$1"
    echo "Tarball listing (${tgz}):" >&2
    tar tf "${tgz}" >&2 || true
}

# Verify main tarball exists
if [[ ! -f "${MAIN_PATH}" ]]; then
    echo "[verify.smoke] Main tarball not found: ${MAIN_PATH}" >&2
    exit 1
fi

# Verify required members exist
for member in "package/package.json" "package/dist-node/index.js" "package/dist-node/bin/uuid"; do
    if ! tgz_has_member "${MAIN_PATH}" "${member}"; then
        echo "[verify.smoke] Missing required member: ${member}" >&2
        dump_tgz_listing "${MAIN_PATH}"
        exit 1
    fi
done

# Extract and verify package.json identity
temp_extract="$(mktemp -d)"
trap "rm -rf ${temp_extract}" EXIT

tar -xzf "${MAIN_PATH}" -C "${temp_extract}"

pkg_name="$(jq -r .name "${temp_extract}/package/package.json")"
pkg_version="$(jq -r .version "${temp_extract}/package/package.json")"

if [[ "${pkg_name}" != "uuid" ]]; then
    echo "[verify.smoke] Package name mismatch: expected uuid, got ${pkg_name}" >&2
    exit 1
fi

if [[ "${pkg_version}" != "${VERSION}" ]]; then
    echo "[verify.smoke] Version mismatch: expected ${VERSION}, got ${pkg_version}" >&2
    exit 1
fi

# Verify main entry file is valid JavaScript
node --check "${temp_extract}/package/dist-node/index.js" || {
    echo "[verify.smoke] Main entry file failed syntax check" >&2
    exit 1
}

# Verify CLI bin is valid JavaScript
node --check "${temp_extract}/package/dist-node/bin/uuid" || {
    echo "[verify.smoke] CLI bin failed syntax check" >&2
    exit 1
}

# Verify the CLI bin is executable in the package.json
bin_path="$(jq -r '.bin.uuid // .bin' "${temp_extract}/package/package.json")"
if [[ "${bin_path}" != "dist-node/bin/uuid" ]]; then
    echo "[verify.smoke] CLI bin path mismatch: expected dist-node/bin/uuid, got ${bin_path}" >&2
    exit 1
fi

echo "[verify.smoke] All checks passed for uuid@${VERSION}"

Assisted-by: Claude
