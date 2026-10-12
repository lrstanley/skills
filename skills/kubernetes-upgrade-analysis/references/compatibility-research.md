# Compatibility Research

Determine, per component, whether it works on the target Kubernetes version, what it must be
upgraded to first, and how far beyond the target it can go, without cloning upstream repos and
without spending equal effort on every component.

## When to use / not use

- Step 5, once the component list and API findings exist.
- Not a substitute for `deprecation-tools.md` (removed APIs); this covers support statements,
  release notes, CRDs, and node-level requirements.

## Tiers

| Tier | Components | Effort |
| --- | --- | --- |
| A | Control plane and provider, CNI, CSI/snapshotters, GitOps controllers, ingress/gateway and Gateway API CRDs, anything with CRDs or admission webhooks, anything flagged by a scan, anything a major version or more behind | Full: support range for current and latest, ceiling, release-note scan from current to recommended, linked breaking changes, open issues |
| B | Other Helm releases and add-ons without CRDs or webhooks | One compat lookup (docs or chart `kubeVersion`); release-note scan only if `recommended` differs from `current` |
| C | Workloads and tools that do not use the Kubernetes API or version (apps, chart libraries, sidecars of other components) | None: `N/A` row with a one-line reason |

If unsure whether a component uses the Kubernetes API, treat it as Tier B.

## Flow

1. Reuse history: copy rows from the previous report whose component version and pinned source
   URLs are unchanged. Re-research only changes, rows cited via moving URLs, and prior `UNKNOWN`s.
2. Resolve each Tier A/B component's upstream repo and chart/image location once (from the Helm
   release, GitOps source URL, or image labels).
3. Run lookups in parallel batches by source type (releases, chart metadata, compat docs,
   issues). For very large inventories you may split across a few research subagents grouped by
   source type, returning report-table rows plus linked breaking changes.
4. **Two-lookup rule**: if two different lookups cannot establish a fact, record `UNKNOWN` with
   the sources checked and move on.
5. Write results straight into the report tables; keep no second copy.

## Sources, in priority order (no cloning)

1. Official compatibility matrix or support statement, at a version-specific URL. Moving URLs
   (`latest`, `stable`, `master`) are acceptable when that is the only place a matrix exists:
   cite with the retrieval date.
2. Release notes for versions between current and candidate.
3. Chart `kubeVersion` in `Chart.yaml` (a hard install/upgrade gate).
4. CI test matrix (`.github/workflows/*`): fetch the one file, do not clone.
5. Issues and PRs about the target version.
6. Dependency versions (`k8s.io/client-go` in `go.mod`): `inferred` only.
7. https://endoflife.date/api/<product>.json for latest versions and EOL dates (supporting
   only); ArtifactHub for chart metadata.

```bash
# stable releases and notes keyword scan (read hits after the installed version). Add
# --paginate for older versions; for monorepos add select(.tag_name | startswith("<chart>-"));
# ignore backport releases from other branches. Always filter with jq/--jq, never dump bodies.
gh api "repos/<owner>/<repo>/releases?per_page=100" | jq -r '.[] | select(.prerelease | not) |
  "## \(.tag_name) \(.html_url)", ((.body // "") | split("\n")[] |
  select(test("breaking|remov|deprecat|incompatib|action required|migrat|kubernetes v?1\\.[0-9]{2}|crd"; "i")) | .[0:200])'
gh api repos/<owner>/<repo> --jq '{archived, pushed_at}'          # health

# one file at a tag, and a doc search in a repo, without cloning
gh api "repos/<owner>/<repo>/contents/<path>?ref=<tag>" -H 'Accept: application/vnd.github.raw'
gh api "repos/<owner>/<repo>/git/trees/<tag>?recursive=1" --jq '.tree[].path' | rg -i 'compat|support'

# issues about the target
gh search issues "1.37" --repo <owner>/<repo> --state open --json title,url,updatedAt

# chart kubeVersion: HTTP Helm repo index (many versions, one request)
curl -sL "<helm-repo-url>/index.yaml" | python3 -c '
import sys, yaml
d = yaml.safe_load(sys.stdin)
for e in d["entries"].get(sys.argv[1], [])[:15]:
    print(e["version"], e.get("appVersion", "-"), e.get("kubeVersion", "-"))' <chart>
# chart kubeVersion: OCI chart
helm show chart oci://<registry>/<path>/<chart> --version <v> | rg '^(version|appVersion|kubeVersion)'
```

Monorepo release lists mix charts and branches; filter by tag prefix and ignore backport
releases from other branches. Use `gh api`/`helm show`, not `helm repo add` (changes local
state). A keyword scan is triage, not reading: label breaking changes `scanned` (or `read` if
you read the notes), say "scanned, no hits" when nothing matched, and for ranges of many minors
also open the project's upgrade guide.

## Confidence

Use exactly: `documented` (explicit support statement), `tested` (CI matrix or release notes),
`constraint` (only a chart `kubeVersion` or similar gate), `inferred` (dependencies or
conventions), `unknown`. Do not raise confidence by reasoning; never present `inferred` or
`unknown` as `READY`.

## Status

Judged against the first reachable target: `min(requested target, max_target)`. When the target
is above what the provider offers, judging every row against it would turn most of the table into
`UNKNOWN` and hide the real `UPGRADE_FIRST` work, so use the highest reachable hop, say so in
Methodology, and show the unreached-hop gaps in the hop table:

