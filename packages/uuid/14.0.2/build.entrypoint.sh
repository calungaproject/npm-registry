#!/usr/bin/env bash
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"
: "${WORK_DIR:?WORK_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
SOURCE_URL="$(jq -r .source.url "${MANIFEST_PATH}")"
SOURCE_REF="$(jq -r .source.ref "${MANIFEST_PATH}")"
MAIN_TGZ_REL="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"

path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

main_tgz="$(path_under_out "${MAIN_TGZ_REL}")"

assert_tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1 || {
        echo "[build.entrypoint] ${tgz} missing ${member}" >&2
        tar tf "${tgz}" >&2 || true
        exit 1
    }
}

# Clone source at the pinned ref
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${WORK_DIR}/src"
cd "${WORK_DIR}/src"

# Install dependencies (including dev for build tools)
npm install --include=dev --ignore-scripts

# Run the build (transpile TypeScript to dist-node/)
npm run build

# Pack the built package
packed_tgz="$(npm pack --quiet)"

# Move to output directory
mv "${packed_tgz}" "${main_tgz}"

# Verify critical files exist in the tarball
assert_tgz_has_member "${main_tgz}" "package/package.json"
assert_tgz_has_member "${main_tgz}" "package/dist-node/index.js"
assert_tgz_has_member "${main_tgz}" "package/dist-node/bin/uuid"

# Verify packed version matches manifest
packed_version="$(tar -xOf "${main_tgz}" package/package.json | jq -r .version)"
if [[ "${packed_version}" != "${VERSION}" ]]; then
    echo "[build.entrypoint] Version mismatch: expected ${VERSION}, got ${packed_version}" >&2
    exit 1
fi

echo "[build.entrypoint] Successfully built uuid@${VERSION}"
echo "[build.entrypoint] Output: ${main_tgz}"

Assisted-by: Claude
