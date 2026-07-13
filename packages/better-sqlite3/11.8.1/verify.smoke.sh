#!/usr/bin/env bash
# Post-build smoke checks for better-sqlite3 Tier C outputs.
set -euo pipefail

: "${MANIFEST_PATH:?MANIFEST_PATH required}"
: "${OUT_DIR:?OUT_DIR required}"

VERSION="$(jq -r .version "${MANIFEST_PATH}")"
MAIN_TGZ="$(jq -r '.outputs[] | select(.type == "npm-package") | .path' "${MANIFEST_PATH}")"
PLATFORM_TGZ="$(jq -r '.outputs[] | select(.type == "tl-platform-package") | .path' "${MANIFEST_PATH}")"

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
    tar tf "${tgz}" >&2 || ls -la "${tgz}" >&2 || true
}

# npm-builder image has no `file(1)`; validate ELF magic + x86-64 via od (coreutils).
verify_elf_linux_x64() {
    local bin="$1"
    local magic elf_class machine

    magic="$(od -An -tx1 -N4 "${bin}" | tr -d ' \n')"
    [[ "${magic}" == "7f454c46" ]] || {
        echo "Not an ELF file: ${bin} (magic ${magic})" >&2
        return 1
    }

    elf_class="$(od -An -tu1 -j4 -N1 "${bin}" | tr -d ' ')"
    [[ "${elf_class}" == "2" ]] || {
        echo "Not ELF64: ${bin} (class ${elf_class})" >&2
        return 1
    }

    # e_machine EM_X86_64 == 62
    machine="$(od -An -tu2 -j18 -N2 "${bin}" | tr -d ' ')"
    [[ "${machine}" == "62" ]] || {
        echo "Not x86-64 ELF: ${bin} (machine ${machine})" >&2
        return 1
    }
}

echo "[verify.smoke] Inspecting ${MAIN_TGZ}"
for member in package/package.json package/install.js package/lib/database.js; do
    tgz_has_member "${MAIN_PATH}" "${member}" || {
        echo "Main tarball missing ${member}" >&2
        dump_tgz_listing "${MAIN_PATH}"
        exit 1
    }
done

main_pkg="$(tar -xOf "${MAIN_PATH}" package/package.json)"
echo "${main_pkg}" | jq -e '.scripts.install == null' >/dev/null || {
    echo "Published main package must not retain upstream install script" >&2
    exit 1
}
echo "${main_pkg}" | jq -e '.optionalDependencies["@calunga/better-sqlite3-linux-x64"] == "'"${VERSION}"'"' >/dev/null || {
    echo "Main package missing TL optional dependency" >&2
    exit 1
}

echo "[verify.smoke] Inspecting ${PLATFORM_TGZ}"
tgz_has_member "${PLATFORM_PATH}" package/better_sqlite3.node || {
    echo "Platform tarball missing package/better_sqlite3.node" >&2
    dump_tgz_listing "${PLATFORM_PATH}"
    exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
tar xzf "${PLATFORM_PATH}" -C "${tmpdir}"
node_file="${tmpdir}/package/better_sqlite3.node"
[[ -f "${node_file}" ]] || {
    echo "Extracted addon missing" >&2
    exit 1
}

echo "[verify.smoke] Verifying native addon is ELF linux-x64"
verify_elf_linux_x64 "${node_file}"

echo "[verify.smoke] OK"
