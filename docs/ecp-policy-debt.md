# Enterprise Contract policy — revisit before production

Phase 1 uses a relaxed Enterprise Contract policy for the custom **`build-npm`**
OCI factory pipeline. **Debt** exclusions are tightened later; **structural**
exclusions match the pipeline shape and stay through first package onboard.

## Current setup

| Control | Setting |
| ------- | ------- |
| ECP | Python parity + `build-npm` structural excludes (see below) |
| Integration test | **Optional** until first package PR — `test.appstudio.openshift.io/optional: "true"` |
| Infra-only PRs | EC may run; failures do not block merge |
| First package PR | Set ITS **required** in same release-data MR or immediately before merge |

## Where policy lives

| Item | Location |
| ---- | -------- |
| ECP CR | [`konflux-release-data`](https://github.com/calungaproject/konflux-release-data) → `tenants-config/cluster/kflux-prd-rh03/tenants/calunga-tenant/npm/enterprisecontractpolicy-calunga-npm.yaml` |
| Integration test | `.../npm/integrationtest-calunga-npm-registry-main.yaml` |
| Python reference | [`index/konflux/ecp.yaml`](https://github.com/calungaproject/index/blob/main/konflux/ecp.yaml) |

After editing the ECP or ITS, run `tenants-config/build-manifests.sh` and commit
`auto-generated/` in `konflux-release-data`.

## Exclusion layers

### Python parity (same debt model as index)

Mirrors [Python `index/konflux/ecp.yaml`](https://github.com/calungaproject/index/blob/main/konflux/ecp.yaml), with
`base_image_permitted` for tenant `npm-builder` instead of `calunga-builder`.

### Structural — `build-npm` pipeline (keep through first package)

These are **not** infra-only workarounds; they reflect OCI factory vs `docker-build`:

- `pre_build_script_task.pre_build_script_task_runner_image_allowed:.../npm-builder` — `run-script-oci-ta` script runner
- `tasks.required_tasks_found:clamav-scan` — no clamav on this pipeline type
- `tasks.required_tasks_found:build-container` — OCI npm artifact, not a container image build
- `tasks.required_untrusted_task_found:git-clone-oci-ta` / `:init` — catalog bundles not in trusted-task list yet

### Trusted tasks (enabled for first package)

- `task-build-npm-package` is allowlisted via
  [`plumbing/policy-data/trusted_task_rules.yaml`](https://github.com/calungaproject/plumbing/blob/main/policy-data/trusted_task_rules.yaml)
  (ECP data source + `trusted_task_rules_enabled: true`).
- `BUILDER_IMAGE` must come from `lint-manifests` →
  `SCRIPT_RUNNER_IMAGE_REFERENCE` (not a raw PipelineRun param) so
  `trusted_task.trusted_parameters` passes. See
  [running user scripts](https://konflux-ci.dev/docs/patterns/running-user-scripts-on-the-build-pipeline/).

### Debt — tighten when compliance ships

Remove from ECP when implemented (same plan as Python index):

- `sbom.found`, `cve.cve_results_found`
- SAST / clair / rpm signature task requirements

## First package onboard checklist (e.g. esbuild)

In **npm-registry** PR:

- [ ] Recipe under `packages/<name>/<version>/` (no `builder` section in manifest)
- [ ] PipelineRun `builder-image` and `task-build-npm-package-bundle` digests current

In **konflux-release-data** (can merge before or with first package PR):

- [ ] ECP structural excludes synced (this doc’s structural list)
- [ ] Set `test.appstudio.openshift.io/optional: "false"` on `calunga-npm-registry-main-enterprise-contract`
- [ ] Argo sync to `calunga-tenant`

Expected EC outcome after sync: **pass** on a PR that builds real packages (optional warning `pipeline_required_tasks_list_provided` is OK).

## Pipeline behaviors that interact with EC

- PAC CEL on both PLRs requires at least one non-README change under `packages/`,
  so infra-only and README-only PRs/merges do not start a PipelineRun (no empty
  Snapshot for EC).
- Pipeline **`IMAGE_URL` / `IMAGE_DIGEST`** are **`build-npm-package` /
  `promote-npm-oci` task results** (trusted via plumbing task bundles). Do not
  add an inline `export-image-results` taskSpec — EC treats those as `<NAMELESS>`
  untrusted.

## Trigger to reopen this doc

- Removing debt exclusions (`sbom`, `trusted_task`, …)
- Enabling on-push / release pipeline
- EC failure on a **required** test after first package onboard
