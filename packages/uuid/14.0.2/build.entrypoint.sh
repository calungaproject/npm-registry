#!/usr/bin/env bash
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"
: "${WORK_DIR:?WORK_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
SOURCE_URL="$(jq -r .source.url "${MANIFEST_PATH}")"
SOURCE_REF="$(jq -r .source.ref "${MANIFEST_PATH}")"
MAIN_TGZ_REL="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
main_tgz="${OUT_DIR}/${MAIN_TGZ_REL#out/}"

assert_tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1 || {
        echo "[build.entrypoint] ${tgz} missing ${member}" >&2
        tar tf "${tgz}" >&2 || true
        exit 1
    }
}

# Clone source at tag
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${WORK_DIR}/src"
cd "${WORK_DIR}/src"

# Install dependencies and run build (uuid has prepare/build scripts for TypeScript compilation)
npm install --ignore-scripts
npm run build

# Pack the built package
npm pack --quiet

# Move tarball to output
mv uuid-*.tgz "${main_tgz}"

# Verify critical members
assert_tgz_has_member "${main_tgz}" "package/package.json"
assert_tgz_has_member "${main_tgz}" "package/dist-node/index.js"
assert_tgz_has_member "${main_tgz}" "package/dist-node/bin/uuid"

# Verify version
packed_version="$(tar -xOf "${main_tgz}" package/package.json | jq -r .version)"
if [[ "${packed_version}" != "${VERSION}" ]]; then
    echo "[build.entrypoint] version mismatch: expected ${VERSION}, got ${packed_version}" >&2
    exit 1
fi

echo "[build.entrypoint] Successfully built uuid@${VERSION}"

Assisted-by: Claude
