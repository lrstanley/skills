# Discovery

Confirm the cluster, collect the inventory in one batch, find the provider's version cap, and
trace GitOps sources into the repos that drive the cluster. All commands are read-only.

## When to use / not use

- Steps 2 and 3 of the workflow, before compatibility research.
- Not for troubleshooting a broken cluster; this assumes a healthy API server.

## Confirm the cluster

The only commands allowed before the user confirms:

```bash
kubectl config current-context
kubectl config get-contexts
CTX=<context>
kubectl --context "$CTX" version -o json
kubectl --context "$CTX" get nodes -o wide
```

If the user named a cluster, match it to a context; if several or none match, ask. Show the
user: context, API server host (no credentials), cluster slug (report folder name), server
version, distro/provider, node count and version spread, scope, from-version, to-version, and
the report root. If only a target was given, derive the from-version from the server version
and say so. Flag nodes whose kubelet version differs from the server (mid-upgrade). A target
more than one minor above the server means a multi-hop plan.

### Distro

Identify it and record it in the header; it changes upgrade mechanics.

| Signal | Distro |
| --- | --- |
| `gitVersion` ends `-eks-...`, `providerID` `aws://` | EKS |
| `gitVersion` contains `-gke.`, label `cloud.google.com/gke-nodepool` | GKE |
| `providerID` `azure://` | AKS |
| `gitVersion` contains `+k3s` / `+rke2`; `osImage` contains `Talos` | k3s / RKE2; Talos |
| `kubeadm-config` ConfigMap in `kube-system` | kubeadm |
| `ClusterVersion` CRD (`config.openshift.io`) | OpenShift (different upgrade model) |
| `providerID` `openstack://`, `digitalocean://`, `hcloud://`, `scaleway://`, ... | Other managed provider: use its docs |

If nothing matches, record `distro: other` and the signals seen.

## Collect the inventory (one batch)

After confirmation, run these together (parallel shell calls, or one call with `&` and `wait`),
each redirected into `<report-folder>/evidence/<name>`. Read the files afterwards; do not paste
output into the report. A probe that fails or is denied means `not collected`, never `clean`.

```bash
k() { kubectl --context "$CTX" "$@"; }
E=<report-folder>/evidence; mkdir -p "$E"

k get nodes -o json | jq -r '.items[] | [.metadata.name, .status.nodeInfo.kubeletVersion,
  .status.nodeInfo.containerRuntimeVersion, .status.nodeInfo.osImage,
  .status.nodeInfo.kernelVersion, (.spec.providerID // "-")] | @tsv'            > "$E/nodes.tsv" &
k get crd -o json | jq -r '.items[] | [.spec.group, .metadata.name,
  ([.spec.versions[] | select(.served) | .name] | join(",")),
  ([.spec.versions[] | select(.deprecated == true) | .name] | join(",")),
  (.status.storedVersions | join(","))] | @tsv' | sort                          > "$E/crds.tsv" &
k get pods -A -o json | jq -r '.items[] | .metadata.namespace as $n |
  (.spec.containers + (.spec.initContainers // []))[] | [$n, .image] | @tsv' | sort -u > "$E/images.tsv" &
k get deploy,sts,ds -A -L app.kubernetes.io/name,app.kubernetes.io/version,helm.sh/chart \
  --no-headers                                                                  > "$E/workloads.txt" &
helm --kube-context "$CTX" list -A -o json | jq -r '.[] |
  [.namespace, .name, .chart, .app_version, .status] | @tsv'                    > "$E/helm.tsv" &
k get validatingwebhookconfigurations,mutatingwebhookconfigurations -o json | jq -r '
  .items[] | .metadata.name as $n | (.webhooks // [])[] | [$n, .name,
  (.failurePolicy // "Fail"), (.clientConfig.service.namespace // "url"),
  (.clientConfig.service.name // .clientConfig.url)] | @tsv'                    > "$E/webhooks.tsv" &
k get apiservices -o json | jq -r '.items[] | select(any(.status.conditions[]?;
  .type == "Available" and .status != "True")) | .metadata.name'                > "$E/apiservices-unavailable.txt" &
k get pdb -A -o json | jq -r '.items[] | select(.status.disruptionsAllowed == 0) |
  [.metadata.namespace, .metadata.name, "healthy=" + (.status.currentHealthy | tostring)] | @tsv' \
                                                                                > "$E/pdbs-zero-disruption.tsv" &
wait
```

Notes:

- **CRD stored versions**: from `crds.tsv`, flag CRDs with more than one stored version or a
  deprecated stored version. An operator release that drops a stored version can fail to start
  or strand objects; treat it as a prerequisite for that operator (see `deprecation-tools.md`).
- **Zero-disruption PDBs** and `failurePolicy: Fail` webhooks affect node drains; list them in
  the plan's node batch.
- Tooling: a snap-installed `jq` cannot read files under `/tmp` (pipe via stdin or use a
  home-directory path); older `yq` can return nothing for multi-document YAML (use python).

Add Flux or Argo CD sources only if their CRD group is in `crds.tsv` (see next section).

## Find what the provider offers (managed clusters)

On managed distros the provider caps the reachable version and often decides add-on versions
(CNI, CoreDNS, kube-proxy, CSI, node image, container runtime). Do this deliberately; it is
often the deciding blocker and is not visible from the cluster.

