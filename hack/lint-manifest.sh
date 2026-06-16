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

mapfile -t MANIFESTS < <(git diff --name-only --diff-filter=AM "${PREV_REF}" -- 'packages/' | grep '/manifest\.json$' || true)
if [[ ${#MANIFESTS[@]} -eq 0 ]]; then
    echo "[lint-manifest] no changed manifests under packages/"
    exit 0
fi

validate_manifest() {
    local manifest="$1"
    local pkg_dir name version tier entrypoint smoke digest_pin source_url source_ref

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
    digest_pin="$(jq -r '.builder.image_digest_pin // empty' "${manifest}")"
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

    if [[ -n "${digest_pin}" && -n "${BUILDER_IMAGE_DIGEST:-}" ]]; then
        [[ "${digest_pin}" == "${BUILDER_IMAGE_DIGEST}" ]] || {
            echo "builder.image_digest_pin mismatch in ${manifest}" >&2
            exit 1
        }
    fi
}

for manifest in "${MANIFESTS[@]}"; do
    [[ -f "${manifest}" ]] || continue
    validate_manifest "${manifest}"
done

echo "[lint-manifest] OK (${#MANIFESTS[@]} manifest(s))"
