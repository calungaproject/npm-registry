# npm-registry Tekton

## Pipelines

### `build-npm` (PR) — `build-pipeline.yaml`

```text
init → clone-repository → lint-manifests → identify-packages → build-npm-package
```

Built tarballs are pushed as an OCI artifact to
`$(output-image).npm` (e.g. `.../calunga-npm-registry-main:on-pr-<sha>.npm`, 5d TTL).
Pipeline `IMAGE_URL` / `IMAGE_DIGEST` come from the trusted **`build-npm-package`**
task (same pattern as Python `build-wheels`).

`calunga-npm-registry-main-pull-request.yaml` triggers on PRs to `main`.

### `promote-npm` (push) — `promote-pipeline.yaml`

```text
init → clone-repository → identify-packages → promote-npm-oci
```

On merge to `main`, promotes the matching **`on-pr-<sha>.npm`** artifact to a durable
`:<sha>.npm` snapshot (SBOM verify + compliance sidecars). **No rebuild.**

`calunga-npm-registry-main-push.yaml` sets:

| Param | Value |
| ----- | ----- |
| `output-image` | `…/calunga-npm-registry-main:{{revision}}` → OCI `….npm` |
| `source-npm-image` | `…/calunga-npm-registry-main:on-pr-{{revision}}.npm` |
| `prev-packages-ref` | `HEAD^` |

Promote **skips on-pr pull** when `identify-packages` returns `no-packages` (infra-only
merges); it still pushes a durable `.keep` OCI so the PipelineRun stays green.

Promote **fails** on `has-packages` if there is no on-pr OCI for `source-npm-image`.
Note: GitHub merge/squash commits usually have a **different SHA** than the PR head
that built `on-pr-<sha>.npm`, so package promotes need a matching strategy (same
commit on main as the PR build, or resolve the PR artifact by digest / PR metadata).

## Bootstrap checklist

Konflux **Application / Component / ECP / integration test** for `calunga-npm-registry-main`
are GitOps-managed in
[`konflux-release-data`](../../konflux-release-data/tenants-config/cluster/kflux-prd-rh03/tenants/calunga-tenant/npm/).

Plumbing (`npm-builder`, `task-build-npm-package`, `task-promote-npm-oci`) stays UI-managed
under `calunga-v2`.

1. Merge `konflux-release-data` PR; wait for Argo sync to `calunga-tenant`.
2. **Task bundle digests** — keep PipelineRun pins in sync with Quay:
   - PR: `task-build-npm-package-bundle`
   - push: `task-promote-npm-oci-bundle`
3. **Builder image** — keep `builder-image` in both PipelineRuns in sync with Quay `npm-builder`.

## Viewing OCI artifacts

Builds push to a **private** Quay repo (`calunga-npm-registry-main`).
Do **not** expect to browse it at `quay.io/redhat-user-workloads/calunga-tenant/calunga-npm-registry-main`
unless a Quay admin has granted your user Read on that repo.

**Inspect builds in Konflux UI:**

1. Application / Component **`calunga-npm-registry-main`**
2. Open the PipelineRun → **Results** → `IMAGE_URL`, `IMAGE_DIGEST`
3. For local pull: Component page → **Registry login information** → use the Konflux image
   proxy login (not a direct `quay.io` URL). See
   [Accessing private image repositories](https://konflux-ci.dev/docs/building/accessing-private-images/).

## Pulp Stage (deferred)

The build task still supports optional `publish-to-pulp` when a stage npm repo exists.
No ExternalSecret or Vault wiring is required for Quay-only output.

## No packages in this change

With no changes under `packages/`, `identify-packages` returns `no-packages`.
PR build still pushes an empty `.npm` OCI (`.keep`); push promote copies that to the
durable tag (compliance skipped when there are no tarballs).
