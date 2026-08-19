#!/usr/bin/env bash
# Tier B factory build: esbuild JS wrapper + @calunga/esbuild-linux-x64 from git source.
# Writes only to OUT_DIR; must not publish.
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"
: "${WORK_DIR:?WORK_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
SOURCE_URL="$(jq -r .source.url "${MANIFEST_PATH}")"
SOURCE_REF="$(jq -r .source.ref "${MANIFEST_PATH}")"
TL_PLATFORM="@calunga/esbuild-linux-x64"

path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

assert_tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1 || {
        echo "[build.entrypoint] ${tgz} missing ${member}" >&2
        echo "Tarball listing:" >&2
        tar tf "${tgz}" >&2 || file "${tgz}" >&2 || true
        exit 1
    }
}

SRC="${WORK_DIR}/esbuild-src"
MAIN_STAGE="${WORK_DIR}/esbuild-main-pack"
PLATFORM_STAGE="${WORK_DIR}/calunga-platform"
MAIN_PKG="${SRC}/npm/esbuild"
UPSTREAM_PLATFORM="${SRC}/npm/@esbuild/linux-x64"

rm -rf "${SRC}" "${MAIN_STAGE}" "${PLATFORM_STAGE}"
mkdir -p "${OUT_DIR}" "${OUT_DIR}/@calunga"

echo "[build.entrypoint] Cloning ${SOURCE_URL} @ ${SOURCE_REF}"
git clone --depth 1 --branch "${SOURCE_REF}" "${SOURCE_URL}" "${SRC}"

cd "${SRC}"

echo "[build.entrypoint] Building linux-x64 binary (upstream make platform-linux-x64)"
make platform-linux-x64

LINUX_BIN="${UPSTREAM_PLATFORM}/bin/esbuild"
[[ -x "${LINUX_BIN}" ]] || {
    echo "Missing platform binary: ${LINUX_BIN}" >&2
    exit 1
}

echo "[build.entrypoint] Generating npm/esbuild install shims"
node scripts/esbuild.js npm/esbuild/package.json --version
node scripts/esbuild.js "${LINUX_BIN}" --neutral

echo "[build.entrypoint] Patching main package for TL platform optional dep"
jq --arg name "${TL_PLATFORM}" --arg version "${VERSION}" \
    '.optionalDependencies = { ($name): $version }' \
    "${MAIN_PKG}/package.json" > "${MAIN_PKG}/package.json.tmp"
mv "${MAIN_PKG}/package.json.tmp" "${MAIN_PKG}/package.json"

if [[ -f "${MAIN_PKG}/install.js" ]]; then
    sed -i "s#@esbuild/linux-x64#${TL_PLATFORM}#g" "${MAIN_PKG}/install.js"
fi

for req in install.js lib/main.js bin/esbuild package.json; do
    [[ -f "${MAIN_PKG}/${req}" ]] || {
        echo "[build.entrypoint] Missing generated main package file: ${MAIN_PKG}/${req}" >&2
        ls -la "${MAIN_PKG}" >&2 || true
        exit 1
    }
done

echo "[build.entrypoint] Packing main npm package"
# Use tar (npm package/ prefix) — npm pack applies upstream/git ancestor ignore rules and
# omits generated install.js even from a staging dir under WORK_DIR.
rm -rf "${MAIN_STAGE}"
mkdir -p "${MAIN_STAGE}"
cp -a "${MAIN_PKG}/." "${MAIN_STAGE}/"
MAIN_TGZ_REL="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
main_tgz="$(path_under_out "${MAIN_TGZ_REL}")"
pack_root="$(mktemp -d)"
mkdir -p "${pack_root}/package" "$(dirname "${main_tgz}")"
cp -a "${MAIN_STAGE}/." "${pack_root}/package/"
rm -f "${main_tgz}"
tar --create --gzip --file "${main_tgz}" --directory "${pack_root}" package
rm -rf "${pack_root}"
[[ -f "${main_tgz}" ]] || {
    echo "Expected main tarball: ${main_tgz}" >&2
    exit 1
}
assert_tgz_has_member "${main_tgz}" package/package.json
assert_tgz_has_member "${main_tgz}" package/install.js

echo "[build.entrypoint] Assembling ${TL_PLATFORM} platform package"
rm -rf "${PLATFORM_STAGE}"
mkdir -p "${PLATFORM_STAGE}/bin"
cp "${UPSTREAM_PLATFORM}/README.md" "${PLATFORM_STAGE}/"
cp "${LINUX_BIN}" "${PLATFORM_STAGE}/bin/esbuild"
chmod +x "${PLATFORM_STAGE}/bin/esbuild"
jq -n --arg name "${TL_PLATFORM}" --arg version "${VERSION}" \
    '{
        name: $name,
        version: $version,
        description: "The Linux 64-bit binary for esbuild (Trusted Libraries build).",
        license: "MIT",
        preferUnplugged: true,
        engines: { node: ">=18" },
        os: ["linux"],
        cpu: ["x64"]
    }' > "${PLATFORM_STAGE}/package.json"

PLATFORM_TGZ_REL="$(jq -r '.outputs[] | select(.type == "tl-platform-package") | .path' "${MANIFEST_PATH}")"
platform_tgz="$(path_under_out "${PLATFORM_TGZ_REL}")"
pack_root="$(mktemp -d)"
mkdir -p "${pack_root}/package" "$(dirname "${platform_tgz}")"
cp -a "${PLATFORM_STAGE}/." "${pack_root}/package/"
rm -f "${platform_tgz}"
tar --create --gzip --file "${platform_tgz}" --directory "${pack_root}" package
rm -rf "${pack_root}"
[[ -f "${platform_tgz}" ]] || {
    echo "Expected platform tarball: ${platform_tgz}" >&2
    exit 1
}
assert_tgz_has_member "${platform_tgz}" package/bin/esbuild

echo "[build.entrypoint] Outputs:"
ls -la "${OUT_DIR}" "${OUT_DIR}/@calunga"
