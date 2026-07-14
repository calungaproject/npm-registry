# Proposal: npm Trusted Libraries — factory + recipe onboarding


| Field       | Value                    |
| ----------- | ------------------------ |
| **Status**  | Draft                    |
| **Authors** | TL team (draft for review) |
| **Date**    | 2026-05-20               |


## Summary

Trusted Libraries (TL) for npm adopts a **factory + recipe** model:

- **TL** operates CI/CD, standard **linux-x64 glibc** builder images, SBOM generation, signing, and Pulp publish — the **trusted factory**.
- **Onboarders** supply, per package version: a **manifest** (JSON metadata), an **entrypoint build script**, and a **smoke-test script** — the **recipe**.
- TL does **not** infer source locations, build commands, or native/binary layout from npm metadata alone.
- **Every onboarded version is built from source** at the git `ref` in the manifest. TL does **not** republish tarballs downloaded from registry.npmjs.org.
- **Tier B/C:** one manifest entry produces **all** declared `outputs` (main npm package + linux-x64 platform package) in a **single** factory run of `build.entrypoint.sh`.

Onboarding lives in a **dedicated Calunga git repository** (separate from Python `index/onboarded_packages/`). Builder images are defined and built from **`plumbing`** (or a documented image pipeline there).

Human review is required on every onboarding change; AI agents may **draft** PRs but do not sign releases or approve policy gates.

---

## Background

npm packages do not share a single build interface (unlike PEP 517 + wheels). Native tooling often splits JS wrappers and linux-x64 binaries across **optional dependencies** (e.g. `esbuild` + `@esbuild/linux-x64`). TL cannot scalably **guess** builds; onboarders declare **source** and **entrypoint** in a recipe PR.

Python RHTL pins versions in `index/onboarded_packages/<name>.json` and builds via **Fromager** from **sdist**. npm TL mirrors that intent: **build from declared git source**, not from npmjs tarballs. Published `.tgz` files are **outputs** of the factory (like wheels), even when install layout resembles upstream npm.

**Dependency closure** on the TL registry grows over time. Each published version carries a **compliance level** (`L1`–`L3`) describing how much of its production dependency tree is available from TL vs upstream registry at install time. Publish is allowed at any level; stricter org policy can require `L3` for production.

### Native tiers (for manifests and review)

| Tier | Description | Examples |
| ---- | ----------- | -------- |
| **A** | Pure JS; no linux-x64 binary package required | `express` |
| **B** | Platform optional family; main pkg + one TL linux-x64 binary package | `esbuild`, `sharp` |
| **C** | Compile-heavy; allowlisted only; strict smoke + recipe review | node-gyp-heavy deps |

---

## Goals

1. **Provable supply chain** — attestations bind published artifacts to TL builder image digest, git `ref`, and entrypoint script hash.
2. **Source-only builds** — `build.entrypoint.sh` clones/builds from `source.ref` only; `upstream_npm` is used for **verification**, not as the build input.
3. **Explicit recipes** — onboarders own build commands; TL owns the factory and compliance labeling.
3. **Bounded platform** — v1: **linux-x64**, **glibc** (UBI), one **Node LTS** per builder image line.
4. **Standard consumption** — TL-defined optional/binary packages (esbuild-style) so consumers resolve **TL-built** natives from Pulp.
5. **Graded closure compliance** — `L1` / `L2` / `L3` per version; catalog grows incrementally without blocking publish.
6. **Organizational scale** — package owners (or TL partners) maintain recipes via PR; TL maintains factory images and Konflux tasks.
7. **AI-assisted, human-gated** onboarding — agents draft manifests and scripts; humans verify ref↔version and script safety.

## Out of scope (v1)

- All CPU architectures or musl/Alpine (v1.1+).
- Automatic onboarding without PR review.
- TL-maintained universal native rebuild (Fromager-for-npm).
- Byte-identical parity with npmjs prebuilds.
- AI inside the signing path or hermetic build pod with outbound LLM access.

---

## Repository layout

### 1. `calunga-npm-onboarding` (new repo, name TBD)

Holds **one directory per onboarded package version** (or per package with versioned subdirs — see below).

```text
calunga-npm-onboarding/
  README.md
  CONTRIBUTING.md                 # PR checklist, review rules
  packages/
    esbuild/
      0.28.0/
        manifest.json
        build.entrypoint.sh
        verify.smoke.sh
    express/
      5.2.1/
        manifest.json
        build.entrypoint.sh
        verify.smoke.sh
    better-sqlite3/
      11.1.0/
        manifest.json
        build.entrypoint.sh
        verify.smoke.sh
        tl-install.js              # optional — Tier B/C install shim (see below)
```

**Alternative:** `packages/<name>/manifest.json` + scripts with version inside manifest only — team to pick one layout and enforce in CI.

Each onboarded **name@version** includes **at minimum** `manifest.json`, `build.entrypoint.sh`, and `verify.smoke.sh`. Tier **B/C** recipes may add **optional helper files** in the same directory (e.g. `tl-install.js`) that the entrypoint copies into the published main tarball — keep them small and PR-reviewable; do not hide install-time logic only inside bash heredocs.

