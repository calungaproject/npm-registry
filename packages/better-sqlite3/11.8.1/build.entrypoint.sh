#!/usr/bin/env bash
# Tier C factory build: compile better-sqlite3 native addon from git + publish main + platform tarballs.
# Writes only to OUT_DIR; must not publish.
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"
: "${WORK_DIR:?WORK_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
SOURCE_URL="$(jq -r .source.url "${MANIFEST_PATH}")"
SOURCE_REF="$(jq -r .source.ref "${MANIFEST_PATH}")"
TL_PLATFORM="@calunga/better-sqlite3-linux-x64"
RECIPE_DIR="$(cd "$(dirname "${MANIFEST_PATH}")" && pwd)"

path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

assert_tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1 || {
        echo "[build.entrypoint] ${tgz} missing ${member}" >&2
        echo "Tarball listing:" >&2
        tar tf "${tgz}" >&2 || ls -la "${tgz}" >&2 || true
        exit 1
    }
}

pack_dir() {
    local stage="$1" tgz="$2"
    local pack_root
    pack_root="$(mktemp -d)"
    mkdir -p "${pack_root}/package" "$(dirname "${tgz}")"
    cp -a "${stage}/." "${pack_root}/package/"
    rm -f "${tgz}"
    tar --create --gzip --file "${tgz}" --directory "${pack_root}" package
    rm -rf "${pack_root}"
}

SRC="${WORK_DIR}/better-sqlite3-src"
MAIN_STAGE="${WORK_DIR}/better-sqlite3-main-pack"
PLATFORM_STAGE="${WORK_DIR}/calunga-platform"
MAIN_TGZ_REL="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
PLATFORM_TGZ_REL="$(jq -r '.outputs[] | select(.type == "tl-platform-package") | .path' "${MANIFEST_PATH}")"
main_tgz="$(path_under_out "${MAIN_TGZ_REL}")"
platform_tgz="$(path_under_out "${PLATFORM_TGZ_REL}")"
NATIVE_BIN="${SRC}/build/Release/better_sqlite3.node"

rm -rf "${SRC}" "${MAIN_STAGE}" "${PLATFORM_STAGE}"
mkdir -p "${OUT_DIR}" "${OUT_DIR}/@calunga"

echo "[build.entrypoint] Cloning ${SOURCE_URL} @ ${SOURCE_REF}"
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${SRC}"

cd "${SRC}"

echo "[build.entrypoint] Compiling native addon (node-gyp --release)"
npm run build-release

[[ -f "${NATIVE_BIN}" ]] || {
    echo "Missing compiled addon: ${NATIVE_BIN}" >&2
    exit 1
}

echo "[build.entrypoint] Staging main package (JS + TL install shim; no consumer compile path)"
rm -rf "${MAIN_STAGE}"
mkdir -p "${MAIN_STAGE}/lib"
cp -a lib/. "${MAIN_STAGE}/lib/"
cp "${RECIPE_DIR}/tl-install.js" "${MAIN_STAGE}/install.js"

jq --arg name "${TL_PLATFORM}" --arg version "${VERSION}" \
    'del(.scripts.install, .scripts.prepare, .devDependencies)
     | .dependencies = { bindings: .dependencies.bindings }
     | .optionalDependencies = { ($name): $version }
     | .scripts = { postinstall: "node install.js" }
     | .files = ["lib/**", "install.js"]' \
    package.json > "${MAIN_STAGE}/package.json"

echo "[build.entrypoint] Packing main npm package"
pack_dir "${MAIN_STAGE}" "${main_tgz}"
assert_tgz_has_member "${main_tgz}" package/package.json
assert_tgz_has_member "${main_tgz}" package/install.js
assert_tgz_has_member "${main_tgz}" package/lib/index.js

echo "[build.entrypoint] Assembling ${TL_PLATFORM} platform package"
rm -rf "${PLATFORM_STAGE}"
mkdir -p "${PLATFORM_STAGE}"
cp "${NATIVE_BIN}" "${PLATFORM_STAGE}/better_sqlite3.node"
jq -n --arg name "${TL_PLATFORM}" --arg version "${VERSION}" \
    '{
        name: $name,
        version: $version,
        description: "linux-x64 native addon for better-sqlite3 (Trusted Libraries build).",
        license: "MIT",
        os: ["linux"],
        cpu: ["x64"],
        files: ["better_sqlite3.node"]
    }' > "${PLATFORM_STAGE}/package.json"

pack_dir "${PLATFORM_STAGE}" "${platform_tgz}"
assert_tgz_has_member "${platform_tgz}" package/better_sqlite3.node

echo "[build.entrypoint] Outputs:"
ls -la "${OUT_DIR}" "${OUT_DIR}/@calunga"
