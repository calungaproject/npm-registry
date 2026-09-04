#!/usr/bin/env bash
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"
: "${WORK_DIR:?WORK_DIR required}"

PACKAGE_NAME="$(jq -r .name "${MANIFEST_PATH}")"
VERSION="$(jq -r .version "${MANIFEST_PATH}")"
SOURCE_URL="$(jq -r .source.url "${MANIFEST_PATH}")"
SOURCE_REF="$(jq -r .source.ref "${MANIFEST_PATH}")"
MAIN_TGZ_REL="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
main_tgz="${OUT_DIR}/${MAIN_TGZ_REL#out/}"

assert_tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1 || {
        echo "[build.entrypoint] ${tgz} missing ${member}" >&2
        echo "Tarball listing:" >&2
        tar tf "${tgz}" >&2 || true
        exit 1
    }
}

SRC="${WORK_DIR}/${PACKAGE_NAME}-src"
rm -rf "${SRC}"
mkdir -p "${OUT_DIR}" "$(dirname "${main_tgz}")"

echo "[build.entrypoint] Cloning ${SOURCE_URL} @ ${SOURCE_REF}"
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${SRC}"

cd "${SRC}"

actual_ref="$(git describe --tags --exact-match 2>/dev/null || git rev-parse HEAD)"
[[ "${actual_ref}" == "${SOURCE_REF}" ]] || {
    echo "Source ref ${actual_ref} != expected ${SOURCE_REF}" >&2
    exit 1
}

echo "[build.entrypoint] Installing dependencies"
npm install --ignore-scripts

echo "[build.entrypoint] Running build"
npm run build

echo "[build.entrypoint] Packing"
rm -f "${main_tgz}"
packed="$(npm pack --quiet)"
mv "${packed}" "${main_tgz}"

[[ -f "${main_tgz}" ]] || {
    echo "Expected tarball: ${main_tgz}" >&2
    exit 1
}

assert_tgz_has_member "${main_tgz}" package/package.json
assert_tgz_has_member "${main_tgz}" package/lib/index.js

packed_version="$(tar -xOf "${main_tgz}" package/package.json | jq -r .version)"
[[ "${packed_version}" == "${VERSION}" ]] || {
    echo "Packed version ${packed_version} != manifest ${VERSION}" >&2
    exit 1
}

echo "[build.entrypoint] Output: ${main_tgz}"