1. Find how the control-plane version is set: IaC in the GitOps repo (search for the cluster
   resource's version attribute and update policy), the provider console, or its CLI. Record
   the file and attribute for the plan.
2. Find the versions the provider offers now and its published roadmap for the next ones
   (provider docs, release notes, public roadmap issue tracker). For GitHub-hosted roadmaps:
   `gh search issues "<provider> kubernetes <target>" --json title,url,state` and read the
   matching issue or announcement thread with `gh api ... --jq` (never dump whole threads).
3. Record `provider_max` (highest offered minor), its source link, planned dates for later
   minors, and which add-ons and node image upgrade with the cluster versus are customer-owned.
4. If nothing can be found, `provider_max` is `unknown`; do not assume the target is reachable.

`provider_max` below the requested target makes the verdict `NO_GO` and caps `max_target`.

## Build the component list

Merge `helm.tsv`, GitOps-managed releases, CRD owners (by API group), `kube-system` add-ons, and
images belonging to none of those. Deduplicate by upstream project. For each: name, kind
(`controlplane`, `node`, `runtime`, `addon`, `operator`, `helm`, `kustomize`, `gitops`,
`other`), namespace, current version (chart and app version for charts), and manager (flux,
argocd, helm, manual, provider).

Common CRD group owners: `*.toolkit.fluxcd.io` Flux; `argoproj.io` Argo CD/Rollouts/Workflows;
`cert-manager.io`; `cilium.io`; `*.projectcalico.org`; `gateway.networking.k8s.io` (Gateway API
CRDs, versioned separately from implementations); `monitoring.coreos.com`;
`external-secrets.io`; `snapshot.storage.k8s.io`; `*.crunchydata.com`, `*.cnpg.io`. Find the
owner of unknown groups through CRD labels or `helm.sh/chart`.

Always include the platform pieces even if nothing "installs" them: control plane, kubelet and
kube-proxy, container runtime, OS image, CNI, CoreDNS, CSI drivers and snapshotters,
metrics-server, Gateway API CRDs, and the GitOps controllers. Provider-managed pieces with
unknown versions are one row: `provider-managed add-ons (...)`.

## Trace GitOps into repositories

Detect by CRD group: Flux (`*.toolkit.fluxcd.io`) and/or Argo CD (`Application` in
`argoproj.io`).

```bash
# Flux: sources, deployed revisions, Kustomizations, HelmReleases
k get gitrepositories,ocirepositories,helmrepositories -A -o json | jq -r '.items[] |
  [.kind, .metadata.namespace, .metadata.name, .spec.url, (.spec.ref // {} | tostring),
   (.status.artifact.revision // "-")] | @tsv'
k get kustomizations.kustomize.toolkit.fluxcd.io -A -o json | jq -r '.items[] |
  [.metadata.namespace, .metadata.name, .spec.sourceRef.name, (.spec.path // "./"),
   (.spec.suspend // false | tostring)] | @tsv'
k get helmreleases.helm.toolkit.fluxcd.io -A -o json | jq -r '.items[] |
  [.metadata.namespace, .metadata.name, (.spec.chart.spec.chart // .spec.chartRef.name // "-"),
   (.spec.chart.spec.version // "-"), (.status.history[0].chartVersion // "-"),
   (.spec.suspend // false | tostring)] | @tsv'
flux --context "$CTX" check

# Argo CD: one row per source (handles multi-source apps)
k get applications.argoproj.io -A -o json | jq -r '.items[] | . as $a |
  (.spec.sources // [.spec.source])[] | [$a.metadata.namespace, $a.metadata.name,
  .repoURL, (.targetRevision // "HEAD"), (.path // .chart // "-"),
  ($a.spec.destination.server // $a.spec.destination.name),
  ($a.status.sync.status // "-"), ($a.status.health.status // "-")] | @tsv'
```

- Use deployed `status` values (revision, chart version) for what is actually running; `spec`
  may be a range. Flag suspended resources, branch-pinned sources, and sources using deprecated
  Flux API versions.
- For Argo CD, only analyze Applications whose destination is this cluster; note
  `OutOfSync`/`Degraded` apps as pre-existing risk; ApplicationSets decide what deploys per
  cluster, so note their generators.
- The source URLs tell you where each chart lives (Helm repo, OCI) for chart metadata lookups.

### Repositories (the only clones allowed)

For each distinct repo URL (the cluster's own, usually 1-3):

1. Prefer an existing local clone (`git remote -v`); verify its ref matches the deployed
   revision. Otherwise `git clone --depth 1 --branch <ref>` into a temp dir, using the URL the
   GitOps source uses (SSH for private repos, with the user's existing keys); if that fails try
   `gh repo clone`; else record `repo not accessible` and use cluster-only evidence. Never copy
   credentials from cluster Secrets.
2. Find: chart versions (HelmRelease, `Chart.yaml` dependencies, Argo `chart:`), Kustomize
   bases, remote resource URLs pinned to a ref (these often drift from the running chart), raw
   manifests and their `apiVersion`s, IaC that sets the control-plane version, version-bump
   automation (`renovate.json`, dependabot), and the overlay for this cluster only.
3. Flag drift between repo-declared and cluster-actual versions.
4. Note how changes are delivered (PR to a reconciled branch, bot, manual apply): it decides
   which plan batches are `PR` vs `MANUAL`.

Open upgrade PRs (`gh pr list --search "<component>"`) are useful context; link them.

## Anti-patterns

- Treating the repo as truth without comparing it to what the cluster runs.
- Stopping at the chart version: app version and CRD versions matter too.
- Assuming a clean result when a probe was denied or a repo was unreadable.
- Reading Secrets or Helm values.
- Cloning upstream component repositories.
