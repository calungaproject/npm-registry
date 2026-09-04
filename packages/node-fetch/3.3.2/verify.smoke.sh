#!/usr/bin/env bash
# Post-build smoke checks for Tier A output (node-fetch).
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"

PACKAGE_NAME="$(jq -r .name "${MANIFEST_PATH}")"
VERSION="$(jq -r .version "${MANIFEST_PATH}")"
MAIN_TGZ="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"

path_under_out() {
    local rel="$1"
    echo "${OUT_DIR}/${rel#out/}"
}

MAIN_PATH="$(path_under_out "${MAIN_TGZ}")"

echo "[verify.smoke] OUT_DIR=${OUT_DIR}" >&2
echo "[verify.smoke] MAIN_PATH=${MAIN_PATH}" >&2

[[ -f "${MAIN_PATH}" ]] || {
    echo "Missing tarball: ${MAIN_PATH}" >&2
    exit 1
}

tgz_has_member() {
    local tgz="$1" member="$2"
    tar -xOf "${tgz}" "${member}" >/dev/null 2>&1
}

for member in package/package.json package/src/index.js; do
    tgz_has_member "${MAIN_PATH}" "${member}" || {
        echo "Main tarball missing ${member}" >&2
        tar tf "${MAIN_PATH}" >&2 || true
        exit 1
    }
done

packed_name="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .name)"
packed_version="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .version)"

[[ "${packed_name}" == "${PACKAGE_NAME}" ]] || {
    echo "Unexpected package name: ${packed_name} (expected ${PACKAGE_NAME})" >&2
    exit 1
}

echo "[verify.smoke] Packed version: ${packed_version}"
echo "[verify.smoke] Manifest version: ${VERSION}"

if [[ "${packed_version}" != "${VERSION}" ]]; then
    echo "[verify.smoke] ERROR: Version mismatch detected" >&2
    echo "[verify.smoke] Tag v3.3.2 contains package.json with version ${packed_version}" >&2
    echo "[verify.smoke] This indicates an upstream tagging issue that requires manual investigation" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

npm install --ignore-scripts --no-audit --no-fund --prefix "${tmpdir}" "${MAIN_PATH}"

echo "[verify.smoke] Testing ESM module load"
node -e "import('${tmpdir}/node_modules/${PACKAGE_NAME}/src/index.js').then(() => console.log('ESM load OK')).catch(err => { console.error(err); process.exit(1); })"

echo "[verify.smoke] OK"
