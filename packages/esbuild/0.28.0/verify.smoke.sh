#!/usr/bin/env bash
# Post-build smoke checks for esbuild Tier B outputs.
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
MAIN_TGZ="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
PLATFORM_TGZ="$(jq -r '.outputs[] | select(.type == "tl-platform-package") | .path' "${MANIFEST_PATH}")"

# Manifest paths are recipe-relative (e.g. out/foo.tgz); OUT_DIR is writable factory output.
path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

MAIN_PATH="$(path_under_out "${MAIN_TGZ}")"
PLATFORM_PATH="$(path_under_out "${PLATFORM_TGZ}")"

echo "[verify.smoke] OUT_DIR=${OUT_DIR}" >&2
echo "[verify.smoke] MAIN_PATH=${MAIN_PATH}" >&2
echo "[verify.smoke] PLATFORM_PATH=${PLATFORM_PATH}" >&2

for path in "${MAIN_PATH}" "${PLATFORM_PATH}"; do
    [[ -f "${path}" ]] || {
        echo "Missing tarball: ${path}" >&2
        exit 1
    }
done

tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1
}

dump_tgz_listing() {
    local tgz="$1"
    echo "Tarball listing (${tgz}):" >&2
    tar tf "${tgz}" >&2 || file "${tgz}" >&2 || true
}

echo "[verify.smoke] Inspecting ${MAIN_TGZ}"
tgz_has_member "${MAIN_PATH}" package/package.json || {
    echo "Main tarball missing package/package.json" >&2
    dump_tgz_listing "${MAIN_PATH}"
    exit 1
}
tgz_has_member "${MAIN_PATH}" package/install.js || {
    echo "Main tarball missing package/install.js" >&2
    dump_tgz_listing "${MAIN_PATH}"
    exit 1
}

echo "[verify.smoke] Inspecting ${PLATFORM_TGZ}"
tgz_has_member "${PLATFORM_PATH}" package/bin/esbuild || {
    echo "Platform tarball missing package/bin/esbuild" >&2
    dump_tgz_listing "${PLATFORM_PATH}"
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
tar xzf "${PLATFORM_PATH}" -C "${tmpdir}"
bin="${tmpdir}/package/bin/esbuild"
[[ -f "${bin}" ]] || {
    echo "Platform tarball missing bin/esbuild" >&2
    exit 1
}
chmod +x "${bin}"

echo "[verify.smoke] Running esbuild --version"
"${bin}" --version | grep -F "${VERSION}"

echo "[verify.smoke] OK"
