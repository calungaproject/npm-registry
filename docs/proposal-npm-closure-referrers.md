# npm Closure Graph via OCI Referrers API

Status: Draft proposal for discussion
Date: 2026-10-27
Related: `update-npm-closure` / `upload-npm-closure` (current implementation, release-service-catalog + slan-cuan)

## Problem

The current npm closure tracking (per-package `*.tl-compliance.json` docs + a single
global `npm-closure-index` artifact on Quay) uses mutable tags with optimistic
CAS-by-retry. There is no atomic compare-and-swap at the registry, so concurrent
writers can silently lose index updates; contention funnels through one global
index tag that can also drift and must be rebuilt via `rebalance`. Derived state
(computed compliance levels, gap lists) is stored alongside raw facts, which is
what forces mutation and locking in the first place.

## Proposal

Replace the mutable doc/index scheme with an **append-only graph of OCI referrers
artifacts**, stored in Quay (which supports the real Referrers API v1).

### Core invariants

1. **Facts only, computed on read.** Store dependency edges, build markers, and
   release markers as referrers. Compliance levels (L1/L2/L3) are derived during
   the closure walk, never stored as mutable state.
2. **Reproducible artifacts.** Every referrer is byte-deterministic (canonical
   JSON, sorted keys, no wall-clock timestamps, no revision counters).
   Timestamps, where needed (build metadata), must be derived from
   reproducible inputs (e.g. the recipe's git commit timestamp), never the
   pipeline's wall clock, so duplicate/retried builds produce the identical
   digest and dedup. Racing writers producing the same fact produce the
   same digest; the registry dedups them. Lost updates are impossible by
   construction.
3. **One referrer per relationship.** Finest granularity: a single
   `parent -> child` edge is one referrer. Two processes adding *different*
   edges never collide; conflicts only arise on transient API failures or
   subject movement, handled by replay.
4. **Append-only / monotone.** Closures are only valid for validated builds and
   are keyed by purl (name@version). A CVE fix produces a new version = new
   purl = new edges; the old edges become irrelevant history, never wrong data.
   Retraction shrinks to a singular bad relationship, handled by a
   tombstone referrer scoped to that one edge. **Tombstones never lower
   compliance**: retracting an edge only removes a dependency requirement,
   so levels can only stay the same or rise. Monotonicity — and therefore
   the L3/level marker cache — survives retraction intact.

### Closure semantics: as-built (sticky) — OPEN QUESTION

Validated builds are static: the artifact's bytes and its packed
package.json never change. The closure graph is therefore a representation
of **how the thing was built**: edges record the dep versions resolved at
build time, and "L3" means "this build's dependency set was fully validated
*as built*."

**Chosen semantics: sticky levels.** Once a purl reaches L3 it stays L3.
Levels move only upward (L1 -> L2 -> L3 as missing deps land and are
validated). This restores monotonicity: the L3 marker is genuinely cacheable,
the Pulp label max-register is sound (no regression to express), and
concurrent releases converge because every release only ever *adds* validated
content.

**Fully-qualified implications of stickiness (must be understood by every
consumer):**

- A reader of "L3" learns "this build's deps were all validated as built" —
  **never** "all currently-max-satisfying versions are validated." The graph
  is silent, by design, about newer versions of dependencies that satisfy an
  open range.
- If `foo@1.4.0` supersedes the validated `foo@1.2.0` and carries a CVE, the
  closure graph will not re-open the parent's level. Detection of
  "newer satisfying version with a CVE" is a **freshness question about the
  spec** (`name@range`), not a closure question — it belongs to spec-based
  VBT matching (OSV/novabucks-style against package.json facts), not to
  compliance levels. Consumers must not use closure level as a
  security-freshness signal.
- Open ranges (`^1.2.0`) are recorded as the spec in the edge content, with
  the resolved version in the edge's purl. The spec is what VBT matching
  should consume; the resolved purl is what closure walks consume.
- Alternative considered and rejected: "flappy" semantics (re-walk every
  parent with an open range whenever any dep releases, levels can regress
  L3 -> L2/L1). This requires unbounded re-computation, is non-monotone
  (kills the L3 cache and the max-register), and tracks a signal
  (rebuild-worthiness) that is better served by spec-based VBT matching.

**Open question / potential limitation:** whether any consumer (VBT
ingestion, console UI) needs the flappy signal. If yes, it should be a
separate, clearly-labeled derived view — not a change to closure levels.

### Per-purl synthetic subject

Referrers attach to a **synthetic per-purl subject** rather than the built
artifact digest: a minimal, deterministic manifest generated from the purl
itself (canonical JSON of the purl, fixed mediaType). Every racing creator
computes the same digest and pushes the same manifest — the bootstrap race
("who creates the initial index") dissolves.

The build marker referrer carries the actual built artifact digest in its
content. This decouples closure state from specific build bytes and survives
rebuilds.

### Referrer types (subject = purl manifest)

| Referrer | Content | Writer |
|---|---|---|
| dependency edge | one direct dep purl (from packed package.json) | build pipeline |
| build marker | built artifact digest, build metadata | build pipeline |
| release marker | release metadata | release pipeline |
| parent link | parent purl that depends on this child | parent's build/release process |
| "build exists for child" notice | child purl | child's build process, pushed to parent's subject |
| level marker (L3 / closure-complete) | (empty/deterministic) | release pipeline when the node's level is computed |
| tombstone | the single edge being retracted | repair tooling |

The level marker is safe to cache because levels are monotone: once a purl
reaches a level it never regresses (deps land over time; tombstones only
remove requirements). The L3 marker doubles as the trigger to notify waiting
parents.

No "building" state marker: a build-in-flight marker would be the one
referrer type requiring retraction (builds fail), for no real gain — a
parent's walk seeing a transiently missing dep is already handled by the
build-exists notice triggering a re-walk. "Not present yet" and "build
failed" look identical to a walk and are both simply "the dep isn't there
yet."

### Walk and level computation (incremental, direct-deps-only)

Compliance levels are **inductive**: a node's level is a function of its
*direct* children's levels (any direct child not L3 → the parent is not L3;
a direct child exists/built → the parent may be L2; all direct children L3
→ L3). Therefore **no one ever walks a full transitive tree**:

