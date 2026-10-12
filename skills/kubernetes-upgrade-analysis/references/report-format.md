# Report Format

Folder layout, status words, the `REPORT.md` template, and the batched upgrade plan. Consistency
across runs matters more than elegance: future runs diff against these files, and the Markdown
tables in `REPORT.md` are the data contract (there is no second structured copy).

## When to use / not use

- Step 1 (reading prior reports) and step 6 (writing the new one).
- Do not rename, reorder, or invent sections; put leftovers in "Open questions" or
  "Methodology".

## Folder layout

```text
upgrade-reports/                       # report root
|-- INDEX.md                           # one row per report, newest first
`-- <cluster>/                         # slug of the confirmed cluster name
    `-- <YYYY-MM-DD>_<subject>/
        |-- REPORT.md
        `-- evidence/                  # raw, redacted command/tool output (redirected, not retyped)
```

- Dates are the user's local date.
- `<subject>`: `k8s-<from>-to-<to>` (minors) for cluster scope, `<component>-<from>-to-<to>` for
  component scope. If the folder exists, append `-2`, `-3`.
- Cluster slug: lowercase `[a-z0-9-]`, from the confirmed cluster name.
- Evidence is exempt from the ASCII rule but must contain no tokens, Secret data, kubeconfig
  content, or URL credentials.

**Root**: use an existing `upgrade-reports/` (or the repo's equivalent) in the working directory
or Git root; else, if the working directory is the cluster's GitOps repo, create it at the Git
root; else `./upgrade-reports/`. A path from the user wins. State the choice at confirmation.

**`INDEX.md`**: create if missing; prepend a row per report.

```markdown
# Upgrade Reports

