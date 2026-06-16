# npm-registry

Onboarding repository for **npm Trusted Libraries** — package recipes, manifests, and Konflux CI.

## Docs

| Document | Purpose |
| -------- | ------- |
| [proposal-npm-trusted-libraries-onboarding.md](docs/proposal-npm-trusted-libraries-onboarding.md) | Design |
| [poc_implementation_plan.md](docs/poc_implementation_plan.md) | Engineering phases |
| [ecp-policy-debt.md](docs/ecp-policy-debt.md) | EC exclusions to revisit before production |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Onboarder checklist |
| [manifest.schema.json](docs/manifest.schema.json) | Manifest JSON Schema |

## Layout

```text
packages/<name>/<version>/   # onboarded recipes (see packages/README.md)
hack/                        # identify-packages, lint-manifest.sh
.tekton/                     # Konflux build-npm pipeline (PAC)
```

Konflux Application / Component / ECP: [`konflux-release-data`](https://github.com/calungaproject/konflux-release-data) → `tenants-config/cluster/kflux-prd-rh03/tenants/calunga-tenant/npm/`

## CI (Phase 1)

PRs to `main` trigger **`build-npm`** via Konflux application `calunga-npm-registry-main`:

- Factory image: `quay.io/.../npm-builder`
- Build task: `task-build-npm-package` (Tekton bundle from `plumbing`)
- Output: Quay OCI artifact `.../calunga-npm-registry-main:on-pr-<sha>.npm` (5d TTL)

See [.tekton/README.md](.tekton/README.md) for bootstrap steps (GitOps in `konflux-release-data`, task bundle digest).

## Related repos

- [`plumbing`](https://github.com/calungaproject/plumbing) — `npm-builder` image + `build-npm-package-oci-ta` task
- [`index`](https://github.com/calungaproject/index) — Python TL onboarding (reference patterns)