- Computing a node's level is O(direct deps): look up each direct child's
  level marker on its subject.
- Each node's computed level is stored as its own monotone level marker, so
  children are computed once, at their own build/release time. The
  transitive closure computation is distributed and incremental across
  releases — it is never re-done centrally.
- A cached (stored) level is always a valid **lower bound**: monotonicity
  guarantees the true level can only be equal or higher. A re-walk refines
  upward.
- A full transitive walk is needed **only once, at backfill/migration**
  (see Migration).
- **Who walks:** the release process (per released package, direct deps
  only). The console UI never walks — it reads Pulp labels. Pulp never
  walks — labels are updated from walk results only.
- **Walk client requirements (hard):** always paginate through referrers
  listings via continuation tokens, and filter by artifact type. A client
  that stops at page 1 silently produces incomplete closures — this is a
  correctness requirement, not a scale nicety.

This addresses the 3,000+-round-trip concern: the naive full-tree walk
(500-node closure × paginated listing per node × manifest fetches) is
replaced by ~1 listing per direct dep per node, computed once per node's
lifetime, spread across all releases.



- **Retry with full-jitter exponential backoff** (base ~200ms, cap ~10s) on
  pushes. Quay's referrers push is atomic; retries cover transient failures.
  Referrer pushes are independent manifest appends (there is no
  tag-overwrite), so there is no lost-update window at the registry; retries
  cover transient API failures only.