### 2. `plumbing`

- **Builder images** — e.g. `quay.io/.../npm-builder` (UBI, Node 20 LTS, Go, Rust, gcc, python3 for node-gyp). Compiler/stdlib baseline must match onboarded native addons (e.g. C++20 may require **gcc-toolset** on UBI 8 or a newer base image — see [Support matrix](#support-matrix-v1)).
- **Tekton tasks / pipelines** — generic `build-npm-onboarded-package` that:
  - Clones onboarding repo at merged commit
  - Runs `build.entrypoint.sh` in chosen builder image
  - Runs `verify.smoke.sh`
  - Collects outputs, SBOM, sign, publish to Pulp
- Reuse patterns from `build-python-wheels-oci-ta`, `generate-and-sign-attestations`, `pulp-upload`.

### 3. `index` (existing)

- Product docs, support matrix, Konflux app wiring — may reference npm TL once operational.

---

## Onboard unit: manifest + scripts

Each onboarded **name@version** includes the three required scripts below (plus optional helpers for Tier B/C).

### One manifest, one build, multiple outputs

A single onboard directory (e.g. `packages/esbuild/0.28.0/`) defines **one** factory run:

- **One** `manifest.json`, **one** `build.entrypoint.sh`, **one** `verify.smoke.sh` (Tier B/C may add optional helpers such as `tl-install.js`).
- **One** checkout of `source.ref`.
- **One or more** `outputs[]` entries — e.g. main `npm-package` and `tl-platform-package` for Tier B.

Tier B and Tier C packages such as **esbuild** and **better-sqlite3** are **not** split across two onboarding PRs. The entrypoint must produce **both** tarballs listed in `outputs` (main package + `@calunga/<name>-linux-x64`) before publish. Smoke tests should cover both where applicable.

Tier A has a single `outputs` entry (main package only). Tier **B** and Tier **C** normally publish **main + `@calunga/<name>-linux-x64`** (see `outputs[]`); Tier C differs in that the platform binary is **compiled in the factory** (e.g. node-gyp), not downloaded as an upstream prebuild.

### `manifest.json`

Machine-readable metadata for CI and review.

```json
{
  "name": "esbuild",
  "version": "0.28.0",
  "description": "JavaScript bundler — TL linux-x64 binary + JS wrapper",
  "native_tier": "B",
  "source": {
    "url": "https://github.com/evanw/esbuild.git",
    "ref": "v0.28.0",
    "ref_type": "tag"
  },
  "upstream_npm": {
    "version": "0.28.0",
    "integrity": "sha512-..."
  },
  "entrypoint": "build.entrypoint.sh",
  "smoke": "verify.smoke.sh",
  "outputs": [
    {
      "id": "main",
      "type": "npm-package",
      "path": "out/esbuild-0.28.0.tgz",
      "pulp_name": "esbuild"
    },
    {
      "id": "linux-x64-binary",
      "type": "tl-platform-package",
      "path": "out/@calunga/esbuild-linux-x64-0.28.0.tgz",
      "pulp_name": "@calunga/esbuild-linux-x64",
      "platform": "linux-x64",
      "libc": "glibc"
    }
  ],
  "optional_dependencies_published": [
    "@calunga/esbuild-linux-x64@0.28.0"
  ],
  "requires_tl_packages": [
    { "name": "lodash", "version": "4.17.21" }
  ]
}
```

Do **not** author `compliance_level` or `closure_gaps` in the onboarding manifest. The pipeline **computes** them after querying the TL registry and **writes** them into published packages (and attestations). See [Where compliance metadata is stored](#where-compliance-metadata-is-stored).

Fields are illustrative; JSON Schema to be added in the onboarding repo.


| Field                             | Purpose                                                      |
| --------------------------------- | ------------------------------------------------------------ |
| `name` / `version`                | TL publish identity (aligned with npm name when possible)    |
| `native_tier`                     | `A` pure JS, `B` platform optional family, `C` compile-heavy |
| `source`                          | **Authoritative build input** — git URL + tag or commit        |
| `upstream_npm`                    | Expected npm release version + optional integrity; **verification only** (ref↔version), not fetched for build |
| `entrypoint` / `smoke`            | Filenames in same directory                                  |
| `outputs`                         | All tarballs this manifest produces in one build (main + platform) |
| `optional_dependencies_published` | Platform packages wired from main package (Tier B/C)           |
| `requires_tl_packages`            | **Author input** — prod deps (and platform packages for Tier B deps) used to **compute** L1/L2/L3; AI may draft, human confirms |


### `build.entrypoint.sh`

- **Required.** Runs **inside** TL builder only (non-interactive).
- Clones or uses mounted `source` at `ref` (CI may pre-checkout; script receives env vars).
- **Must not** use `npm pack <name>@<version>` from registry.npmjs.org or extract npmjs tarballs as the source of published artifacts.
- Produces **every** path in `outputs[]` under one run (e.g. `out/`).
- Must not call `npm publish` to npmjs, hold cosign keys, or exfiltrate secrets.
- Network: document required egress (git, language toolchains); default factory policy is allowlist-only.

Factory image version is pinned in the onboarding repo **PipelineRun** (`builder-image@sha256:...`), not in per-package manifests. Provenance records the digest used at build time.

**Tier B/C — assembling the published main tarball**

The entrypoint is responsible for **both** platform and main outputs, including **TL-specific wiring of the main `.tgz`** (not only compiling or copying upstream files):

1. Build or obtain the linux-x64 native artifact and pack `@calunga/<name>-linux-x64` (platform `outputs[]` entry).
2. Stage the **published** main package: JS/API files, updated `optionalDependencies`, stripped consumer compile paths (`prebuild-install`, `node-gyp`, `|| npm run build`, etc.).
3. Include a **TL install shim** (`install.js` or equivalent) that resolves the platform package from **Pulp only** — see [Published `package.json` and scripts policy](#published-packagejson-and-scripts-policy).
4. Pack the main tarball to the path in `outputs[]`.

Onboarders may **patch upstream** `install.js` (esbuild-style) or ship a **separate recipe file** (e.g. `tl-install.js`) that the entrypoint copies into the tarball as `install.js` — preferred when upstream has no small shim to adapt. Either way, the install helper diff must be visible in the PR.

Example responsibilities (package-specific):

- Tier A: build/pack from git tree (`npm pack` **from local checkout**, `npm run build`, etc.).
- Tier B: same run builds JS wrapper tarball **and** linux-x64 binary tarball (e.g. `go build` + layout for `@calunga/...-linux-x64`); patch or replace upstream install helper.
- Tier C: **compile** native artifacts from git (e.g. `node-gyp`) into the platform package; assemble main tarball **without** consumer compile fallbacks; same install-shim pattern as Tier B.

### `verify.smoke.sh`

- **Required.** Runs after build in the same builder image (or slim verifier with same glibc/Node).
- Exits non-zero on failure — blocks publish.
- Minimal checks: tarball layout, published `package.json` policy (Tier B/C), native artifact sanity (ELF / `--version` / `node --check` as appropriate).
- Use tools available in the **npm-builder** image (`od`, `tar`, `node`, `jq`) — do not assume optional packages such as `file(1)`.

---

## TL platform responsibilities (the factory)


| Capability                                             | Owner                   |
| ------------------------------------------------------ | ----------------------- |
| Builder images (UBI, Node LTS, toolchains)             | TL / `plumbing`         |
| Konflux pipeline (build → SBOM → sign → Pulp)          | TL / `plumbing`         |
| Hermetic / egress policy                               | TL                      |
| cosign / PEP-style attestations for published tarballs | TL pipeline only        |
| CVE / EC policy gates on pipeline output               | TL                      |
| Pulp npm repository                                    | TL                      |
| Consumption contract documentation + shim guidelines   | TL                      |
| Onboarding PR review (recipe correctness)              | Onboarder + TL reviewer |
| Factory security (image provenance, task trust)        | TL                      |


---

## Dependency closure compliance (L1, L2, L3)

Compliance describes **where production dependencies may resolve at `npm install` time** for consumers of this **name@version**. It does **not** block publish: TL ships source-built artifacts with SBOM and attestations at every level. Stricter environments (e.g. production Konflux) may require a minimum level.

**What is always true (all levels):** this version’s **own** artifacts (main tarball and, for Tier B, `@calunga/<name>-linux-x64`) were **built from `source.ref`** in the TL factory — never repacked from npmjs.

| Level | Name | Production dependencies at install | Typical use |
| ----- | ---- | ------------------------------------ | ------------- |
| **L1** | `partial-closure` | **Mixed** — any prod dep not yet on TL may resolve from **upstream npm registry** | Early onboarding; leaves first |
| **L2** | `direct-closure` | **Direct** prod `dependencies` + required **TL platform packages** for those deps (pinned versions) must be on TL; transitive deps may still use npmjs | Most packages before full tree exists |
| **L3** | `full-closure` | **Entire production lockfile closure** for this package resolves **only** from TL registry (linux-x64 v1); **no npmjs** for prod tree | Target for production apps; “highest” compliance |

**Computing the level (pipeline):**

1. On merge, manifest lists `requires_tl_packages` (direct prod deps + platform packages for Tier B deps — AI may draft, human confirms).
2. After build, factory queries Pulp (or onboarding repo index) for each pinned `name@version`.
3. Write `compliance_level`, `closure_gaps`, and **`assessed_at`** (UTC timestamp) into **`tl-compliance.json`** (main tarball) and **`artifact.json`** (platform tarball); include the same fields in the **attestation predicate**.

**Point-in-time assertion (no compliance republish):**

- TL publishes **`name@version` matching upstream semver only** (e.g. `vite@5.4.0`). No TL-specific suffixes (`5.4.0+tl.1`) to “bump” compliance.
- **`compliance_level` is fixed for that publish** — a snapshot of the registry **at factory run time**. It is embedded in the tarball and attestation and **does not change** when dependencies are onboarded later.
- Onboarding **`esbuild@0.28.0` later does not upgrade `vite@5.4.0` from L2 to L3** on the registry. `vite@5.4.0` remains L2 as published; consumers read that from `tl-compliance.json` / attestations.
- **Higher compliance comes from new upstream versions:** when `vite@5.5.0` is onboarded and the closure is fuller, that **new** `name@version` may ship as L3. Over time, **most actively maintained versions** are onboarded when the tree is mature → **most new publishes are L3**; older pins may stay L1/L2 historically.

**Re-publish same semver** only for **recipe/security fixes** (bad build, wrong ref, CVE rebuild policy) — not to refresh compliance labels. That is a separate org policy from closure level.

**Incremental growth:** onboard leaves first (often **L3** at first publish). Parents onboarded early may publish at **L1/L2**; later upstream releases benefit from a fuller TL registry. AI prioritizes onboarding deps that block many `requires_tl_packages` lists in pending manifests.

**Install behavior by level:**

- **L1:** Main package uses TL shim for **its own** `@calunga/*` platform dep. Other deps may install from npmjs per consumer `.npmrc` / lockfile.
- **L2:** Direct deps must be on TL; lockfile should pin TL URLs for those names.
- **L3:** Org configures **only** TL registry; lockfile fully resolved to Pulp.

---

## Where compliance metadata is stored

Use **layered** storage so humans, npm clients, and attestations see the same level.

| Location | File / field | Who writes | Audience |
| -------- | ------------ | ---------- | -------- |
| **Onboarding repo** | `manifest.json` → `requires_tl_packages` only (plus source, outputs, scripts) | Human / AI in PR | CI **input** for closure computation |
| **Main npm tarball** | `tl-compliance.json` at package root (include in `package.json` `files`) | **Pipeline** after build | Consumers, catalog tools, compliance dashboards |
| **Platform tarball** | `artifact.json` | **Pipeline** | Binary identity + **same** `compliance_level` / `closure_gaps` as main |
| **Attestation predicate** | `compliance_level`, `closure_gaps`, `source.ref`, `entrypoint_digest` | **Pipeline** | Sigstore / EC verification |
| **Pulp** (optional later) | Content attributes mirroring `compliance_level` | **Pipeline** | Registry search without unpacking |

**Authoring rule:** `manifest.json` declares **what to check** (`requires_tl_packages`). **CI declares the result** (`compliance_level`, `closure_gaps`) on artifacts consumers install — not in the merged manifest unless an optional bot documents last publish.

**`tl-compliance.json`** (main package) — logical **npm name@version**:

```json
{
  "name": "vite",
  "version": "5.4.0",
  "compliance_level": "L2",
  "assessed_at": "2026-05-20T14:32:00Z",
  "closure_gaps": [
    { "name": "esbuild", "version": "0.28.0", "reason": "not_on_tl_registry" }
  ],
  "requires_tl_packages": [
    { "name": "esbuild", "version": "0.28.0" },
    { "name": "@calunga/esbuild-linux-x64", "version": "0.28.0" }
  ],
  "built_from": {
    "url": "https://github.com/vitejs/vite.git",
    "ref": "v5.4.0"
  },
  "manifest_entrypoint_digest": "sha256:..."
}
```

**`artifact.json`** (platform package) — **binary artifact** metadata; includes the **same** `compliance_level` and `closure_gaps` as sibling main package (one manifest entry → one compliance story):

```json
{
  "name": "@calunga/esbuild-linux-x64",
  "version": "0.28.0",
  "platform": { "os": "linux", "cpu": "x64", "libc": "glibc" },
  "node_abi": "115",
  "built_from": {
    "url": "https://github.com/evanw/esbuild.git",
    "ref": "v0.28.0"
  },
  "builder_image_digest": "sha256:...",
  "entrypoint_digest": "sha256:...",
  "compliance_level": "L3",
  "closure_gaps": []
}
```

**Rule:** `artifact.json` is **not** a substitute for `tl-compliance.json` on the main package — platform pkg holds **binary/layout** fields; main pkg holds the **primary** catalog record for the npm package name consumers depend on. Both repeat `compliance_level` so installing only the platform optional still shows level.

---

## Consumption contract (TL platform packages v1)

For **this package’s own** Tier B binary, consumers must resolve **`@calunga/<name>-linux-x64`** from **Pulp** (TL-built in the same manifest). That holds at **all compliance levels** — TL never publishes a platform package that points at npmjs prebuilds.

### Naming (proposed)


| Artifact        | Pulp / npm name                           |
| --------------- | ----------------------------------------- |
| Main package    | `<name>` @ `<version>` (e.g. `esbuild`)   |
| Platform binary | `@calunga/<name>-linux-x64` @ `<version>` |


Exact scope (`@calunga` vs `@redhat-trusted-libraries`) is an open decision; must be stable across the index.

### Layout inside platform package

```text
package/
  bin/<tool>              # or sharp.node path per recipe
  artifact.json           # platform build identity + compliance_level (see above)
  README.md
  package.json
```

Main package layout additionally includes:

```text
package/
  tl-compliance.json      # closure level + gaps for this name@version
  sboms/                  # optional CycloneDX
  ...
```

Main package includes a **TL-maintained or onboarding-supplied** install shim (reviewed in PR) that:

1. Resolves `@calunga/<name>-linux-x64` from **TL registry URL** (this package’s platform output).
2. Falls back to clear error if optional missing — **no** silent fetch of **TL platform** binaries from npmjs.

At **L1**, other (non-TL) prod dependencies may still resolve from upstream registry per lockfile; shims must not conflate that with **this** package’s own `@calunga/*` binary.

Onboarders may adapt upstream `install.js` in the recipe PR; changes must be visible in diff review.

### Published `package.json` and scripts policy

The **main** tarball published to Pulp is usually **not** byte-identical to npmjs. Changes are **small and PR-visible**, focused on wiring TL platform packages and install-time behavior.

#### Factory vs consumer scripts

| Location | Role |
| -------- | ---- |
| `build.entrypoint.sh` (onboarding repo) | May invoke `npm run build`, `go build`, upstream release tooling — **not** shipped to consumers |
| Published main tarball | Only scripts that run on **`npm install`** are in scope for TL policy |

Upstream dev scripts (`test`, `lint`, `docs-build`) are normally **absent** from the published `.tgz` or irrelevant; do not need TL rewrites.

#### `package.json` fields that commonly change

| Field | Typical TL change |
| ----- | ----------------- |
| `optionalDependencies` | Rename platform deps to `@calunga/<name>-linux-x64` (or chosen scope) |
| `install` / `postinstall` | Point at TL-reviewed shim (see below) |
| `files` | Add `tl-compliance.json`, SBOM paths (e.g. `sboms/*.cdx.json`) |
| `prepare` | Often **removed** or omitted from published package so install does not trigger builds |

Usually **unchanged**: `name`, `version`, `main` / `exports`, `dependencies` for pure JS deps, public API.

The **platform package** uses a **new** minimal `package.json` (binary layout only); it is not a patch of upstream’s `@esbuild/*` / `@img/*` manifest.

#### Install-time scripts (main touch point)

| Tier | Expectation |
| ---- | ----------- |
| **A** | Often **no** `install` / `postinstall`; optional `files` only |
| **B** | **Targeted** change: `postinstall` / `install` + helper JS (e.g. `install.js`) |
| **C** | Same as B; **compile** runs in factory via entrypoint, **not** on consumer via `node-gyp` fallback |

**Upstream patterns → TL intent**

- **esbuild (Tier B):** `postinstall` → `node install.js` selecting `@esbuild/linux-x64` from npmjs → entrypoint patches upstream `install.js` so the shim resolves `@calunga/esbuild-linux-x64` from **Pulp only**.
- **better-sqlite3 (Tier C):** `install` → `prebuild-install || node-gyp rebuild` → entrypoint compiles in factory, ships `tl-install.js` as `install.js`, removes consumer compile path from published `package.json`.
- **sharp (Tier B/C):** `install` → `node install/check.js || npm run build` → TL shim loads prebuilt from platform package; **remove** consumer compile-at-install path from published artifact.

#### Preferred strategies (least → most invasive)

1. **Replace or add helper file** — keep `"postinstall": "node install.js"` (or `"install": "node install.js"`) and ship TL `install.js` in the tarball. Source it from a recipe sibling (e.g. `tl-install.js`) or patch upstream — clear PR diff.
2. **Publish with install scripts stripped** — only if optional deps are always resolved from Pulp and org policy allows `npm install --ignore-scripts` for edge cases.
3. **Broad `scripts` rewrites** — avoid unless necessary; increases review burden and drift from upstream.

Default: **(1)**. No silent fallback to npmjs for **this package’s** `@calunga/*` platform optional. At **L1**, other dependencies may still use npmjs — document in `tl-compliance.json` `closure_gaps`.

#### PR review checklist (scripts)

- [ ] Diff of published `package.json` vs upstream called out in PR description
- [ ] Install/postinstall helpers reviewed line-by-line (no `curl`/`npm install` to npmjs, no `node-gyp` on consumer for Tier B/C)
- [ ] `optionalDependencies` names and versions match manifest `outputs` / `optional_dependencies_published`
- [ ] Tier C: published package does not retain `|| npm run build` style fallbacks

#### What “significant” means here

**Significant** = install-time **behavior and supply-chain risk**, not a large `scripts` block. A few lines in `package.json` plus one shim file is normal for Tier B.

---

## CI/CD flow

Three Konflux pipelines, mirroring **Python `index`** (build → Quay OCI → release → Pulp prod) with an extra **Pulp Stage** on PR so recipes are built and installable before merge.

**Repos:** onboarding PRs land in `calunga-npm-onboarding` (name TBD). **Registries:** Pulp **Stage** (pre-merge), Quay **OCI** (post-merge transport), Pulp **Prod** (consumer `npm install`).

```text
PR → calunga-npm-onboarding
│
▼ on-pr (PipelineRun: pull_request → main)
├─ Static gate (fail PR)
│    ├─ lint: manifest schema, script shellcheck, no secrets
│    └─ policy: tier vs outputs[]; builder image pin; requires_tl_packages present
│
▼ Konflux build pipeline (same task graph as Python build-wheels pattern)
├─ identify changed packages/<name>/<version>/ (path filter or git diff vs origin/main)
├─ checkout onboarding path @ PR commit + source.ref (git)
├─ verify: package.json version at source.ref matches upstream_npm.version
├─ run build.entrypoint.sh in builder image  → all outputs[] (main + platform)
├─ run verify.smoke.sh
├─ cyclonedx / SBOM for collected artifacts
├─ compute compliance_level (L1–L3) + closure_gaps + assessed_at
├─ embed tl-compliance.json (main) + artifact.json (platform) in tarballs
├─ cosign attest each output .tgz (predicate: digests, source.ref, entrypoint_digest,
│    compliance_level, closure_gaps, assessed_at)
└─ npm publish all outputs[] → Pulp Stage only
│
▼ human review + merge
│
▼ on-push (PipelineRun: push → main)
├─ identify packages promoted by this merge (same identify logic; prev ref HEAD^)
├─ download matching name@version tarballs (+ attest sidecars) from Pulp Stage
├─ verify: cosign / attestation (signatures, predicate matches tarball digest)
├─ verify: optional EC policy on attestation + SBOM
└─ oras push → Quay OCI artifact
     e.g. quay.io/.../calunga-npm-onboarding:<merge-sha>.npm
     artifact-type: application/vnd.npm.packages (or equivalent)
     (no rebuild; promotes Stage bits already attested on PR)
│
▼ Release (ReleasePlan → rhtap-releng-tenant, auto-release on snapshot)
├─ download packages from Quay OCI artifact (oras pull)
├─ verify: attestation + signature (again at release boundary)
└─ npm publish all outputs[] → Pulp Prod
│
▼ consumers: npm install --registry <TL Pulp Prod>
              read compliance from tl-compliance.json (point-in-time for that name@version)
```

### Stage vs prod (review notes)

| Stage | When | Rebuild? | Registry | Consumer use |
| ----- | ---- | -------- | -------- | -------------- |
| **Pulp Stage** | `on-pr` | **Yes** — full factory from git source | Internal stage npm registry | PR validation, optional manual `npm install` against stage; **not** production |
| **Quay OCI** | `on-push` | **No** — copy from Stage after verify | `…/calunga-npm-onboarding:<sha>.npm` | Transport + release input (same role as Python `…:<sha>.wheel`) |
| **Pulp Prod** | **Release** | **No** — copy from Quay after verify | `packages.redhat.com/...` (prod TL npm) | Production installs |

**Alignment with Python:** Python **on-push** builds wheels and pushes **directly to Quay** (no Pulp Stage). npm adds **Stage on PR** so reviewers can test published layout before merge; **on-push** then **promotes** Stage → Quay instead of rebuilding (unless org later chooses rebuild-on-push — not default here).

**Compliance:** Level is computed on **PR build** (query TL Prod + Stage registry for `requires_tl_packages` at `assessed_at`), embedded in tarballs, and **carried unchanged** through Quay → Pulp Prod. Later onboarding of deps does **not** republish the same semver to bump level ([point-in-time assertion](#dependency-closure-compliance-l1-l2-l3)).

**PR vs merge commit:** Stage publish uses **PR head** revision. Merge promotion assumes the **merged PR** built successfully on that head (or final push to PR branch). If `main` moves without a fresh PR build, policy should require a green `on-pr` on the merge commit or re-trigger build — open operational detail.

### Triggers (Pipelines-as-Code)

| PipelineRun | CEL (example) | Params note |
| ----------- | ------------- | ----------- |
| `…-on-pull-request` | `event == "pull_request" && target_branch == "main"` | Pulp Stage URL; `output-image` optional for OCI skip |
| `…-on-push` | `event == "push" && target_branch == "main"` | Quay `output-image: …:{{revision}}.npm`; `prev-packages-ref: HEAD^` |
| **Release** | ReleasePlan on `calunga-npm-onboarding` app snapshot | `ociStorage` configmap → releng pulls Quay artifact |

### Verification gates

**on-pr (fail PR / no Stage publish)**

1. Manifest schema; tier vs `outputs[]`; shellcheck; no secrets.  
2. `build.entrypoint.sh` + `verify.smoke.sh`; all `outputs[]` produced from **git source only**.  
3. Ref ↔ `upstream_npm.version` (sanity; not build input).  
4. Install-script policy on built tree — [Published `package.json` and scripts policy](#published-packagejson-and-scripts-policy).  
5. Human TL reviewer approval.

**on-pr (before Stage publish)**

6. SBOM generated.  
7. `tl-compliance.json` + `artifact.json` embedded.  
8. cosign attest on each `.tgz`.

**on-push (fail merge pipeline)**

9. Every promoted package exists on Pulp Stage at pinned version.  
10. Attestation verifies against tarball digest.  
11. oras push to Quay succeeds.

**release (fail release / no Prod publish)**

12. Re-verify attestations on Quay artifact.  
13. EC / CVE policy when wired.  
14. Prod publish only from release pipeline service account.

### Python `index` parallel

| Step | Python | npm TL (this proposal) |
| ---- | ------ | ---------------------- |
| PR gate | `on-pr` → build-wheels → Quay `on-pr-*` (5d TTL) | `on-pr` → build → **Pulp Stage** |
| Merge | `on-push` → **rebuild** → Quay `:<sha>.wheel` | `on-push` → **promote Stage** → Quay `:<sha>.npm` |
| Release | releng: Quay → attest → **Pulp PyPI prod** | releng: Quay → verify → **Pulp npm prod** |
| Consumer index | `packages.redhat.com/.../python/` | `packages.redhat.com/.../npm/` (prod) |

---

## Governance: AI + human-in-the-loop


| Step                                                   | Actor                                       |
| ------------------------------------------------------ | ------------------------------------------- |
| Draft manifest + scripts from upstream docs / lockfile | AI agent (advisor, read-only to registries) |
| Open PR to `calunga-npm-onboarding`                    | Human or agent under human account          |
| Review tag↔version, script safety, outputs, tier       | **TL reviewer** (required)                  |
| Second review for Tier C                               | Recommended                                 |
| `on-pr` → build + attest + Pulp Stage                  | Konflux PR pipeline (no LLM in pod)         |
| `on-push` → promote Stage → Quay OCI                   | Konflux push pipeline                       |
| Release → Pulp Prod                                    | rhtap-releng release pipeline only          |


AI must **not** run inside the hermetic build with registry credentials or trigger cosign.

---

## Support matrix (v1)

| Dimension | v1                                          |
| --------- | ------------------------------------------- |
| OS / arch | linux-x64                                   |
| libc      | glibc (UBI)                                 |
| Node      | 20 LTS (example; pin per builder image tag) |
| Factory toolchain | Must satisfy **onboarded** native builds (e.g. node-gyp, C++ standard). Raising compiler requirements is a **`plumbing` npm-builder** change (gcc-toolset on UBI 8, or newer UBI base), not a per-recipe version downgrade. |
| Registry  | **Prod:** TL npm registry for installs; **Stage:** PR builds only; **L1/L2** may mix upstream npm for missing deps per `tl-compliance.json` |


musl / arm64: out of scope until v1.1 manifests declare additional `outputs`.

---

## Comparison to Python onboarding


|             | Python (`index`)              | npm (proposed)                                                              |
| ----------- | ----------------------------- | --------------------------------------------------------------------------- |
| Repo        | `index/onboarded_packages/`   | **`calunga-npm-onboarding`**                                                |
| Pin         | `version`, `ignored_versions` | `version` + **`source.ref`** + scripts                                      |
| Build logic | **Fromager** (central)        | **`build.entrypoint.sh`** (per package)                                     |
| Builder     | `plumbing` calunga-builder    | **`plumbing` npm-builder image(s)**                                         |
| Artifact    | wheel + SPDX                  | npm tarball + **TL platform package**                                       |
| PR output   | Quay OCI (`on-pr-*`)          | **Pulp Stage** (+ attest)                                                   |
| Merge output| Quay OCI (`:<sha>.wheel`)     | Quay OCI (`:<sha>.npm`) from Stage promotion                                |
| Consumer    | Pulp PyPI prod                | **Pulp npm prod**                                                           |
| Trust claim | We built wheel from sdist     | We built **declared outputs** from **declared ref** with **audited script** |


---

## Risks and mitigations


| Risk                              | Mitigation                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------- |
| Wrong git ref for npm version     | CI verification gate; human review                                              |
| Malicious entrypoint              | PR review, shellcheck, no secrets in repo, hermetic egress, no cosign in script |
| Recipe drift                      | Rebuild on manifest merge; optional nightly rebuild                             |
| Transitive natives                | One manifest builds main + platform; separate onboard entry per dep over time   |
| Consumer uses npmjs at L1         | Document in `tl-compliance.json`; raise level as deps publish to TL           |
| Builder compromise                | Standard Konflux trusted tasks, image digest pins, EC                           |
| Over-reliance on AI               | Human approval required; AI outside sign path                                   |


---

## Phased rollout


| Phase | Deliverable                                                                               |
| ----- | ----------------------------------------------------------------------------------------- |
| **0** | This proposal + JSON schema draft + CONTRIBUTING checklist                                |
| **1** | `plumbing`: npm builder image (node20-glibc) + manual pipeline for one Tier A (`express`) |
| **2** | Onboarding repo + Tier B pilot (`esbuild`) with platform package publish                  |
| **3** | `on-pr` / `on-push` / Release PipelineRuns; Stage + Quay + Pulp prod path                 |
| **4** | Tier C pilot (`sharp` or simpler native) + AI PR template                                 |
| **5** | Support matrix in `index/docs`; production publish only via plumbing pipeline          |


---

## Open decisions

- Final repo name: `calunga-npm-onboarding` vs other
- Scope namespace: `@calunga/` vs `@redhat-trusted-libraries/`
- Directory layout: `packages/<name>/<version>/` vs single manifest per name
- **Decided:** compliance is **point-in-time** per `name@version`; no TL-only semver; no republish solely to raise L1→L3
- **Decided:** three-stage publish — **Pulp Stage** (on-pr build) → **Quay OCI** (on-push promote) → **Pulp Prod** (release)
- on-push: promote from Stage vs rebuild on merge (default: **promote**; document merge-commit / PR head alignment)
- Who owns long-term recipe maintenance (onboarder vs TL SRE)
- Minimum compliance level for production consumers (org policy defaulting to `L3`)

---

## Appendix: supplementary design notes

Background material for reviewers; not part of the normative proposal above.

### Registry tarball vs git source

- npm `files` / pack output and a git repo are often **different subsets** of the same project.
- Fair mapping: **registry `.tgz` ≈ install artifact (wheel-like)**; **git tag + TL build ≈ sdist → wheel**.
- Registry `repository` metadata is optional and may be wrong; onboarding **`source.ref`** is authoritative for TL builds.

### Reference: esbuild and sharp (why Tier B exists)

**esbuild**

- Source: https://github.com/evanw/esbuild (Go).
- Main npm tarball: JS shim (`bin/esbuild` is a small Node script, not the compiler), `install.js`, `lib/main.js`.
- Real binary: optional `@esbuild/linux-x64` (~10 MB ELF), selected at install via `postinstall`.
- Consumers can also use GitHub Go releases or `ESBUILD_BINARY_PATH` outside npm.

**sharp**

- Source: https://github.com/lovell/sharp (C++ / libvips).
- Main npm tarball includes `src/*.cc` for **fallback** build, but default install uses prebuilt `@img/sharp-linux-x64` / `@img/sharp-libvips-linux-x64`.
- `install`: `node install/check.js || npm run build` — compile only when prebuilds are missing.

TL recipes for Tier B must publish **main + linux-x64 platform package** from **one** manifest entry / one source build.

### linux-x64 v1: scope and sign-off

**In scope:** linux-x64, glibc (UBI), one Node LTS per builder line, Pulp-only production installs.

**Out of scope for v1:** darwin, win32, arm64, s390x; musl/Alpine unless v1.1 adds separate platform `outputs`.

**Reasonable TL commitment**

- Tier A: SBOM + attest + CVE gate on published tarball.
- Tier B: factory-built or recipe-built linux-x64 binary package; no consumer fetch from npmjs for natives.
- Tier C: allowlist + mandatory smoke script.
- Default deny: packages that require compile-at-install on the laptop without a TL recipe.

**Not committed:** rebuilding all transitive natives on npm; byte-identical parity with npmjs prebuilds.

### Threat model (factory + recipe)

Provenance is **process trust**, not proof of vulnerability-free code.

- **Recipe model:** shifts trust to TL builder + audited `source.ref` + entrypoint digest; wrong ref or malicious script are still risks (mitigate with CI gates and human review).
- **Builder compromise** concentrates blast radius — mitigate with Konflux trusted tasks, image digest pins, EC.
- **Attestations** bind digests to Calunga; they do not validate that upstream source is benign.

Worth the model when TL is the **sole** npm index, install scripts do not re-download from npmjs, and CVE policy runs on pipeline SBOM output.

### AI agents at onboarding time

| Suitable for | Not suitable for |
| ------------ | ---------------- |
| Draft manifest, entrypoint, smoke scripts | cosign / publish decisions |
| Tier classification, closure listing | Hermetic build with secrets + LLM egress |
| CVE/SBOM triage summaries | Replacing smoke tests or EC gates |

Run agents as **advisors** on read-only inputs; humans approve PRs; pipeline remains deterministic.

### Install scripts, lockfile, closure

- Treat `install` / `postinstall` / `prepare` as high risk; published TL packages should not phone npmjs at consumer install unless explicitly allowlisted.
- After full closure is on Pulp, regenerate lockfiles so `resolved` points at TL, not registry.npmjs.org.
- Transitive natives: manifest `closure_policy` should list separate onboarded packages or document which TL platform packages must already exist on the index.

### Integrity scans (factory output)

| Layer | Approach |
| ----- | -------- |
| Fetch integrity | `upstream_npm.integrity`, tarball shasum checks in CI |
| CVE / license | Grype, Trivy, or osv-scanner on CycloneDX from pipeline |
| Malware | ClamAV on collected artifacts (optional Konflux task) |
| Provenance | cosign attest on each published `.tgz` |
| Policy | Enterprise Contract on Konflux results |

SBOM inventory alone does not imply safe code.

### Python references (existing Calunga)

- Pipeline: `plumbing/tasks/build-python-wheels-oci-ta.yaml`, `plumbing/builder/scripts/build-wheels`
- Attest / upload: `plumbing/utils/scripts/generate-and-sign-attestations`, `plumbing/utils/scripts/pulp-upload`
- Onboard pins: `index/onboarded_packages/*.json`

### Local Pulp (dev)

| Purpose | URL |
| ------- | --- |
| Publish | `http://127.0.0.1:8080/npm/dev-npm/` |
| Install / view | `http://127.0.0.1:8080/pulp/content/dev-npm/` |

Remove package content: `POST {repo_pulp_href}/modify/` with `remove_content_units` (repository **UUID**, not name).

