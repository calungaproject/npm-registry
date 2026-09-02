#!/bin/bash
# Static gate for changed package manifests (policy checks; full schema for local dev).
set -euo pipefail

PREV_REF="${1:-origin/main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to lint manifests" >&2
    exit 1
fi

set +e
diff_output="$(git diff --name-only --diff-filter=AM "${PREV_REF}" -- 'packages/')"
err="$?"
set -e

if [[ $err -ne 0 ]]; then
    echo "[lint-manifest] git diff failed (ref ${PREV_REF}), linting all manifests under packages/" >&2
    mapfile -t MANIFESTS < <(find packages -name manifest.json -type f 2>/dev/null | sort)
else
    mapfile -t MANIFESTS < <(printf '%s\n' "${diff_output}" | grep '/manifest\.json$' || true)
fi

if [[ ${#MANIFESTS[@]} -eq 0 ]]; then
    echo "[lint-manifest] no changed manifests under packages/"
    exit 0
fi

validate_manifest() {
    local manifest="$1"
    local pkg_dir name version tier entrypoint smoke source_url source_ref

    echo "[lint-manifest] ${manifest}"

    if ! jq -e . "${manifest}" >/dev/null 2>&1; then
        echo "Invalid JSON in ${manifest}" >&2
        exit 1
    fi

    pkg_dir="$(dirname "${manifest}")"
    name="$(jq -r '.name // empty' "${manifest}")"
    version="$(jq -r '.version // empty' "${manifest}")"
    tier="$(jq -r '.native_tier // empty' "${manifest}")"
    entrypoint="$(jq -r '.entrypoint // empty' "${manifest}")"
    smoke="$(jq -r '.smoke // empty' "${manifest}")"
    source_url="$(jq -r '.source.url // empty' "${manifest}")"
    source_ref="$(jq -r '.source.ref // empty' "${manifest}")"

    for field in name version tier entrypoint smoke; do
        if [[ -z "${!field}" ]]; then
            echo "Missing required field: ${field} in ${manifest}" >&2
            exit 1
        fi
    done

    case "${tier}" in
        A|B|C) ;;
        *)
            echo "native_tier must be A, B, or C (got ${tier})" >&2
            exit 1
            ;;
    esac

    stream="$(jq -r '.stream // empty' "${manifest}")"
    if [[ -z "${stream}" ]]; then
        echo "Missing required field: stream in ${manifest}" >&2
        exit 1
    fi
    case "${stream}" in
        validated|remediated) ;;
        *)
            echo "stream must be validated or remediated (got ${stream})" >&2
            exit 1
            ;;
    esac

    [[ "${pkg_dir}" == "packages/${name}/${version}" ]] || {
        echo "Directory ${pkg_dir} must match packages/${name}/${version}" >&2
        exit 1
    }

    [[ -x "${pkg_dir}/${entrypoint}" ]] || {
        echo "Missing or not executable: ${pkg_dir}/${entrypoint}" >&2
        exit 1
    }
    [[ -x "${pkg_dir}/${smoke}" ]] || {
        echo "Missing or not executable: ${pkg_dir}/${smoke}" >&2
        exit 1
    }

    if [[ -z "${source_url}" || -z "${source_ref}" ]]; then
        echo "source.url and source.ref required in ${manifest}" >&2
        exit 1
    fi

    if ! jq -e '.outputs | type == "array" and length > 0' "${manifest}" >/dev/null; then
        echo "outputs[] required in ${manifest}" >&2
        exit 1
    fi

    if [[ "${tier}" == "B" ]]; then
        if ! jq -e '[.outputs[]? | select(.type == "tl-platform-package")] | length > 0' "${manifest}" >/dev/null; then
            echo "Tier B manifests require a tl-platform-package output" >&2
            exit 1
        fi
    fi
}

for manifest in "${MANIFESTS[@]}"; do
    [[ -f "${manifest}" ]] || continue
    validate_manifest "${manifest}"
done

echo "[lint-manifest] OK (${#MANIFESTS[@]} manifest(s))"
