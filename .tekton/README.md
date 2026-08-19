# npm-registry Tekton

## Pipelines

### `build-npm` (PR) — `build-pipeline.yaml`

```text
init → clone-repository → lint-manifests → identify-packages → build-npm-package
```

Built tarballs are pushed as an OCI artifact to
`$(output-image).npm` (e.g. `.../calunga-npm-registry-main:on-pr-<pr-number>.npm`, 5d TTL).
Ephemeral tags use the **pull request number** (`on-pr-{{pull_request_number}}`), not commit
SHA, so squash/rebase merges still match the on-push promote source.
Pipeline `IMAGE_URL` / `IMAGE_DIGEST` come from the trusted **`build-npm-package`**
task (same pattern as Python `build-wheels`).

`calunga-npm-registry-main-pull-request.yaml` triggers on PRs to `main` **only when
at least one non-README file under `packages/` changes** (PAC CEL on `files.all`).
`packages/README.md` (or other `README` / `README.md` under `packages/`) alone does
**not** start a build. Docs / `.tekton` / other infra-only PRs also do not.

`hack/identify-packages` then selects **new** `packages/<name>/<version>/` dirs (or
manifests whose `name`/`version` fields changed vs `prev-packages-ref`). On PR,
`prev-packages-ref` is the GitHub merge-base SHA (`body.pull_request.base.sha`) because
fork clones often lack `origin/main`. In-place
edits to an already-merged recipe are unsupported: the PipelineRun may still start,
but identify returns `no-packages` and the build/promote fails. Contributors should
add a new version directory instead (see [CONTRIBUTING.md](../CONTRIBUTING.md)).

### `promote-npm` (push) — `promote-pipeline.yaml`

```text
init → clone-repository → identify-packages → promote-npm-oci
```

On merge to `main`, promotes the matching **`on-pr-<pr-number>.npm`** artifact to a durable
`:<merge-sha>.npm` snapshot (SBOM verify + compliance sidecars). **No rebuild.**
Package merges must go through a GitHub PR so PAC can set `{{pull_request_number}}` on push.

`calunga-npm-registry-main-push.yaml` triggers on push to `main` **only when at
least one non-README file under `packages/` changes** (same CEL as PR). Infra-only
merges and README-only package-tree edits do not promote, create a Snapshot, or
auto-release.

| Param | Value |
| ----- | ----- |
| `output-image` | `…/calunga-npm-registry-main:{{revision}}` → durable OCI `….npm` (merge SHA) |
| `source-npm-image` | `…/calunga-npm-registry-main:on-pr-{{pull_request_number}}.npm` |
| `prev-packages-ref` | `HEAD^` |

Promote **fails** if `PACKAGES_STATUS` is not `has-packages`, if the on-pr
OCI is missing (no green PR build for that PR number), or if the pulled artifact
has no `.tgz` files.

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

Builds push to Quay repo `calunga-npm-registry-main`. **PoC visibility is public**
(same pattern as Python `calunga-v2-index-main`) so release `verify-conforma` can HEAD
snapshot images without releng pull creds. See
[prod_followup.md](../docs/prod_followup.md) before making the repo private for prod.

**Inspect builds in Konflux UI:**

1. Application / Component **`calunga-npm-registry-main`**
2. Open the PipelineRun → **Results** → `IMAGE_URL`, `IMAGE_DIGEST`
3. For local pull while **public**: `podman pull quay.io/redhat-user-workloads/calunga-tenant/calunga-npm-registry-main:<tag>`
4. If visibility is switched back to **private**: use Component → **Registry login information**
   and the image-rbac-proxy URL. See
   [Accessing private image repositories](https://konflux-ci.dev/docs/building/accessing-private-images/).

## Pulp Stage (deferred)

The build task still supports optional `publish-to-pulp` when a stage npm repo exists.
No ExternalSecret or Vault wiring is required for Quay-only output.

## Testing PipelineRun / `.tekton` changes

With the `packages/`-only CEL filter, editing `.tekton/` alone does **not** start
PR or push PipelineRuns. For prod, add a dedicated on-PR path filter (e.g.
`.tekton/***`) so PipelineRun changes can be exercised without a package bump —
see [prod_followup.md](../docs/prod_followup.md).
