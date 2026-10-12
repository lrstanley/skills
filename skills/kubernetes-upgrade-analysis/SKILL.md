---
name: kubernetes-upgrade-analysis
description: >-
  Analyzes a live Kubernetes cluster and its GitOps sources (Flux, Argo CD) for a cluster
  minor-version upgrade or a single component upgrade, and writes a standardized, skimmable
  upgrade report covering API deprecations, per-component compatibility, maximum upgrade
  headroom, and a batched upgrade plan. Use when planning a Kubernetes upgrade (e.g. 1.34 to
  1.35), upgrading a cluster component (CNI, ingress, operators, controllers, CSI), or
  auditing upgrade readiness.
license: MIT
disable-model-invocation: true
metadata:
  author: https://github.com/lrstanley
  domain: infrastructure
  triggers: kubernetes upgrade, cluster upgrade, k8s upgrade, version skew, API deprecation, removed APIs, pluto, kubent, kubepug, upgrade report, upgrade readiness, Flux, Argo CD, GitOps, compatibility matrix, component upgrade
  role: specialist
  scope: analysis
  output-format: report
  related-skills: kubernetes-specialist
---

# Kubernetes Upgrade Analysis

Read-only analysis of a cluster (and the Git repos that drive it) ahead of an upgrade. The
deliverable is one report in a fixed layout, so runs are comparable and later runs can reuse
earlier ones as context.

## When to Use

- "Upgrade the cluster from 1.34 to 1.35" (scope: `cluster`).
- "Upgrade cert-manager / Cilium / Flux / the ingress controller / ..." (scope: `component`).
- "Is this cluster ready for 1.N?" or "How far can we upgrade?"

Not for performing the upgrade, writing manifests, or live troubleshooting (see
`kubernetes-specialist`).

## Hard Rules

- **Read-only.** Only `get`, `list`, `describe`, `version`, `api-resources`, `auth can-i`,
  `--raw` GETs, `helm list/template`, `flux get/check`, `argocd app get/list`. Never `apply`,
  `patch`, `delete`, `drain`, `cordon`, `annotate`, `flux reconcile/suspend/resume/migrate`,
  `argocd app sync`. Mutating commands may appear in the plan as recommendations only.
- **Explicit context.** After confirmation, pass `--context <ctx>` on every `kubectl`,
  `helm --kube-context`, and `flux --context` call.
- **No guessing.** Every status claim needs a source link. Unverifiable facts are `UNKNOWN`,
  with the sources checked listed.
- **No upstream clones.** Clone only the GitOps repos that drive this cluster (shallow).
  Research components through `gh api`, release pages, raw file URLs, and Helm repo indexes.
- **No secrets.** Never fetch Secret objects or print Helm values; redact credentials from
  `evidence/` and the report.

## Core Workflow

1. **Load history.** Find the report root (default `upgrade-reports/`). Read `INDEX.md` and the
   latest `REPORT.md` for this cluster (and for the same component, if any). Reuse verified
   facts whose version and source URL have not changed.
2. **Confirm target.** Run the confirmation probes in `references/discovery.md`, show the user
   the context, API host, distro, server version, and node count, and **wait for explicit
   confirmation** (use the client's question tool if it has one). Confirm scope, from-version,
   and to-version too. If the user already named context and target, record that as the
   confirmation and still run the probes.
3. **Discover.** Run the discovery probes as one batch (parallel, output redirected into
   `evidence/`). Find the provider's offered versions on managed clusters, trace GitOps sources
   into the cluster's repos, and build the component list (`references/discovery.md`).
4. **Detect deprecations.** Run every installed scanner against the cluster and the GitOps
   repos with the target version set; use the documented fallback for missing tools
   (`references/deprecation-tools.md`).
5. **Research compatibility, by tier.** Deep research for Tier A components, one lookup for
   Tier B, none for Tier C. Run lookups in parallel; stop after two failed lookups per fact and
   record `UNKNOWN` (`references/compatibility-research.md`).
6. **Write the report once.** Produce `REPORT.md` and update `INDEX.md` using the layout,
   status words, and batched plan format in `references/report-format.md`. Summarize the
   verdict, blockers, headroom, and plan batches in chat.

## Reference Guide

| Topic | Reference | Load When |
| --- | --- | --- |
| Confirmation, discovery probes, provider cap, GitOps and repo tracing | `references/discovery.md` | Steps 2-3 |
| Deprecation scanners, API server metric, finding format | `references/deprecation-tools.md` | Step 4 |
| Tiers, no-clone research, ceilings, headroom, skew | `references/compatibility-research.md` | Step 5 |
| Folder layout, status words, report template, batched plan | `references/report-format.md` | Steps 1 and 6 |

## Constraints

### MUST DO

- Confirm the cluster context with the user before running anything beyond the probes.
- Report **headroom** (how far beyond the target the cluster could go) for the cluster and per
  component, including the provider's offered versions on managed clusters.
- Group the upgrade plan into ordered **batches**, each with a type (`PR`, `MANUAL`,
  `PROVIDER`, `VERIFY`), a phase (before, during, after the control-plane upgrade), its
  dependencies, and a gate, so each batch is one pull request or one operation.
- Link every component row to its release and compatibility source.
- Record what could not be checked (missing tools, RBAC denials, private repos) in the report.
- Keep section order, headings, and status words identical across reports.

### MUST NOT DO

- Mutate the cluster or GitOps repos, or trigger reconciliation.
- Clone upstream component repositories.
- Claim support for a Kubernetes version without a cited source.
- Silently skip a missing tool; record it as `not installed` and use the fallback.
- Use non-ASCII punctuation in `REPORT.md` and `INDEX.md`. Raw `evidence/` files are exempt.
