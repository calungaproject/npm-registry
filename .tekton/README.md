# npm-registry Tekton

## Pipeline

`build-pipeline.yaml` defines pipeline **`build-npm`** (Phase 1 — PR build to Quay OCI).

```text
init → clone-repository → lint-manifests → identify-packages → build-npm-package (optional) → export-image-results
```

Built tarballs are pushed as an OCI artifact to
`$(output-image).npm` (e.g. `.../calunga-npm-registry-main:on-pr-<sha>.npm`, 5d TTL).

`calunga-npm-registry-main-pull-request.yaml` triggers on PRs to `main`.

## Bootstrap checklist

Konflux **Application / Component / ECP / integration test** for `calunga-npm-registry-main`
are GitOps-managed in
[`konflux-release-data`](../../konflux-release-data/tenants-config/cluster/kflux-prd-rh03/tenants/calunga-tenant/npm/).

Plumbing (`npm-builder`, `task-build-npm-package`) stays UI-managed under `calunga-v2`.

1. Merge `konflux-release-data` PR; wait for Argo sync to `calunga-tenant`.
2. If you previously created `calunga-npm-registry-main` in the UI, remove the duplicate.
3. **Task bundle digest** — after `task-build-npm-package` is on Quay (UI component), update
   `task-build-npm-package-bundle` in this PipelineRun.
4. **Builder image** — keep `builder-image` / `builder-image-digest` in sync with Quay `npm-builder`.

## Pulp Stage (deferred)

The build task still supports optional `publish-to-pulp` when a stage npm repo exists.
No ExternalSecret or Vault wiring is required for Phase 1 Quay-only output.

## No packages in this PR

With no changes under `packages/`, `identify-packages` returns `no-packages` and
`build-npm-package` is skipped. `export-image-results` still runs, pushes an empty
npm OCI artifact to `$(output-image).npm`, and emits `IMAGE_URL` / `IMAGE_DIGEST`
so Konflux can create a Snapshot and run Enterprise Contract on infra-only PRs.
