# npm Trusted Libraries — production plan (first draft)

| Field | Value |
| ----- | ----- |
| **Status** | Draft |
| **Date** | 2026-09-22 |
| **Audience** | Lightwell / TL eng, RelEng, Fullsend |
| **Related** | [proposal-npm-lightwell-onboarding](./proposal-npm-lightwell-onboarding.md), [prod_followup](./prod_followup.md), [ecp-policy-debt](./ecp-policy-debt.md), [poc_implementation_plan](./poc_implementation_plan.md), [plan-on-push-snapshot-release](./plan-on-push-snapshot-release.md) |

---

## Introduction

This document plans the move from the **npm Trusted Libraries PoC** to a **production-ready Lightwell Validated** path, then onward to hardening and **Remediated**.

The PoC proved the factory spine: recipe PR → Konflux on-pr build → on-push promote → release to Pulp → `npm install` against the TL registry. Production means that spine is trustworthy end-to-end for consumers, not only that a package can be published.

**End-to-end surface we are productizing:**

```text
Ingestion (Fullsend)
  priority queue → recipe drafter → attack gate → PR to npm-registry
       ↓
Factory (Konflux)
  build · smoke · SBOM · EC · attest · sign · release
       ↓
Storage (Pulp)
  Validated catalog (existing npm-registry / javascript/)
  (+ later Remediated repo)
       ↓
Customer consumption
  one .npmrc registry= URL → proxy / virtual repo:
    remediated → 404 → validated → 404 → customer fallback or registry.npmjs.org
```

**Assumption:** the Python Lightwell factory path (Calunga wheels → Lightwell) is owned by a separate factory team and is **nearly done**. This npm plan **starts after that work**. The Python precondition is listed under core Validated for sequencing awareness, but it is **not included in effort estimates**.

This plan has two work sections:

