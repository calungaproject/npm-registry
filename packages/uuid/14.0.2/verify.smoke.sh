#!/usr/bin/env bash
# Post-build smoke checks for uuid Tier A output.
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

dump_tgz_listing() {
    local tgz="$1"
    echo "Tarball listing (${tgz}):" >&2
    tar tf "${tgz}" >&2 || true
}

# Assert key files from the built dist-node tree
for member in package/package.json package/dist-node/index.js package/dist-node/bin/uuid; do
    tgz_has_member "${MAIN_PATH}" "${member}" || {
        echo "Main tarball missing ${member}" >&2
        dump_tgz_listing "${MAIN_PATH}"
        exit 1
    }
done

packed_name="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .name)"
packed_version="$(tar -xOf "${MAIN_PATH}" package/package.json | jq -r .version)"
[[ "${packed_name}" == "uuid" ]] || {
    echo "Unexpected package name: ${packed_name}" >&2
    exit 1
}
[[ "${packed_version}" == "${VERSION}" ]] || {
    echo "Unexpected package version: ${packed_version}" >&2
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

echo "[verify.smoke] Installing tarball for API test"
npm install --ignore-scripts --no-audit --no-fund --prefix "${tmpdir}" "${MAIN_PATH}"

echo "[verify.smoke] Testing module API"
node -e 'const uuid = require(process.argv[1]); const v4 = uuid.v4(); if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v4)) { console.error("Invalid v4 UUID:", v4); process.exit(1); }; console.log("v4:", v4)' "${tmpdir}/node_modules/uuid"

echo "[verify.smoke] Testing CLI"
uuid_output="$("${tmpdir}/node_modules/.bin/uuid")"
[[ -n "${uuid_output}" ]] || {
    echo "CLI produced no output" >&2
    exit 1
}
echo "[verify.smoke] CLI output: ${uuid_output}"

echo "[verify.smoke] OK"
