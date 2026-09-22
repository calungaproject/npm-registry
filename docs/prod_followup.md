# Production follow-ups (PoC OK / not for prod)

Working list of shortcuts that are **acceptable for the npm Trusted Libraries PoC**
but should be closed (or explicitly reaffirmed) before treating the path as
production-ready for consumers.

Related: [plan-on-push-snapshot-release](./plan-on-push-snapshot-release.md),
[poc_implementation_plan](./poc_implementation_plan.md),
[ecp-policy-debt](./ecp-policy-debt.md),
[proposal](./proposal-npm-lightwell-onboarding.md).

Update this file when a follow-up lands or when a PoC choice is intentionally
kept for prod.

**Workflow:** Whenever we skip, relax, or defer something to land the PoC, add or
update a row here the same turn (PoC today / prod expectation). Do not rely on
memory or chat — this file is the prod debt register.

**Two registers in this file:**

- **PoC implementation debt** — the tables from [Go-live checklist](#go-live-checklist-rh-pulp-prod--first-cut)
  through [Ops / validation](#ops--validation), plus [Explicitly out of first cut](#explicitly-out-of-first-cut-reconfirm-for-prod)
  and [Suggested order](#suggested-order-after-e2e-is-green). These are shortcuts
  we took while wiring factory → Pulp.
- **GA consumption and catalog** — [its own section](#ga-consumption-and-catalog-proposal-review--not-poc-debt).
  That list comes from proposal review, not from implementing the PoC. Do not
  fold those items into the PoC tables; they are not e2e blockers.

---

## Go-live checklist (RH Pulp prod — first cut)

PoC spine when these are wired:

| Layer | Repo | PoC status | Prod gate |
| ----- | ---- | ---------- | --------- |
| on-pr build | `npm-registry` + `plumbing` | Factory → Quay `on-pr-<sha>.npm` | First real package green; builder + task bundles pinned by digest |
| on-push promote | `npm-registry` | Promote → Quay `:<merge-sha>.npm` | Runbook: merge SHA must have green on-pr artifact |
| Release | `release-service-catalog` | `calunga-push-npm-to-pulp` merged | Pin RPA to `production` after weekly RSC promote; signing + attest (below) |
| Release admission | `konflux-release-data` | RPA + ReleasePlan + ECP in MR | Merge + Argo sync; SA mapping includes `calunga-push-npm-to-pulp` |
| Consumer smoke | manual | — | `npm install --registry …/javascript/` on at least one published package |

**Suggested order after first e2e green:** see [Suggested order](#suggested-order-after-e2e-is-green) at the bottom.

---

## Konflux release admission (`konflux-release-data`)

| Topic | PoC today | Prod expectation |
| ----- | --------- | ---------------- |
| **RPA pipeline revision** | `development` (same interim as Python wheels after twine fix) | `production` once `calunga-push-npm-to-pulp` is on the weekly RSC promote branch |
| **ECP parent** | Temporary policy `registry-calunga-npm-tmp-onboard-prod` derives from **`registry-standard`** (ROOT) | Keep while onboarding — custom policies cannot chain off `registry-calunga-prod` (CI `test_policy_derivation_declarations`) |
| **Label rule waivers** | `labels` / `labels.required_labels` in **`volatileConfig.exclude`** with `effectiveUntil` + `reference` (RELDEV-317) | Python `registry-calunga-prod` still uses static `config.exclude` (grandfathered); **new** npm release ECP must use volatile form. Renew/remove and converge before `effectiveUntil` |
| **ProdSec exception process** | PoC uses temporary onboarding policy name + mapped exceptions | File explicit ProdSec exception request via form before declaring prod-ready: <https://docs.google.com/forms/d/e/1FAIpQLSdGkT1iWwmYIJ0i3zIQRer07UIlPKNVemzDWq2PxLaX_BzMMw/viewform?fbzx=3761964719917576384> |
| **ReleasePlan** | `calunga-npm-registry-main` → `calunga-push-npm-to-pulp-prod` | Confirm auto-release + standing-attribution labels after sync |
| **Constraints** | `calunga.yaml` allows npm pipeline path + `registry-calunga-npm-prod` | Tighten `pathInRepo` regex to full-path alternation if we want to block mismatched directory/file pairs |
| **Pulp RPA data** | `repository: npm-registry`, shared `rhtl-pulp-credentials-secret` | Confirm npm push ACL on `public-trusted-libraries`; separate secret only if least-privilege requires |
| **Argo / sync** | MR not merged yet | Merge KRD → verify releng + `calunga-tenant` reconcile before first release |
| **Release SA Quay pull (private repos)** | Not required while ImageRepository is **public** | If repo is **private**, confirm `release-pulp-calunga-prod` has `redhat-user-workloads-pull` (releng; see [Quay visibility](#build--promote--registry-model)) |

---

## Release pipeline (`release-service-catalog`)

| Topic | PoC today | Prod expectation |
| ----- | --------- | ---------------- |
| **Package signing** | No `rh-sign-npm-packages`; pipeline ships unsigned `.tgz` to Pulp | Add signing task (mirror `rh-sign-python-wheels`); gate on signing secret; optional compliance fields in attestation predicate |
| **Atlas / SBOM upload** | Not wired | Wire when ProdSec requires (same bar as Python when enabled) |
| **Upload client** | `curl` + Pulp REST in `upload-npm-pulp` | Prefer `pulp-cli` (or shared plumbing-utils) for maintainability, retries, and API drift |
| **Compliance file sidecars** | Labels (`tl.compliance_level`) applied on the npm content unit; `PULP_FILE_REPOSITORY` optional and usually unset → **no** adjacent `*.tl-compliance.json` in a file repo | Create a Pulp **file** repository for compliance JSON; set `PULP_FILE_REPOSITORY` via RPA / `collect-task-params`; stop relying on labels alone for operators who need the full sidecar |
| **Sidecar upload failures** | Best-effort warning only | Decide: fail release on sidecar upload failure once file repo is required |
| **verify_ec_task_bundle** | Deprecated/ignored; EC task resolved from pinned ec-cli git revision | Keep documenting as ignored, or switch to the supported Conforma resolver pattern catalog-wide when peers do |
| **Advisory content** | Pipeline may still call advisory steps with npm-thin content | Flesh advisory / product notes for npm when release process requires them |
| **RSC pipeline pin** | RPA uses git `revision: development` | After promote, pin to `production`; `taskGitRevision` is injected by release-operator from the same value — no separate SHA enforcement in pipeline YAML |
| **Attestations at release** | Verify boundary; cosign predicate may omit compliance fields | Full attest per `.tgz`; optional `compliance_level` / `assessed_at` in predicate when sidecars exist |

---

## Compliance metadata

| Topic | PoC today | Prod expectation |
| ----- | --------- | ---------------- |
| **Assess quality** | Inductive L1/L2/L3 from packed `package.json` `dependencies` vs the TL packument (ranges via max-satisfying). Direct deps only; empty deps → L3. Existing Pulp labels stay until re-promote/re-release after the new `npm-builder` pin. | Tighten to lockfile / resolved tree if org policy needs stronger L3 claims |
| **Point-in-time levels** | Level fixed at on-push; no republish to bump L1→L3 | **Closure updater** (below) propagates level changes when deps land; still no silent semver re-publish |
| **Query path for operators** | Pulp content labels | Labels **plus** adjacent file records (or equivalent queryable store) |
| **Closure index + updater** | Not wired. Levels are point-in-time at on-push; parents stay L1/L2 until manual re-release. | Maintain a versioned **closure index** OCI artifact (Quay) + mutable Pulp label (`tl.latest_closure_digest`). Updater runs in release after publish, merges the new node, walks **parents** upward, recomputes levels, writes a new index snapshot, CAS-updates the global digest label. |
| **Updater retry policy** | **Debug / PoC:** fail fast on any error **except** explicit CAS / race conflicts (stale digest on label write). Retry with backoff **only** on conflict. Release fails even if publish succeeded so the same snapshot can be retried until updater logic is stable. | **GA:** broaden retry and idempotency once updater is stable — bounded retries on transient Pulp/Quay errors, debounce/coalesce when multiple children land, metrics/alerts, runbook for stuck closure digest. Treat “publish OK, updater failed” as a release failure until closure state converges. |

---

## Build / promote / registry model

| Topic | PoC today | Prod expectation |
| ----- | --------- | ---------------- |
| **Pulp Stage** | None — Quay `on-pr-*` only until release → Pulp Prod | Revisit pre-merge Stage registry if reviewers need `npm install` before merge |
| **Promote source** | Quay on-pr artifact promoted on push (no rebuild) | Keep unless Stage returns; harden runbook when merge SHA has no green on-pr |
| **PAC path filter** | PR + push PLRs run when a non-README file under `packages/` changes | Keep for package releases; **add a second on-PR PipelineRun** (or CEL branch) filtered to `.tekton/***` so PipelineRun/pipeline edits can be tested without a package change |
| **EC on build** | Relaxed / optional ITS until first packages; structural excludes for OCI factory | Make ITS **required** (`optional: "false"` on `calunga-npm-registry-main-enterprise-contract`); remove debt excludes per [ecp-policy-debt](./ecp-policy-debt.md) when SBOM/CVE/SAST gates are real |
| **EC on release** | `registry-calunga-npm-prod` mirrors Python debt excludes + npm structural rules | Tighten debt excludes in step with build ECP; keep structural excludes for OCI/npm factory shape |
| **Empty / infra-only snapshots** | Removed: PAC skips non-`packages/` changes; build/promote/upload fail if no `.tgz` | Keep PAC filters; fail closed on empty artifacts |
| **Quay ImageRepository visibility** | **`public`** on `calunga-npm-registry-main` (matches Python `calunga-v2-index-main` PoC). Unblocks release `verify-conforma` `builtin.image.accessible` without releng `redhat-user-workloads-pull` on `release-pulp-calunga-prod`. Promoted `.npm` OCI artifacts are anonymously pullable from `quay.io` until changed. | **Revisit before prod:** prefer **private** for least exposure of interim OCI artifacts. Private requires `redhat-user-workloads-pull` on `release-pulp-calunga-prod` in `rhtap-releng-tenant` (releng-managed; confirm Argo sync + robot read on `calunga-tenant/*`). Release Conforma validates snapshot **`quay.io`** URLs, not Konflux **image-rbac-proxy** URLs. After flipping to private, re-run a full release and confirm `verify-conforma` + `extract-npm-artifacts` both pass. |

---

## Ops / validation

| Topic | PoC today | Prod expectation |
| ----- | --------- | ---------------- |
| **Post-release smoke** | Manual `npm install --registry …/javascript/` | Automate smoke (and optional digest/idempotency checks) in release or a follow-on job |
| **Credentials** | Reuse / share Pulp secret pattern with Python wheels | Confirm npm push ACL on the domain; separate secret if least-privilege requires it |
| **Consumer docs** | Internal plan docs | Public install URL, scoped package rules, L1/L2/L3 meaning, and “no silent npmjs for TL platform optionals” |
| **Minimum compliance level** | Publish allowed at L1–L3; level fixed at on-push | Org policy: document prod default (often L3 for apps); see proposal compliance section |

---

## Future product surfaces (not first RH prod cut)

| Topic | Notes |
| ----- | ----- |
| **Lightwell remediated Pulp** | CVE backports to customer-pinned versions; paid subscription; separate RPA / publish routing |
| **Lightwell private Pulp** | Per-customer or per-group repos; paid subscription |
| **Fullsend agent onboarding** | Priority queue → recipe PR → attack gate before on-pr; human merge still required |
| **Pulp Stage on PR** | Optional pre-merge `npm install` registry; PoC uses Quay on-pr only |

See proposal [High-level flow](./proposal-npm-lightwell-onboarding.md#high-level-flow-agents--factory--multi-pulp-publish).

---

## GA consumption and catalog (proposal review — not PoC debt)

Comments from proposal review on **how customers install and how large the
catalog can be**. They do **not** invalidate the factory + recipe + Pulp PoC
(build, attest, publish a source-built `.tgz` with a compliance label). They
**do** need explicit product decisions before calling TL npm generally
available.

For the PoC: do not over-claim. Do not demo L1 mixed-registry as production-safe,
do not imply Ubuntu-certified natives, do not imply top-50 cadence or full
dependency closure. Story until GA: **factory + publish works; consumption
policy is a GA discussion.**

### Already in the proposal (say so in review)

| Topic | Take |
| ----- | ---- |
| Silent `node-gyp` / install exit 0 | Intent is already fail-closed: Tier B/C strip consumer compile fallbacks; missing TL platform package must error. Residual risk is **recipe quality + smoke coverage**, not missing policy. |
| Lockfile integrity hashes | Source-built `.tgz` will never match npmjs `integrity`. That is the trust model. Regenerating lockfiles is a **migration**, not a drop-in mirror. |
| Semver `^` vs exact pins | L2/L3 assume `npm ci` + lockfile URLs on Pulp. Without a lockfile, mixed registries will surprise people. That is npm, not a TL factory bug. |
| Python comparison / L3 hardness | L1/L2/L3 exist *because* npm trees are huge. Still undersell it in the comparison table. Own: **L3 full-closure is a years-scale catalog problem**, not a factory problem. v1 success is publish, not “Vite’s whole tree is L3.” |

### Real GA decisions (consumption contract)

These are the review comments that matter. The proposal is weakest here.

| Topic | Take | Before GA |
| ----- | ---- | --------- |
| **Registry routing (unscoped names)** | npm has no clean “`express` from TL, everything else from npmjs.” `@scope:registry=` only helps scoped names. L1 mixed install is honest and **unsafe by default** (`^` can resolve from npmjs). | Do **not** ship L1 mixed-registry as a supported production story. Consumers get **Pulp-only + lockfile**, or a **routing proxy**. Treat L1 as catalog KPI + factory output. |
| **Platform package rename vs same name** | Main tarball should **keep** upstream names (`express`, `esbuild`). `@calunga/<name>-linux-x64` vs `@esbuild/linux-x64` **does** break optional-dep dedup and inflates installs. Keeping the upstream **platform** name is a legal/redistribution question, not a factory one. | Force the open decision: **scope rename vs same-name platform packages**, with Legal. Cost the dedup tax. |
| **Multiple versions / silent fallback** | Same as routing. If TL has `4.22.0` and npmjs has `4.22.1`, `^4.22.0` can skip TL. | Exclusive registry + lockfile; not smarter `optionalDependencies`. |
| **Native portability (no manylinux)** | v1 is linux-x64 / glibc / UBI. “linux-x64” is not every distro. UBI-built `.node` / ELF may fail on Ubuntu/Debian. | Support matrix must state **consumer ABI**: RHEL-family promised; other glibc distros best-effort. |
| **`@types/*`** | Omitted. TypeScript apps stay mixed/L1 for types even if runtime is closed. | Onboard `@types` as Tier A, **or** an explicit L3 exception: types may come from npmjs. |
| **Catalog cadence** | Recipe-per-version cannot track ~150–200 releases/month for a top-50 set. | Pin a **small version set**; security/backport on request (Lightwell). Do not promise “top 50 always current.” |
| **Build-script variance** | The recipe model *is* the answer and the scaling risk. Expect high fail rates past express/esbuild. | Staff like a recipe backlog, not like Fromager. Agents draft; humans gate. |
| **Workspaces, `git+https`, dist-tags, `bundledDependencies`** | Correctly not in v1; easy to read as “you forgot.” | List them in proposal **out of scope**. `dist-tags` (`latest`) on Pulp is a later product question. |

### How this relates to PoC vs GA

| Track | What “done” means |
| ----- | ----------------- |
| **PoC / first RH prod cut** | Factory builds from git, promote snapshot, release to Pulp, label `tl.compliance_level`, smoke `npm install` against **only** the TL registry for packages we published. |
| **GA** | Routing story for unscoped names, platform naming + Legal, ABI promise, catalog policy (what we keep current), `@types` / TS, lockfile migration docs, honest L3 timeline. |

Do not stall the factory PoC on this list. Do not let a green PoC imply the consumption problems are solved.

---

## Explicitly out of first cut (reconfirm for prod)

These were called out as non-goals for the **first PoC e2e**; several move to **required for prod** (see tables above):

| Item | First cut | Prod |
| ---- | --------- | ---- |
| cosign / package signing on every release | Deferred | **Required** — add `rh-sign-npm-packages` |
| Atlas SBOM upload | Deferred | When ProdSec requires (parity with Python) |
| Pulp Stage on PR | No | Optional product decision |
| Compliance inside consumer `.tgz` | No — sidecars + labels only | Keep unless proposal changes |

---

## Suggested order after e2e is green

1. Merge **konflux-release-data** (RPA, ECP, ReleasePlan) + Argo sync
2. First package PR → green on-pr + on-push → release to Pulp → manual `npm install` smoke
3. Signing + attestation path (`rh-sign-npm-packages`)
4. Pulp file repository + wire `PULP_FILE_REPOSITORY` for compliance JSON
5. Tighten EC / ITS ([ecp-policy-debt](./ecp-policy-debt.md)) — build + release ECPs
6. Pin RPA `pipelineRef.revision` to **`production`**
7. On-PR PipelineRun path filter for `.tekton/***` (test PLR/pipeline changes without a package bump)
8. `pulp-cli` (or shared util) instead of raw curl upload
9. Atlas / advisory / Stage — only when product or ProdSec asks
10. Rebuild/pin `npm-builder` + task bundles + `plumbing-utils`; align RSC tests with fail-closed empty upload
11. **Closure updater** — closure index OCI artifact, post-publish updater (conflict-only retry for PoC), parent propagation, Pulp label CAS; harden retry/idempotency before GA
12. Lightwell / multi-Pulp / agent onboarding — product track after RH prod is stable
