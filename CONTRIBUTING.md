# Contributing — npm Trusted Libraries onboarding

Onboard packages under `packages/<name>/<version>/`. See
[proposal](docs/proposal-npm-trusted-libraries-onboarding.md) and
[POC plan](docs/poc_implementation_plan.md).

## Recipe layout

```text
packages/<name>/<version>/
  manifest.json           # required metadata (see docs/manifest.schema.json)
  build.entrypoint.sh     # factory build — writes out/*.tgz only
  verify.smoke.sh         # post-build checks
  out/                    # gitignored factory output
```

## Rules

1. **Build from git source** at `source.ref` — never repack from registry.npmjs.org.
2. **`build.entrypoint.sh` must not publish** — no `npm publish`, cosign keys, or registry tokens.
3. **One manifest → one factory run → all `outputs[]`** tarballs (Tier B: main + platform).
4. Set `builder.image_digest_pin` to the deployed `npm-builder` digest (see `.tekton` PipelineRun).
5. Do **not** author `compliance_level` / `closure_gaps` — CI computes those later.

## Local checks

Requires `jq` (shipped in the `npm-builder` image used by CI).

```bash
chmod +x hack/identify-packages hack/lint-manifest.sh
./hack/lint-manifest.sh origin/main
```

Validate JSON against schema locally (optional):

```bash
# pip install check-jsonschema  # or ajv-cli
check-jsonschema --schemafile docs/manifest.schema.json packages/*/*/manifest.json
```

## CI

PRs to `main` run Konflux pipeline **`build-npm`** (`.tekton/`):

1. Lint changed manifests
2. Identify changed packages vs `origin/main`
3. Run factory in `npm-builder`
4. Push built tarballs to **Quay** as an OCI artifact (`on-pr-<sha>.npm`, 5d TTL)

Register Konflux component **`calunga-npm-registry-main`** before the first pipeline run (GitOps in `konflux-release-data`).

## Pulp Stage (deferred)

Optional stage `npm publish` can be enabled later when the Pulp team provisions a stage repo
(`publish-to-pulp: "true"` in the PipelineRun + stage credentials). Phase 1 uses Quay only,
matching Python `calunga-v2-index-main`.
