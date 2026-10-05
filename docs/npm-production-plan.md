# npm Trusted Libraries — production plan


| Field        | Value                                                                                                                                                                                                                                                                                   |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Status**   | Draft                                                                                                                                                                                                                                                                                   |
| **Date**     | 2026-10-05                                                                                                                                                                                                                                                                              |
| **Audience** | Lightwell / TL eng, RelEng, balor-fianna                                                                                                                                                                                                                                                |
| **Related**  | [proposal-npm-lightwell-onboarding](./proposal-npm-lightwell-onboarding.md), [prod_followup](./prod_followup.md), [ecp-policy-debt](./ecp-policy-debt.md), [poc_implementation_plan](./poc_implementation_plan.md), [plan-on-push-snapshot-release](./plan-on-push-snapshot-release.md) |


---

## Introduction

This document plans **Lightwell Validated** for npm: the smallest production path that follows the same Konflux shape Python remediated uses today — private cluster tenant, Application / Component / ReleasePlan / RPA, orchestrator-driven PipelineRuns — without waiting on other ecosystem migrations.

The GitHub PoC (`calungaproject/npm-registry`) already proved recipe → build → Pulp. Core Validated moves that factory onto **Lightwell**, with recipes living in a **GitLab build-config** repo — the npm sibling of [calunga-python](https://gitlab.cee.redhat.com/lightwell/lightwell-builds/build-configs/calunga-python), e.g. `https://gitlab.cee.redhat.com/lightwell/lightwell-builds/build-configs/npm-registry` (exact path TBD). That GitLab repo is **not** the GitHub PoC.

```text
GitLab build-configs/npm-registry  (recipes = build-config inventory)
  MR → human merge
       ↓
Ingest (Lightwell)
  recipe-aware code ingestion → durable source in lightwell-builds (or equivalent)
       ↓
Build (Konflux, private cluster)
  orchestrator creates PipelineRun on npm Validated application
  reuses Quay digests: builder image, config image, task bundles (from plumbing)
       ↓
Release (auto)
  ReleasePlan → RPA → sign / EC / publish to Pulp Validated
       ↓
Customer
  npm install --registry <validated javascript URL>
```

**Not in core:** migrating plumbing to GitLab/Lightwell repos; balor-fianna Fullsend (priority queue / recipe drafter); proxy/Remediated hardening; or Calunga Pac on-pr/on-push as the long-term factory trigger. Pac on the GitHub PoC may remain briefly as a bridge; the production spine is **ingest → build → auto-release**. Core proves the factory with **hand-authored / canary recipes** in the GitLab build-config repo.

This plan has two sections:

1. **[Core Validated](#1-core-validated)** — Konflux tenant artifacts, ingest, orchestrator, build after ingest, auto Pulp publish.
2. **[Post-core](#2-post-core)** — Next: balor-fianna Fullsend to populate recipes; then MR scratch, EC debt, proxy, Remediated, optional plumbing move.

---

## Guiding principles

1. **Same Konflux pattern as Python remediated today** — private cluster, tenant apps/components, ReleasePlan + RPA in konflux-release-data, orchestrator submits PipelineRuns. Do not invent an npm-only release culture.
2. **Build after code ingestion; release auto-on** — Validated build runs when ingest succeeds; ReleasePlan auto-release publishes to Pulp.
3. **Reuse Quay artifacts from plumbing** — builder image, config image, and Tekton task bundles stay on Quay digests. Plumbing stays on GitHub for core.
4. **Recipes are build-config** — GitLab `lightwell-builds/build-configs/npm-registry` (name TBD) holds per-package/version recipes, parallel to `build-configs/calunga-python`. Do not confuse with the GitHub PoC `npm-registry`.
5. **AI drafts; humans gate** — When balor-fianna Fullsend drafts recipe MRs, humans still review and merge; AI never signs or publishes.
6. **Source-built only** — factory never republishes npmjs tarballs.
7. **PoC debt is explicit** — close or reaffirm rows in [prod_followup](./prod_followup.md) as work lands.

---

## 1. Core Validated

**Goal:** On the private Lightwell Konflux cluster, a merged recipe is ingested, built, and auto-released to Pulp Validated — using existing Quay npm builder/config/bundle digests.

### Target shape (mirror Python remediated)

Stand up npm Konflux resources the same way Python remediated does on the private cluster today (Application, Component, ImageRepository, ReleasePlan, service account, RPA + ECP in RelEng), in a **new** tenant — not shared with Python.


| Layer                       | What to add                                                                                             |
| --------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Tenant**                  | New `lightwell-npm-tenant` on `stone-prod-p01` (same private cluster as `lightwell-python-tenant`)      |
| **Application / Component** | e.g. `npm-validated-build` (names TBD)                                                                  |
| **ImageRepository**         | OCI output for `.tgz` / factory artifact                                                                |
| **ReleasePlan**             | Auto-release **on** → RelEng target                                                                     |
| **RPA + ECP**               | konflux-release-data product admission; release pipeline pushes to Pulp Validated javascript index      |
| **Orchestrator**            | `javascript` / `npm` ecosystem commands that create PipelineRuns with the right app/component/SA labels |


### Core phases


| Phase  | Scope                                                     |
| ------ | --------------------------------------------------------- |
| **P1** | Konflux + RelEng artifacts on private cluster             |
| **P2** | Ingest understands npm recipes                            |
| **P3** | Orchestrator + build pipeline (Quay digests) after ingest |
| **P4** | Auto-release to Pulp Validated (sign / EC / smoke)        |
| **P5** | Minimal install contract docs                             |


#### P1 — Konflux artifacts on private cluster


| Activity                                                            | Notes                                                                                                    |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **C-P1.1** Create tenant `lightwell-npm-tenant` on `stone-prod-p01` | Same private cluster as `lightwell-python-tenant`; new namespace via tenants-config / `add-namespace.sh` |
| **C-P1.2** Application + Component + ImageRepository                | GitOps under `tenants-config` (or equivalent); build SA                                                  |
| **C-P1.3** ReleasePlan with **auto-release: true**                  | Points at new RPA name                                                                                   |
| **C-P1.4** RPA + ECP in konflux-release-data                        | Release pipeline for npm → Pulp Validated; SA mapping RelEng ↔ tenant                                    |
| **C-P1.5** Network: cluster → GitLab                                | Clone lightwell-builds + GitLab build-configs/npm-registry as needed                                     |
| **C-P1.6** Quay pull of plumbing digests from private cluster       | Builder image, config image, task bundles — **no plumbing repo move**                                    |


**Exit criteria:** Empty or canary PipelineRun can schedule on the new app; ReleasePlan/RPA exist and reconcile.

#### P2 — Ingest for npm recipes


| Activity                                                        | Notes                                                                                                                      |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **C-P2.1** Treat GitLab build-configs/npm-registry as inventory | Same role as calunga-python; per `packages/<name>/<version>/` (manifest + entrypoint + smoke). Not the GitHub PoC.         |
| **C-P2.2** Extend Lightwell ingestion for npm                   | Prefer parametrizing shared ingest patterns; expect an npm-capable pipeline (not a thin rename of python-sdist-only tasks) |
| **C-P2.3** Durable source output                                | Land in lightwell-builds (or equivalent) so the build clones a known ref — same idea as Python ingest tags                 |
| **C-P2.4** Wire merge-to-default (or explicit import) → ingest  | Production path only for core; scratch-on-MR is post-core                                                                  |


**Exit criteria:** Merging a canary recipe produces an ingested source ref the build can clone.

#### P3 — Orchestrator + build after ingest


| Activity                                                  | Notes                                                                                                                 |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **C-P3.1** Add orchestrator ecosystem for javascript/npm  | Create PipelineRun on the Validated application                                                                       |
| **C-P3.2** Build pipeline                                 | Recipe entrypoint + smoke; pin **builder image**, **config image**, and **task bundles by Quay digest** from plumbing |
| **C-P3.3** Trigger Validated build when ingest succeeds   | Primary factory trigger — not Pac on-push                                                                             |
| **C-P3.4** SCRATCH / no-release target (optional in core) | Useful for dry-runs; MR scratch validation can wait for post-core                                                     |


**Exit criteria:** Post-ingest PipelineRun builds a canary package to Quay using plumbing digests.

#### P4 — Auto-release to Pulp


| Activity                                                     | Notes                                                                           |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| **C-P4.1** Release pipeline path for npm packages            | Extract → sign → EC → Pulp Validated (reuse / adapt existing npm release tasks) |
| **C-P4.2** Auto-release on                                   | Snapshot from Validated build admits via RPA without manual promote for core GA |
| **C-P4.3** Signing secret + Pulp credentials on private path | Least privilege vs shared Python secrets as RelEng directs                      |
| **C-P4.4** Post-release smoke                                | `npm install --registry <validated URL>` for canary                             |


**Exit criteria:** Canary package installable from Pulp Validated after an ingest-triggered build.

#### P5 — Minimal install contract


| Activity                                                          | Notes                                     |
| ----------------------------------------------------------------- | ----------------------------------------- |
| **C-P5.1** Document Validated registry URL + Pulp-only + lockfile | Supported prod story for first GA         |
| **C-P5.2** Note platform `@calunga/…` resolution from TL registry | No silent npmjs for TL platform optionals |


**Exit criteria:** Short consumer doc; no claim of full proxy/Remediated yet.

### Core — what we are not doing yet


| Out of core                                            | Why                                                                                                                    |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Move plumbing git to GitLab / Lightwell                | Quay digests are enough for GA                                                                                         |
| Pac on-pr / on-push as production factory              | Replaced by ingest → orchestrator → auto-release                                                                       |
| balor-fianna Fullsend (priority queue, recipe drafter) | **Next priority after core** — populates GitLab build-configs/npm-registry at scale; not required to prove the factory |
| Closure updater, proxy chain, Remediated Pulp          | Later post-core                                                                                                        |
| Atlas / advisory parity with Calunga Python            | Add only if product requires for npm Validated index                                                                   |


### Core Validated — phase effort

Rough focused eng-days with AI agents (order-of-magnitude; refine as spikes land).


| Phase  | Scope                             | Complexity (0–10) | Effort (eng-days)               |
| ------ | --------------------------------- | ----------------- | ------------------------------- |
| **P1** | Konflux + RelEng artifacts        | 7                 | 12–20                           |
| **P2** | npm recipe ingest                 | 7                 | 10–18                           |
| **P3** | Orchestrator + build after ingest | 7                 | 12–20                           |
| **P4** | Auto-release + sign/EC/smoke      | 6                 | 10–16                           |
| **P5** | Install docs                      | 2                 | 2–3                             |
|        | **Core Validated total**          |                   | **≈ 46–77** (midpoint **≈ 60**) |


**One engineer:** about **60 focused eng-days** (~3 calendar months sequential, less with RelEng overlap).  
**Team of two:** one on **P1+P4** (Konflux/RelEng/release), one on **P2+P3** (ingest/orchestrator/build).

---

## 2. Post-core

After Validated canaries flow ingest → build → Pulp.

### First post-core priority — balor-fianna Fullsend (populate recipes)

Fullsend (priority queue + recipe drafter work that lived in the recipe kitchen) is being integrated as a **component of balor-fianna**. That path opens MRs against the **GitLab** build-config repo (`lightwell-builds/build-configs/npm-registry`, sibling of calunga-python) so the catalog grows without hand-authoring every recipe.

This is **not** a core Factory requirement. Core only needs enough canary recipes in that GitLab repo to prove ingest → build → auto-release. Fullsend is the **next high priority after core** so Validated can be populated at scale.


| Activity | Notes                                                                       |
| -------- | --------------------------------------------------------------------------- |
| **F-1**  | Move / wire priority queue into balor-fianna                                |
| **F-2**  | Recipe drafter opens human-gated MRs to GitLab build-configs/npm-registry   |
| **F-3**  | Attack gate (or equivalent) before merge / factory                          |
| **F-4**  | E2E: queue → drafted recipe MR → merge → existing core ingest/build/release |


**Exit criteria:** balor-fianna can draft and land recipe MRs that the core factory already knows how to ingest and publish.

### Later post-core


| Phase  | Scope                                                                 |
| ------ | --------------------------------------------------------------------- |
| **P1** | Scratch validate on recipe MR (optional consolidation of old on-pr)   |
| **P2** | EC debt / compliance sidecars / closure updater                       |
| **P3** | Consumer proxy + Legal platform names + `@types`                      |
| **P4** | Remediated stream (same build spine, patched ref + different Pulp RP) |
| **P5** | Optional: move plumbing npm surfaces to GitLab                        |


#### Notes

- **MR vs post-ingest:** Core only requires build after ingest. Later post-core can add orchestrator **SCRATCH** on recipe MR (no Pulp) so bad recipes fail before merge — that replaces Pac on-pr without keeping two Pac pipelines.
- **Remediated:** Same Application/pipeline family where possible; different git ref and ReleasePlan/RPA (stage/promote as needed). Not a second Pac factory.
- **Plumbing move:** Only when VPN-only / ownership policy requires it; not a Validated blocker.

### Post-core effort (rough)


| Phase                                    | Effort (eng-days) |
| ---------------------------------------- | ----------------- |
| balor-fianna Fullsend (populate recipes) | 12–22             |
| MR scratch                               | 3–6               |
| EC / compliance / closure                | 15–25             |
| Proxy + Legal + `@types`                 | 9–17              |
| Remediated multi-Pulp                    | 8–14              |
| Optional plumbing → GitLab               | 10–16             |
| **Post-core (excl. optional plumbing)**  | **≈ 47–84**       |


---

## Explicit non-goals for first Validated GA


| Item                                              | Status                                                                       |
| ------------------------------------------------- | ---------------------------------------------------------------------------- |
| Plumbing git migration off GitHub                 | Out of core — Quay digests only                                              |
| Pac on-pr / on-push as the production trigger     | Replaced by ingest → orchestrator                                            |
| Full dependency closure (L3 at scale)             | Years-scale catalog                                                          |
| Byte-identical to npmjs                           | Out of scope                                                                 |
| All arches / musl                                 | Later                                                                        |
| AI in signing or hermetic LLM egress              | Forbidden                                                                    |
| balor-fianna Fullsend / recipe kitchen automation | **After core** — next priority to populate GitLab build-configs/npm-registry |
| Remediated Pulp / private customer repos          | Later post-core                                                              |
| Full consumer proxy                               | Later post-core                                                              |
| Blocking on other ecosystem validated cutovers    | Not required                                                                 |


---

## Tracking

- **PoC debt register:** update [prod_followup](./prod_followup.md) when a shortcut lands or is intentionally kept.
- **EC debt:** update [ecp-policy-debt](./ecp-policy-debt.md) when excludes change.
- **This plan:** mark phases done with date + link to MR.

---

## Open questions

1. Exact GitLab path for the npm build-config repo — confirm `lightwell/lightwell-builds/build-configs/npm-registry` (vs another name under `build-configs/`).
2. Exact Application / ReleasePlan / RPA names and Pulp repository for npm Validated (reuse `…/javascript/` vs new Lightwell path)?
3. Ingest output layout: lightwell-builds git layout for npm vs recipe+upstream git fetch at build time?
4. RSC release pipeline: Lightwell fork revision vs upstream — pin digest/branch explicitly.
5. Is MR-time SCRATCH validation required before first external consumers, or only after Fullsend starts drafting at volume?
6. Signing/attest: match Python Lightwell release tasks closely, or keep GitHub PoC release task set with private-cluster secrets?
7. balor-fianna Fullsend ownership boundaries vs remaining npm-recipe-kitchen surfaces (if any)?
8. Whether/when to archive or freeze the GitHub PoC `calungaproject/npm-registry` once GitLab build-config + Lightwell factory are live.

---

## Appendix A — Core activity checklist


| ID         | Activity                                                     |
| ---------- | ------------------------------------------------------------ |
| **C-P1.1** | Create `lightwell-npm-tenant` on `stone-prod-p01`            |
| **C-P1.2** | Application + Component + ImageRepository                    |
| **C-P1.3** | ReleasePlan auto-release on                                  |
| **C-P1.4** | RPA + ECP in konflux-release-data                            |
| **C-P1.5** | Cluster → GitLab network                                     |
| **C-P1.6** | Quay pull of plumbing builder / config / bundle digests      |
| **C-P2.1** | GitLab build-configs/npm-registry inventory (not GitHub PoC) |
| **C-P2.2** | npm-capable ingest pipeline                                  |
| **C-P2.3** | Durable source ref after ingest                              |
| **C-P2.4** | Merge/import → ingest wiring                                 |
| **C-P3.1** | Orchestrator javascript/npm commands                         |
| **C-P3.2** | Build pipeline pinned to Quay digests                        |
| **C-P3.3** | Trigger build after successful ingest                        |
| **C-P3.4** | Optional SCRATCH target                                      |
| **C-P4.1** | Release pipeline npm → Pulp                                  |
| **C-P4.2** | Auto-release verified                                        |
| **C-P4.3** | Signing + Pulp secrets                                       |
| **C-P4.4** | Post-release smoke                                           |
| **C-P5.1** | Install contract docs                                        |
| **C-P5.2** | Platform package registry notes                              |


