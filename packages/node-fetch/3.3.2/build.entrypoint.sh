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

echo "[build.entrypoint] Cloning ${SOURCE_URL} at ${SOURCE_REF}"
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${WORK_DIR}/src"
cd "${WORK_DIR}/src"

echo "[build.entrypoint] Patching package.json version to ${VERSION}"
jq --arg version "${VERSION}" '.version = $version' package.json > package.json.tmp
mv package.json.tmp package.json

echo "[build.entrypoint] Packing node-fetch@${VERSION}"
npm pack --quiet

packed_file="$(ls -1 node-fetch-*.tgz)"
mv "${packed_file}" "${main_tgz}"

echo "[build.entrypoint] Verifying tarball structure"
assert_tgz_has_member "${main_tgz}" "package/package.json"
assert_tgz_has_member "${main_tgz}" "package/src/index.js"

packed_version="$(tar -xOf "${main_tgz}" package/package.json | jq -r .version)"
if [[ "${packed_version}" != "${VERSION}" ]]; then
    echo "[build.entrypoint] ERROR: packed version ${packed_version} != expected ${VERSION}" >&2
    exit 1
fi

echo "[build.entrypoint] Successfully built ${main_tgz}"
ls -lh "${OUT_DIR}"