| Status | Rule |
| --- | --- |
| `READY` | Current version has `documented`/`tested` support for the target and no `blocker` finding or breaking change affects it |
| `UPGRADE_FIRST` | Current version does not (or may not) support the target but a released version does; set `Recommended` and `order` |
| `BLOCKED` | No released version supports the target, the provider does not offer it, or an open confirmed bug breaks it; link evidence and any workaround |
| `UNKNOWN` | Support for the target cannot be established; list sources checked |
| `N/A` | Tier C |

- **Ceiling below the target without incompatibility evidence** (latest release documents
  support through 1.36, target 1.37): `UNKNOWN`, not `BLOCKED`; write it as
  `UNKNOWN (ready thru 1.36)`.
- **Chart `kubeVersion` only** (confidence `constraint`): stays `UNKNOWN`, written as
  `UNKNOWN (chart permits 1.35)`, so it is visibly better than no information.
- **Open-ended support** ("1.31+"): ceiling is `open`; it does not lower headroom.
- Ceiling = highest Kubernetes minor the latest release supports: a minor, `open`, or
  `unknown`.
- Flags: `eol`, `archived`, `successor`, `drift`, `suspended`, `unmanaged`. Order: `before` the
  control plane, `with`, `after`, or `independent` (justify non-obvious ordering from the
  component's upgrade docs).

## Headroom

- `max_target` = the minimum of the provider's offer (`provider_max`) and the lowest known
  ceiling (not `open`, not `unknown`) among components that use the Kubernetes API.
- Name the limiting components. Report the count and names of `unknown` ceilings, so `max_target`
  reads as an upper bound. When the provider is the limit, give both numbers ("provider 1.35;
  component evidence stops at 1.36").
- The verdict is for the requested target; the report's hop table answers "how far".
- Never recommend skipping a minor for the control plane. For multi-minor requests analyze each
  hop; the research table stays one combined table.
- State lifecycle: EOL dates for the from-version, target, and max target
  (https://endoflife.date/api/kubernetes.json, https://kubernetes.io/releases/). An EOL
  from-version is a reason to move even when the target is unreachable.

## Kubernetes itself

For each minor in (from, target]:

- Read its CHANGELOG (fetch
  `https://raw.githubusercontent.com/kubernetes/kubernetes/master/CHANGELOG/CHANGELOG-1.N.md`):
  "Urgent Upgrade Notes", "Deprecation", "API Change", removed flags and feature gates; plus the
  release blog's removals/deprecations post (https://kubernetes.io/blog/).
- Summarize as: item, affects us (yes/no/unknown), evidence, action. "Affects us" needs a check
  against the inventory (a repo flag, kubelet config, runtime version), not a restatement.

Version skew (verify current text: https://kubernetes.io/releases/version-skew-policy/):
control plane components never newer than the API server; kubelet never newer and lagging by a
bounded number of minors (read the bound); kubectl within one minor; upstream does not support
in-place minor kubelet upgrades (drain and replace or upgrade).

Node-level requirements to check against `nodes.tsv`: container runtime minimum, OS image and
kernel support, CNI kernel requirements, CSI sidecar compatibility
(https://kubernetes-csi.github.io/docs/), and provider add-on versions on managed distros.

## Component notes

| Type | Check |
| --- | --- |
| CNI | Upstream compatibility table, kernel/OS requirements, per-minor upgrade notes, CRD changes |
| Ingress / Gateway | Gateway API CRD version and channel the implementation requires (separate release train); webhook availability; retired/archived project |
| Operators with CRDs (cert-manager, external-secrets, ...) | Served vs stored CRD versions; CRD upgrade method (chart flag, separate chart, manual); remote CRD URLs in the repo that drift from the chart |
| Prometheus stack | Chart `kubeVersion`; CRD upgrade steps (Helm does not upgrade CRDs); renamed metrics |
| Flux | https://fluxcd.io/flux/releases/; removed API versions and documented upgrade procedure; `flux migrate` is mutating (recommend only) |
| Argo CD | https://argo-cd.readthedocs.io/en/stable/operator-manual/tested-kubernetes-versions/ (version in use); upgrade guides between minors |
| CSI / storage | Driver matrix; sidecar versions; snapshot CRD version; PDBs on storage pods |
| Service mesh | Mesh version matrix; injection webhook; control vs data plane ordering |
| Autoscalers | cluster-autoscaler is released per Kubernetes minor; Karpenter/KEDA/VPA matrices |
| Policy engines | Policies using removed APIs; `failurePolicy: Fail` impact |
| Node OS / runtime | Distro notes; runtime minimum for the target; managed providers decide these, so read their roadmap |
| Provider-managed add-ons | Status follows the provider's offer, often `UNKNOWN` with the roadmap link |

## Links

- Prefer permalinks (release tags, `blob/<tag>/...`, versioned docs). Moving URLs only per
  source 1, with the retrieval date.
- Verify any link you cite; drop links that fail rather than guessing.
- Each row links at least a release and a compatibility source; blockers add issue/PR links.
- Mark private links `(private)`.

## Anti-patterns

- Cloning upstream repos to read what `gh api` already serves.
- Equating "latest chart supports 1.N" with "our installed chart supports 1.N", or using
  `appVersion` where chart `kubeVersion` gates the install.
- Relying on memory of compatibility tables; fetch sources each run.
- Recommending the newest release without scanning breaking changes in range.
- Computing headroom from only the easy components, or counting `open` ceilings as unknown.
- Deep research on Tier C or low-impact Tier B components.