1. **[Core Validated work](#1-core-validated-work)** — private cluster, GitLab, Fullsend, sign/attest/release, minimum EC, Pulp-only install contract.
2. **[Post-core Validated hardening and Remediated](#2-post-core-validated-hardening-and-remediated-work)** — closure updater, EC debt removal, full proxy/Legal, Remediated stream, optional plumbing→GitLab.

Phase IDs restart at **P1** in each section. Activity-level effort that feeds the phase tables is in the [appendix](#appendix-a-activity-level-effort-estimates).

---

## Guiding principles

1. **Reuse Python Lightwell patterns** — signing, Pulp upload, EC parentage, RPA revision pins, Quay visibility. Do not invent an npm-only release culture.
2. **PoC debt is explicit** — close or reaffirm rows in [prod_followup](./prod_followup.md) as work lands.
3. **Private cluster + GitLab are hard requirements for Validated GA** — not optional posture.
4. **AI drafts; humans gate** — Fullsend never signs, publishes, or merges without human review.
5. **Source-built only** — factory never republishes npmjs tarballs.
6. **Validated GA first** — ship a trustworthy Validated catalog with a narrow install contract; harden and add Remediated after.

---

## 1. Core Validated work

**Goal:** Validated GA on private Konflux + GitLab `npm-registry`, with Fullsend opening MRs there, signed/attested packages on Pulp, and a supported **Pulp-only + lockfile** install story.

### Precondition (in scope, not estimated)

Owned by the factory team; expected complete (or nearly so) before this plan’s estimates start.

| Item | Outcome |
| ---- | ------- |
| Calunga Python wheels on Lightwell remediated (or equivalent) path | npm copies signing, RPA `production`, Pulp, Quay, EC patterns |
| Python reference docs for RelEng / Lightwell ownership | Cluster/tenant and SA mapping known |

### Core phases

| Phase | Scope |
| ----- | ----- |
| **P1** | Private Konflux cluster + GitLab network access |
| **P2** | `npm-registry` on GitLab + Fullsend agents retargeted |
| **P3** | Factory / release hardening for Validated GA (sign, attest, RPA, smoke, digests) |
| **P4** | Minimum EC / Conforma (ITS required, structural + trusted tasks) |
| **P5** | Validated install contract (Pulp-only + lockfile) |

#### P1 — Private cluster + GitLab network

Migrate npm Konflux workloads from a public cluster to a **private** cluster that reaches **GitLab on the private network (VPN)**.

| Activity | Notes |
| -------- | ----- |
| **C-P1.1** Choose target private cluster / tenant | Align with Lightwell / RelEng posture from Python |
| **C-P1.2** Move or recreate `calunga-npm-registry-main` Application/Component | PipelineRuns, ImageRepository, ITS |
| **C-P1.3** Network: cluster → GitLab (clone, PAC, status) | VPN / private DNS / allowlists |
| **C-P1.4** Quay pull/push from private cluster | Builder images, task bundles, OCI `.npm` |
| **C-P1.5** Release path private tenant → RelEng | SA mapping; `redhat-user-workloads-pull` if Quay private |
| **C-P1.6** Flip Quay ImageRepository to **private** when SA can pull | Close PoC public OCI exposure |
| **C-P1.7** Cutover runbook | Dual-run green build; decommission public wiring |

**Exit criteria:** Green on-pr / on-push on private cluster (GitHub remote acceptable only as a brief bridge until P2).

#### P2 — `npm-registry` + Fullsend → GitLab

| Activity | Notes |
| -------- | ----- |
| **C-P2.1** Create GitLab project; protect `main` | Mirror history; approval rules |
| **C-P2.2** Retarget Konflux PAC / PipelineRuns to GitLab | Webhooks, secrets, CEL filters |
| **C-P2.3** Update docs / recipe kitchen links | CONTRIBUTING, proposal repo name |
| **C-P2.4** Archive or redirect GitHub `npm-registry` | Read-only / notice |
| **C-P2.5** Priority queue agent → GitLab issues/MRs | Jira, Pulp gaps, community, closure |
| **C-P2.6** Recipe drafter opens GitLab MRs | Human merge only |
| **C-P2.7** Attack gate on GitLab MRs before on-pr | Fail/flag blocks factory |
| **C-P2.8** E2E dry-run: queue → MR → merge → on-pr | On private cluster |

**Exit criteria:** Fullsend-drafted recipe MR on GitLab builds on-pr on the private cluster.

#### P3 — Factory / release hardening (Validated GA)

| Activity | Notes |
| -------- | ----- |
| **C-P3.1** Add `rh-sign-npm-packages` (mirror Python) | Gate on signing secret |
| **C-P3.2** Full attest per `.tgz` at release | Align with Python attestations |
| **C-P3.3** Pin RPA `pipelineRef.revision` to `production` | After RSC weekly promote |
| **C-P3.4** Merge/sync konflux-release-data RPA + ReleasePlan + ECP | Argo reconcile |
| **C-P3.5** ProdSec exception process | Formal exception for temporary onboarding ECP |
| **C-P3.6** Post-release smoke (automate preferred) | `npm install --registry …/javascript/` |
| **C-P3.7** Confirm Pulp ACL / secret least privilege | Shared vs separate vs Python |
| **C-P3.8** Pin builder image + task bundles by digest | Rebuild as needed |
| **C-P3.9** Consumer-facing install docs | Registry URL, L1/L2/L3 meaning, no silent npmjs for TL platform optionals |

**Exit criteria:** Signed, attested package on Pulp Validated; smoke green; RPA on `production`.

#### P4 — Minimum EC / Conforma

| Activity | Notes |
| -------- | ----- |
| **C-P4.1** ITS **required** (`optional: "false"`) | On private cluster |
| **C-P4.2** Keep/document structural `build-npm` excludes | OCI factory shape |
| **C-P4.3** Converge release ECP label waivers | Volatile `exclude` + `effectiveUntil` |
| **C-P4.4** Trusted-task allowlist current | Builder image via lint → trusted params |

**Exit criteria:** Required ITS passes on real package builds; structural excludes intentional only.

#### P5 — Validated install contract

| Activity | Notes |
| -------- | ----- |
| **C-P5.1** Ship Validated Pulp-only + lockfile reference config | Supported prod story for first GA |
| **C-P5.2** Lockfile migration docs | One-time `integrity` / `resolved` refresh |
| **C-P5.3** Explicitly reject L1 mixed-registry as supported prod | L1 = catalog KPI only |
| **C-P5.4** Consumer support matrix (lite) | linux-x64 / glibc / UBI promised |

**Exit criteria:** Written install contract; no claim of safe mixed npmjs+TL without lockfile/proxy (proxy is post-core).

### Core Validated — phase effort

Roll-up from [Appendix A.1](#a1-core-validated-activities). Complexity = hardest activity in the phase. Effort = focused eng-days with Cursor agents. **Precondition excluded.**

| Phase | Scope | Complexity (0–10) | Effort (eng-days) |
| ----- | ----- | ----------------: | ----------------: |
| **P1** | Private cluster + GitLab network | 8 | 27–42 |
| **P2** | GitLab `npm-registry` + Fullsend | 7 | 23–34 |
| **P3** | Sign · attest · RPA · smoke · digests · docs | 7 | 24–37 |
| **P4** | Minimum EC (ITS + structural + trusted tasks) | 3 | 3.5–5.5 |
| **P5** | Pulp-only + lockfile install contract | 4 | 5–8 |
| | **Core Validated total** | | **≈ 85–125** (midpoint **≈ 105**) |

**One engineer (Cursor agents):** about **105 focused eng-days** for core Validated — roughly **5–6 calendar months** if mostly sequential, or about **3–4 months** if P1/P2 and P3–P5 overlap while network and RelEng waits run in parallel.

**Team of three (Cursor agents):** about **3–4 calendar months** for core Validated (practical split: one on **P1 + release admission**, one on **P2 Fullsend/GitLab**, one on **P3–P5** factory/EC/docs), assuming network, signing secrets, and RelEng SA access are started early.

---

## 2. Post-core Validated hardening and Remediated work

**Goal:** After Validated GA — harden compliance/ops, close EC debt when gates exist, ship the full consumer proxy story, open Remediated Pulp, optionally move plumbing npm artifacts to GitLab.

### Post-core phases

| Phase | Scope |
| ----- | ----- |
| **P1** | Factory / compliance hardening (sidecars, closure updater, pulp-cli, tekton filter) |
| **P2** | EC debt exclude removal (when SBOM/CVE/SAST real) |
| **P3** | Full consumer proxy + Legal platform names + `@types` |
| **P4** | Remediated stream + multi-Pulp |
| **P5** | Optional: plumbing npm artifacts → GitLab |

#### P1 — Factory / compliance hardening

| Activity | Notes |
| -------- | ----- |
| **H-P1.1** Pulp file repository + `PULP_FILE_REPOSITORY` | Adjacent `*.tl-compliance.json`; fail release on sidecar failure when required |
| **H-P1.2** Prefer `pulp-cli` / shared util vs raw curl | Maintainability |
| **H-P1.3** On-PR path filter for `.tekton/**` | Test PLR edits without package bump |
| **H-P1.4** Closure updater (OCI index + Pulp CAS) | Parent L1→L3 propagation |

#### P2 — EC debt close-out

| Activity | Notes |
| -------- | ----- |
| **H-P2.1** Remove debt excludes when gates are real | `sbom.found`, CVE, SAST/clair — same cadence as Python |

#### P3 — Full consumer proxy and catalog policy

| Activity | Notes |
| -------- | ----- |
| **H-P3.1** Design / document proxy chain | remediated → validated → fallback |
| **H-P3.2** Decide who hosts the proxy | Customer Artifactory/Nexus/Pulp vs RH-managed |
| **H-P3.3** Platform package naming + Legal | `@calunga/…` vs upstream platform names |
| **H-P3.4** `@types/*` policy | Onboard Tier A or explicit npmjs exception |

#### P4 — Remediated stream + multi-Pulp

| Activity | Notes |
| -------- | ----- |
| **H-P4.1** Create Remediated Pulp repo + distribution | Separate `base_path` |
| **H-P4.2** Wire `stream` → `pulpRepository` | Same factory; different publish target |
| **H-P4.3** Close Remediated version identity decision | e.g. `1.2.4-rhlw.1` |
| **H-P4.4** Document Remediated-first proxy + overrides | App-level pin story |
| **H-P4.5** Lightwell private / per-customer repos | Paid track (large) |

#### P5 — Optional: plumbing npm → GitLab

| Activity | Notes |
| -------- | ----- |
| **H-P5.1** Inventory plumbing npm surfaces | `npm-builder`, tasks, utils |
| **H-P5.2** Decide GitLab vs keep GitHub fetch | Cost vs VPN-only policy |
| **H-P5.3** Mirror, retarget digests, rebuild bundles | If migrating |
| **H-P5.4** Update RSC / konflux-release-data refs | No broken pulls |

### Post-core — phase effort

Roll-up from [Appendix A.2](#a2-post-core-validated-hardening--remediated-activities). **H-P4.5** (private customer repos) is shown separately — often a distinct product track.

| Phase | Scope | Complexity (0–10) | Effort (eng-days) |
| ----- | ----- | ----------------: | ----------------: |
| **P1** | Compliance sidecars · closure updater · pulp-cli · tekton filter | 9 | 19–28 |
| **P2** | EC debt exclude removal | 7 | 6–9 |
| **P3** | Full proxy · Legal · `@types` | 6 | 9–17 |
| **P4** | Remediated multi-Pulp (without private-customer repos) | 5 | 8–14 |
| **P4+** | Lightwell private / per-customer repos (**H-P4.5**) | 8 | 11–19 |
| **P5** | Optional plumbing → GitLab | 7 | 10–16 |
| | **Post-core total (excl. P4+ and optional P5)** | | **≈ 42–68** (midpoint **≈ 55**) |
| | **Post-core + optional P5 (excl. P4+)** | | **≈ 52–84** (midpoint **≈ 68**) |

**One engineer (Cursor agents):** about **55 focused eng-days** for post-core without private-customer repos or plumbing migration — roughly **2.5–3 calendar months** sequential, or about **6–8 weeks** with overlap. Add **~1.5–2 eng-weeks** for optional P5; add **~2–4 eng-weeks** calendar stretch for **H-P4.5** (often blocked on product/sales, not eng).

**Team of three (Cursor agents):** about **6–8 calendar weeks** for post-core (excl. P4+ and P5); about **8–10 weeks** including optional plumbing→GitLab; private-customer repos (**P4+**) as a follow-on product track.

---

## Explicit non-goals for first Validated GA

| Item | Status |
| ---- | ------ |
| Full dependency closure for large apps (L3 at scale) | Years-scale catalog; not a factory gate |
| Top-50 always-current cadence | Pin a small version set; backport on request |
| Byte-identical to npmjs | Out of scope |
| All arches / musl | v1.1+ |
| AI in signing or hermetic LLM egress | Forbidden |
| Lightwell redistributing entire npmjs via proxy | Prefer customer-hosted fallback remote |
| Remediated Pulp / private customer repos | Post-core |
| Plumbing → GitLab | Post-core optional |

---

## Tracking

- **PoC debt register:** update [prod_followup](./prod_followup.md) when a shortcut lands or is intentionally kept.
- **EC debt:** update [ecp-policy-debt](./ecp-policy-debt.md) when excludes change.
- **This plan:** mark phases done with date + link to MR.

---

## Open questions (carry into next draft)

1. Exact private cluster / tenant names and cutover window.
2. GitLab project path and ownership for `npm-registry`.
3. Remediated version identity final choice (`-rhlw` prerelease vs alternatives).
4. Who operates the reference consumer proxy (docs-only vs RH-managed virtual repo) — post-core.
5. Whether npm attestations on Pulp match Python PEP 740 sidecars exactly or use a parallel store.

---

## Appendix A — Activity-level effort estimates

Per-activity breakdown that rolls up into the phase tables in [§1](#1-core-validated-work) and [§2](#2-post-core-validated-hardening-and-remediated-work). Complexity is 0 (trivial) to 10 (very hard). Effort is focused eng-days for an engineer equipped with Cursor agents.

### A.1 Core Validated activities

| ID | Activity | Complexity (0–10) | Effort (eng-days) |
| -- | -------- | ----------------: | ----------------: |
| **C-P1.1** | Choose private cluster / tenant | 3 | 1–1.5 |
| **C-P1.2** | Move/recreate Konflux npm Application/Component | 7 | 6–9 |
| **C-P1.3** | Cluster ↔ GitLab network (VPN, PAC, DNS) | 8 | 7–11 |
| **C-P1.4** | Quay pull/push from private cluster | 5 | 3–4.5 |
| **C-P1.5** | Release path private tenant → RelEng | 7 | 5–7.5 |
| **C-P1.6** | Flip Quay ImageRepository to private | 5 | 2–4 |
| **C-P1.7** | Cutover runbook | 6 | 3–4.5 |
| **C-P2.1** | Create GitLab `npm-registry` project + protect main | 3 | 1–1.5 |
| **C-P2.2** | Retarget Konflux PAC / PipelineRuns to GitLab | 6 | 3–4.5 |
| **C-P2.3** | Update docs / recipe kitchen links | 2 | 1–1.5 |
| **C-P2.4** | Archive or redirect GitHub repo | 1 | 0.5–1 |
| **C-P2.5** | Priority queue agent → GitLab issues/MRs | 6 | 4.5–6 |
| **C-P2.6** | Recipe drafter opens GitLab MRs | 7 | 6–9 |
| **C-P2.7** | Attack gate on GitLab MRs before on-pr | 6 | 4.5–6 |
| **C-P2.8** | Fullsend → merge → on-pr dry-run | 4 | 2–4 |
| **C-P3.1** | Add `rh-sign-npm-packages` | 7 | 6–9 |
| **C-P3.2** | Full attest per `.tgz` at release | 5 | 3–4.5 |
| **C-P3.3** | Pin RPA revision to `production` | 2 | 0.5–1 |
| **C-P3.4** | Merge/sync konflux-release-data RPA/ReleasePlan/ECP | 5 | 3–4.5 |
| **C-P3.5** | ProdSec exception process | 2 | 1–1.5 |
| **C-P3.6** | Post-release smoke automation | 4 | 2–4 |
| **C-P3.7** | Pulp ACL / secret least privilege | 3 | 1–1.5 |
| **C-P3.8** | Pin builder + task bundles by digest | 4 | 1.5–3 |
| **C-P3.9** | Consumer-facing install docs | 2 | 1.5–2 |
| **C-P4.1** | Confirm ITS required on private cluster | 1 | 0.5–1 |
| **C-P4.2** | Keep/document structural `build-npm` excludes | 2 | 1 |
| **C-P4.3** | Converge release ECP label waivers | 3 | 1–1.5 |
| **C-P4.4** | Trusted-task allowlist current | 3 | 1–1.5 |
| **C-P5.1** | Validated Pulp-only + lockfile reference config | 4 | 2–4 |
| **C-P5.2** | Lockfile migration docs | 2 | 1–1.5 |
| **C-P5.3** | Reject L1 mixed-registry as supported prod | 1 | 0.5–1 |
| **C-P5.4** | Consumer support matrix (lite) | 2 | 1–1.5 |

**Core roll-up:** P1 27–42 · P2 23–34 · P3 24–37 · P4 3.5–5.5 · P5 5–8 · **total ≈ 85–125 eng-days** (midpoint ≈ 105).

### A.2 Post-core Validated hardening + Remediated activities

| ID | Activity | Complexity (0–10) | Effort (eng-days) |
| -- | -------- | ----------------: | ----------------: |
| **H-P1.1** | Pulp file repo + compliance sidecar upload | 5 | 3–4.5 |
| **H-P1.2** | `pulp-cli` / shared util vs raw curl | 4 | 2–4 |
| **H-P1.3** | On-PR path filter for `.tekton/**` | 3 | 1–1.5 |
| **H-P1.4** | Closure updater (OCI index + Pulp CAS) | 9 | 11–15 |
| **H-P2.1** | Remove EC debt excludes when gates real | 7 | 6–9 |
| **H-P3.1** | Design / document proxy chain | 4 | 2–4 |
| **H-P3.2** | Decide who hosts the proxy | 5 | 2–4 |
| **H-P3.3** | Platform package naming + Legal | 6 | 4–7.5 |
| **H-P3.4** | `@types/*` policy | 3 | 1–1.5 |
| **H-P4.1** | Create Remediated Pulp repo + distribution | 4 | 2–4 |
| **H-P4.2** | Wire `stream` → `pulpRepository` | 5 | 3–4.5 |
| **H-P4.3** | Close Remediated version identity decision | 5 | 2–4 |
| **H-P4.4** | Document Remediated-first proxy + overrides | 3 | 1–1.5 |
| **H-P4.5** | Lightwell private / per-customer repos | 8 | 11–19 |
| **H-P5.1** | Inventory plumbing npm surfaces | 2 | 1 |
| **H-P5.2** | Decide GitLab vs keep GitHub for plumbing | 3 | 1–1.5 |
| **H-P5.3** | Mirror plumbing npm → GitLab, rebuild bundles | 7 | 6–9 |
| **H-P5.4** | Update RSC / konflux-release-data refs | 4 | 2–4 |

**Post-core roll-up (excl. H-P4.5 and H-P5.*):** P1 19–28 · P2 6–9 · P3 9–17 · P4 8–14 · **total ≈ 42–68 eng-days** (midpoint ≈ 55).