| Date | Cluster | Subject | Verdict | Max target | Report |
| --- | --- | --- | --- | --- | --- |
| YYYY-MM-DD | <cluster> | k8s <from> -> <to> | <VERDICT> | <x.y> | [report](<cluster>/<folder>/REPORT.md) |
```

**Reading history (step 1)**: read `INDEX.md`; open the newest report for this cluster (and, for
component scope, the latest mentioning that component); read its frontmatter, both component
tables (together they list every component), actions, plan, and open questions. Reuse rows whose
`Current` and pinned source URLs are unchanged; re-check moving URLs and `UNKNOWN`s. Fill
"Changes since previous report" by diffing the component tables and findings.

## Status words

Use exactly:

| Field | Values |
| --- | --- |
| Verdict | `GO`, `GO_WITH_PREREQS`, `NO_GO`, `INCOMPLETE` |
| Component status | `READY`, `UPGRADE_FIRST`, `BLOCKED`, `UNKNOWN`, `N/A` |
| Finding severity / scope | `blocker`, `warn`, `info` / `core`, `crd` |
| Confidence | `documented`, `tested`, `constraint`, `inferred`, `unknown` |
| Flags | `eol`, `archived`, `successor`, `drift`, `suspended`, `unmanaged` |
| Order | `before`, `with`, `after`, `independent` |
| Batch type | `PR`, `MANUAL`, `PROVIDER`, `VERIFY` |
| Batch phase | `pre`, `control-plane`, `nodes`, `post`, `anytime` |

Verdict applies to the **requested** target:

- `NO_GO`: unreachable (above `provider_max`, or a `BLOCKED` component or `blocker` finding
  with no fix). State which. The hop table shows what is reachable now.
- `GO_WITH_PREREQS`: reachable, but an `UPGRADE_FIRST` component, fixable `blocker`, or
  unknown the team must resolve exists.
- `GO`: every component `READY` or `N/A` and no `blocker` findings.
- `INCOMPLETE`: material evidence is missing (access denied, partial tool coverage, many
  `UNKNOWN`); say what is missing first.

## Component table

Same columns in the visible table (non-`READY`, non-`N/A`, sorted `BLOCKED`, `UPGRADE_FIRST`,
`UNKNOWN`) and the collapsed table (`READY` and `N/A`, by name), so the pair is the full,
parseable inventory:

`| Component | Ns | Current | Recommended | Latest | K8s support (current / ceiling) | Status | Links |`

- `Current`: `chart X / app Y` for charts. A repo-declared version that differs, or a floating
  pin, adds `drift` to `Status` and is explained in details.
- `K8s support`: `<range> / <ceiling>`; append the confidence if not `documented`/`tested`.
  Ceiling is a minor, `open`, or `unknown`.
- `Status`: the word, then order: `UPGRADE_FIRST (before)`; `UNKNOWN (ready thru 1.36)` when
  documented support ends before the target; flags after: `READY, archived`.
- Links: `[rel]`, `[compat]`, `[issue]`, `[docs]`, `[pr]`.
- Provider-managed pieces with unknown versions are one row (`Current` = `provider`). Tier C
  rows are `N/A` with the reason in the support cell; group identical ones (for example several
  workloads of the same chart library) into one row.
- Judge `Status` against `min(requested target, max_target)`; the hop table covers the rest.

## `REPORT.md` template

Fill every section; use `None.` when empty. Frontmatter carries the key facts.

````markdown
---
cluster: <slug>
context: <kubectl context>
scope: cluster | component
subject: <subject>
generated: <YYYY-MM-DD>
from_version: "<x.y.z>"
to_version: "<x.y>"
verdict: GO | GO_WITH_PREREQS | NO_GO | INCOMPLETE
max_target: "<x.y>"
provider_max: "<x.y> | unknown | n/a"
---

# Upgrade report: <cluster> - <subject, human readable>

| | |
| --- | --- |
| Cluster | `<cluster>` (context `<context>`, API `<host only>`) |
| Distro | <provider/distro>, <managed or self-managed>; version set in <file/console> |
| Versions | server <x.y.z>, kubelet <min>-<max>, runtime <x.y.z>, OS <image> |
| GitOps | <Flux vX / Argo CD vX>, repos: <n> (<accessible/total>) |
| Scope | <cluster | component: name>, <from> -> <to> (hops: <list>) |
| Generated | <YYYY-MM-DD> (previous: <link or "none">) |

## Verdict

**<VERDICT>**: <one sentence: the most important thing to know.>

| Blockers | Upgrade first | Unknown | Ready | N/A | API blockers | API warnings |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Headroom

- **Requested target** `<to>`: <reachable | reachable after prerequisites | blocked by X>.
- **Maximum supported** `<max_target>`: limited by <components/provider>. <n> components have an
  unknown ceiling (<names>), so this is an upper bound. Provider offers up to `<provider_max>`
  ([source](url)); component evidence alone stops at `<x.y>`.
- **Lifecycle**: `<from>` EOL <date>; `<to>` EOL <date>; latest patch <x.y.z>
  ([releases](https://kubernetes.io/releases/)).

| Hop | Verdict | Limited by |
| --- | --- | --- |
| <from> -> <x.y> | GO_WITH_PREREQS | <components/none> |
| <x.y> -> <to> | NO_GO | <provider offer / component> |

## Action required

Each item points at a plan batch and its type, in plan order.

1. `[B1 PR]` **<Imperative title>** - <component>, <why in a few words>.
   [details](#anchor-or-url) - [issue](url)
2. `[B2 MANUAL]` ...

## Components

| Component | Ns | Current | Recommended | Latest | K8s support (current / ceiling) | Status | Links |
| --- | --- | --- | --- | --- | --- | --- | --- |
| example-operator | example-system | 1.2.0 | 1.4.1 | 1.5.0 | 1.28-1.31 / 1.35 | UPGRADE_FIRST (before) | [rel](url) [compat](url) |

<details>
<summary>Ready and not applicable: <n> components</summary>

(same columns)

</details>

## Details

<details>
<summary>Upgrade plan: <n> batches (<n> PR, <n> manual, <n> provider, <n> verify)</summary>

(see "Upgrade plan" below)

</details>

<details>
<summary>API deprecations: <n> blockers, <n> warnings, <n> info</summary>

Coverage: <tools, data coverage, API server sample count>. Raw output: `evidence/`.

| Severity | Scope | API | Removed in | Count | Owner | Where | Fix |
| --- | --- | --- | --- | --- | --- | --- | --- |

</details>

<details>
<summary>Kubernetes <from> -> <to> changes: <n> affect this cluster</summary>

| Change | Kind (removal / default / flag / gate) | Affects us | Evidence | Action | Link |
| --- | --- | --- | --- | --- | --- |

One table per hop.

</details>

<details>
<summary>Component details: <n> components</summary>

<details>
<summary>example-operator 1.2.0 -> 1.4.1 (UPGRADE_FIRST, before control plane)</summary>

- **Support**: current <range> (<confidence>, [source](url)); latest <range> (<confidence>,
  [source](url)). Ceiling <x.y>.
- **Breaking changes** (scanned | read): <linked bullets>. Affects us: <yes/no/unknown, why>.
- **Upgrade notes**: <CRD handling, ordering, upgrade guide link>.
- **Open issues**: [#1234](url) <one line>.
- **Sources checked** (required if anything is `unknown`/`inferred`): <list>.

</details>

One nested block per non-`READY` component with something to say.

</details>

<details>
<summary>GitOps and repositories (<n> sources)</summary>

| Controller | Source | URL | Ref / revision | Accessible | Notes |
| --- | --- | --- | --- | --- | --- |

Drift, suspended resources, out-of-sync apps, bump automation, and how changes are delivered.

</details>

<details>
<summary>Cluster and nodes</summary>

Node table (pool, count, kubelet, runtime, OS, kernel), provider add-on and image policy,
`failurePolicy: Fail` webhooks, unavailable APIServices, zero-disruption PDBs.

</details>

<details>
<summary>Changes since previous report</summary>

Diff against <previous link>, or "First report for this cluster."

</details>

<details>
<summary>Open questions and unknowns (<n>)</summary>

- <what is unknown, what was checked, what would resolve it>

</details>

<details>
<summary>Methodology and limits</summary>

- Context confirmed with user: <how>; commands were read-only.
- Tools: <name version (used | not installed | partial)>, data coverage vs target.
- Not collected: <denied probes, private repos, missing tools>.
- Sources: <primary docs; moving URLs with retrieval date>.
- Suggested tooling: <missing tools that would help the next run>.

</details>
````

Collapsed blocks need a blank line after `<summary>` and before `</details>`. Put counts or a
verdict in every `<summary>`. The visible part has no raw output, long prose, or code blocks.

## Upgrade plan

Group every required change into ordered **batches**: sets of changes that can be done
together as one pull request or one operation. The team should be able to open the PRs for
batch 1, run the manual steps for batch 2, and know what must be true before moving on.

| Type | Meaning | The batch lists |
| --- | --- | --- |
| `PR` | Change merged through the GitOps or IaC repo | repo, files, old -> new versions, suggested PR title, whether it can be opened in parallel with other `PR` batches |
| `MANUAL` | Operator runs commands or steps (backup, storage migration, CRD apply, `flux migrate`, drain) | exact commands, marked "recommended; not run by this analysis", needed permissions |
| `PROVIDER` | Control-plane or node-pool version change via provider console/API/CLI, or an IaC apply that triggers it | how the version is set, update policy, expected disruption, provider docs link |
| `VERIFY` | Read-only gate or decision (checks, wait for provider offer, resolve unknowns) | the checks, pass criteria, what to wait for |

| Phase | When |
| --- | --- |
| `pre` | before the control-plane upgrade: removed-API and stored-version migrations, `before` components, backups |
| `control-plane` / `nodes` | the control-plane version change / node pool rollout and drains |
| `post` | after: `with` and `after` components, re-verification, cleanup |
| `anytime` | `independent` components and housekeeping; can run in parallel with anything |

Rules:

1. **One batch = one failure domain.** Group changes of the same type and phase with no
   dependency between them. Never mix a storage-version migration, CRD change, or risky
   component upgrade into a batch with unrelated bumps; give it its own batch.
2. **Order by dependency, then blast radius**: `pre` migrations, `before` components, backup and
   `VERIFY` gate, `control-plane`, `nodes`, `with`/`after` components, then `anytime`. State
   dependencies by batch ID.
3. **Every batch has a gate** (what to verify before the next batch; how long to wait, if it
   matters) and a **rollback** (revert the PR, pin the old version, or `not reversible: back up
   <X> first`).
4. **Completeness**: every `blocker` finding, `UPGRADE_FIRST` component, drift to fix, and
   unknown needing a decision is in exactly one batch; "Action required" mirrors the batches.
5. **Multi-hop**: full batches for the first reachable hop; later hops list only the batches
   that repeat or differ, marked `deferred: <reason>` (for example the provider does not offer
   it yet), ending with a `VERIFY` batch to re-run this analysis.
6. **Delivery matches the repo**: say whether a merge applies automatically (reconciled branch)
   and what must be applied by hand because it lives outside Git (provider settings, manual
   CRDs, Terraform state). Mutating commands appear only as recommendations.

Template (inside the "Upgrade plan" details block):

````markdown
All commands are recommendations; this analysis was read-only.

**Hop <from> -> <x.y>**

| Batch | Phase | Type | Change | Depends on | Gate before next |
| --- | --- | --- | --- | --- | --- |
| B1 | pre | PR | Bump <A> <v> -> <v>, <B> <v> -> <v> | - | <A>, <B> Ready |
| B2 | pre | MANUAL | <storage migration / CRD update> | B1 | <check> |
| B3 | pre | VERIFY | Backup completed; PDB plan agreed | B2 | <criteria> |
| B4 | control-plane | PROVIDER | Set version to <x.y> in <file/console> | B3 | nodes report <x.y> |
| B5 | nodes | PROVIDER | Roll node pool; drain notes | B4 | all nodes <x.y> |
| B6 | post | PR | Bump <C> (order `after`) | B5 | <check> |
| B7 | anytime | PR | Independent bumps (<list>) | - | <check> |

**B1 - PR: <title>** (can open in parallel with B7)
- Repo `<repo>`: `<path>`: `<old>` -> `<new>`. PR title: `<conventional title>`.
- Why: <finding or component, link>. Rollback: revert the PR.

**B2 - MANUAL: <title>**
- Run (recommended): `<command>`; expect <result>. Needs: <permission>.
- Why: <finding, link>. Rollback: <how, or "not reversible: back up X">.

(One short block per batch.)

**Hop <x.y> -> <to>** - `deferred: <reason>`; repeats B4-B6; adds <batches>.
````

## Writing rules

- ASCII only in `REPORT.md` and `INDEX.md` (`-`, `->`, straight quotes).
- A status or support claim without a link is a bug; use `UNKNOWN`.
- Link the specific release, issue, or doc section, not a repo root.
- `<summary>` lines are counts or verdicts, not sentences. Keep tables sorted and columns fixed.

## Anti-patterns

- Burying blockers in the visible part, or renaming headings per run.
- A flat checklist plan with no types, phases, dependencies, or gates.
- Mixing PR-able and manual operations in one batch.
- Raw `kubectl get -o yaml` in `evidence/`.
- Reusing prior support claims without checking the version and source URL are still valid.