- **Build-vs-discovery race — two convergent mechanisms:**
  1. **Registration = notification.** When a parent registers its
     relationships (parent links on its children's subjects), it
     **re-walks itself** after registration. A parent that registers *after*
     a child is built sees the built child in its own walk — correct
     immediately, no notification needed.
  2. **Child-side notice.** A child's build/release process discovers its
     parents by listing the parent-link referrers **on its own subject**,
     and notifies them to re-walk. This covers the parent that registered
     *before* the child existed (its walk saw a gap).
  
  In every interleaving, whoever acts last has full information; state
  converges without locks.
- **Upward cascade (explicit).** When a node re-walks and its level changes,
  it notifies *its* parents (found the same way — parent-links on its own
  subject), recursively. This is the distributed equivalent of the current
  `drain_blocker_parents` cascade. The Quay-side notification cascade can be
  asynchronous/queued; only the Pulp label commits are synchronous, and
  those are per-purl.
- **Contention domain** is per-purl, and each purl's state has effectively one
  legitimate writer at a time (its own build/release pipeline).
- **Two releases of different versions of the same package landing close
  together** do not conflict: parent links and edges are per-purl facts, and
  under sticky (as-built) semantics any release only adds validated content,
  so there is no "which release wins" question for level computation.

### Release-time flow

1. Release pipeline builds the closure metadata (child dependency tree) and
   pushes edge/build/release markers + parent links to Quay referrers.
2. Release pipeline **returns the dep-tree metadata** to the caller.
3. In balor-fianna, the release process updates closures for all dependencies
   by establishing **links between VBTs** (Jira issues) of direct dependencies.
   - If a direct dep's VBT exists: add the Jira issue link.
   - If missing: create a VBT for that purl (transitively where possible) and
     establish the relationships.
4. The Quay referrers graph is the source of truth; Jira VBT links (and Pulp
   labels, below) are projections of it.

Open question: which Jira link type/direction encodes "parent depends-on
child", and whether the closure walk is done against Quay or mirrored through
Jira for VBT purposes.

### Pulp labels (console UI projection)

The Lightwell console UI reads compliance metadata from Pulp labels, so the
labels must carry intermediate levels (L1/L2 while a closure is incomplete).
Under **sticky (as-built) semantics**, levels are monotone — they only move
upward — which is what makes a last-writer-wins-safe scheme possible. Label
updates use a **vote-then-commit (max-register) scheme**:

1. **Vote (disjoint write, race-free):** each updater first sets a unique
   per-pipeline label on the content unit:
   `closure.<pipeline-uuid> = <totally ordered value>` (walk epoch counter +
   uuid tiebreak). Unique keys means no two writers ever collide.
2. **Commit (commutative, idempotent):** list all `closure.*` labels, compute
   the maximum, and set the authoritative label
   (`tl.compliance_level = <level implied by max>`) to that value. `max` is a
   pure function of the vote set, so any number of racing commits converges.
3. **Verify before finishing:** re-read the label; if a straggler's stale
   commit clobbered yours, replay (re-read votes, recompute, re-set).

Properties and limits:

- Votes are never deleted during the race — delete/set sequences on Pulp are
  separate non-atomic REST calls and interleavings are unguarded. Pulp does
  support `unset_label/` (deletion is possible), but the scheme deliberately
  avoids needing it mid-race. Vote-label GC, if ever needed, must only
  remove votes older than the last committed epoch, and is a standing
  reconciler job.
- This converts lost-update corruption into **bounded staleness with a
  self-healing path**: a stale value can persist until the next write/verify
  pass. A periodic reconciler (not arbitrary readers — the console UI's read
  path stays read-only) recomputes `max` over the vote set and repairs.
- Cost: 3+ synchronous Pulp calls per content unit (vote, list, set, verify).
  Fine for release-pipeline throughput; the label commits are per-purl, and
  the Quay-side notification cascade is asynchronous.
- Quay referrers remain the source of truth; Pulp labels are a projection
  for the UI. `tl.compliance_oci_digest` is dropped — it would point at an
  append-only referrers set whose digest moves with every append.

## Registry GC and trust model

- **Quay GC**: the real data-loss vector is deletion of a *subject* manifest
  (its referrers become unreachable). Referrer manifests themselves are
  believed to be protected from tag-GC in Quay's referrers implementation,
  but this is implementation behavior, not spec — **verify empirically**, and
  as belt-and-braces tag each synthetic subject deterministically (tag =
  escaped purl). Add a canary that alerts if a known purl's referrers count
  drops.
- **Writer trust**: this is a *pre-existing* property of the current system,
  not a new risk — today, any pipeline with push rights to the compliance
  Quay repo can overwrite compliance docs and the global index, which is
  strictly worse (mutable state can be silently rewritten). The append-only
  graph improves auditability. Worth a sentence in the rollout: restrict
  push on the compliance repos to build/release service accounts.

## Migration (bootstrap, temporary)

Mechanical backfill: seed the referrers graph from the existing global index
+ per-package compliance docs (both are readable today), then dual-read with
shadow-compare for an evaluation window before retiring the index. The
console UI's label read path is unchanged (`tl.compliance_level`), so the UI
does not need to be part of the cutover; `tl.compliance_oci_digest` readers
(if any) must be migrated first.

## VBT projection (Jira)

VBTs are Jira issues. The release process in balor-fianna resolves each dep
purl to a VBT, creates missing ones (transitively where possible), and adds
issue links. Bootstrap concern: a purl→VBT uniqueness convention
(custom field + search-before-create with retry-on-duplicate) to prevent
duplicate creation from concurrent releases. Standing concern (small, not
architectural): a periodic Jira↔Quay reconciliation loop, because humans
merge/delete Jira issues and projections drift. VBT creation on missing deps
should consume the *spec* (`name@range`), not the resolved purl, so CVE
detection against open ranges works independently of closure levels (see
Closure semantics above).

## Why this is better than the current scheme

| Current | Proposed |
|---|---|
| Tag overwrite + local revision check; lost updates possible | Content-addressed reproducible artifacts; dedup by digest |
| Single global index tag = contention + drift + rebalance | Per-purl referrers sets; always consistent with registry |
| Derived levels stored, mutated on every parent event | Levels computed on read; nothing to lose |
| healing relies on idempotent cascade + retry luck | convergence by construction |

## Open items

1. **Sticky vs flappy closure semantics** (see Closure semantics section) —
   confirm no consumer needs the "newer max-satisfying version" signal from
   closure levels; if one does, build it as a separate derived view.
2. **Quay referrers GC behavior** — empirically verify referrer manifests
   survive tag-GC, and that subject deletion is the only orphaning vector;
   deterministic subject tags + referrers-count canary as mitigation.
3. Confirm Quay referrers API behavior at expected scale (pagination with
   continuation tokens, artifactType filtering — a correctness requirement
   of the walk client, not just a scale concern; a client that stops at
   page 1 silently produces incomplete closures).
4. **Walk cost / backfill**: the steady-state walk is direct-deps-only
   (incremental level computation). The one-time backfill walk over the
   full graph is the expensive path — size it, batch it, and benchmark
   before rollout. Decide whether a walk service is still needed for
   backfill or whether the migration tooling suffices.
5. **Synthetic subject validity** — verify Quay accepts layerless subject
   manifests with a config blob and auto-creates repos; specify one
   canonical purl form (package-url spec; scoped packages, prerelease
   versions, URL-unsafe characters) so two writers can never canonicalize
   differently.
6. Jira link type + walk semantics for VBT projection; purl→VBT uniqueness
   convention.
7. Exact ingestion-time contract (what metadata the release pipeline
   returns).
8. Verify `set_label/` / `unset_label/` semantics and label-size limits on
   the target Pulp version; confirm the console UI's label read path.
