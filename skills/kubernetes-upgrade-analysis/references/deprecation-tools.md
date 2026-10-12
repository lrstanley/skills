# Deprecation Detection

Find deprecated and removed APIs in the live cluster and in the GitOps repos, using local tools
when present and a documented fallback when not.

## When to use / not use

- Step 4, every scope. For `component` scope still scan: a component upgrade often changes the
  API versions it serves or consumes.
- Tool output is evidence, not the answer. Cross-check the upstream guide:
  https://kubernetes.io/docs/reference/using-api/deprecation-guide/

## 1. Detect installed tools

```bash
for t in pluto kubent kubepug kubeconform kustomize helm flux argocd gh; do
  command -v "$t" >/dev/null 2>&1 && echo "$t: $(command -v "$t")" || echo "$t: not installed"
done > evidence/tools.txt
pluto version 2>/dev/null; kubent --version 2>/dev/null; kubepug --version 2>/dev/null
```

Record each tool and version in the report's methodology. Never install tools without asking;
list missing useful ones under "Suggested tooling":

| Tool | Scans | Project |
| --- | --- | --- |
| `pluto` | files, rendered Helm, live Helm releases, live API resources | https://github.com/FairwindsOps/pluto |
| `kubent` | live cluster objects, Helm releases, files | https://github.com/doitintl/kube-no-trouble |
| `kubepug` | live cluster, files | https://github.com/kubepug/kubepug |
| `kubeconform` | schema validation of rendered manifests at a target version | https://github.com/yannh/kubeconform |

Run every installed scanner that applies; each has different data coverage, and disagreement is
worth noting. Confirm flags with `--help` for the installed version.

## 2. Check the tool data covers the target

Scanners embed a static removals table. If it predates the target, a clean result means
nothing. Check (`pluto list-versions`, release date vs target release date) and record
`partial coverage` in the report if the tool is older than the target.

## 3. Scan with the target version set

`T=v1.37.0`. Also scan `T+1` and `T+2` where the tool knows them: findings that only appear
there do not block this upgrade but cap headroom.

```bash
# GitOps repo files and rendered output
pluto detect-files -d "$REPO_DIR" --target-versions "k8s=$T" -o wide
kustomize build <path> | pluto detect - --target-versions "k8s=$T" -o wide
helm template <release> <chart> -f values.yaml | pluto detect - --target-versions "k8s=$T" -o wide

# live cluster (Helm release metadata and API resources)
pluto detect-helm --kube-context "$CTX" --target-versions "k8s=$T" -o wide
pluto detect-api-resources --kube-context "$CTX" --target-versions "k8s=$T" -o wide

kubent --context "$CTX" --target-version "${T#v}" -o json > evidence/api-kubent.json
kubepug --k8s-version "$T" --input-file "$REPO_DIR" --format json    # repo; omit input for live
```

- Use `-o json` redirected to `evidence/api-<tool>.json` for the record and `-o wide` for the
  summary. `--only-show-removed` limits output to removals in the target.
- If pluto lacks `--kube-context`, use a minified kubeconfig in a private temp dir for those
  calls only and delete it afterwards. Never write it into the repo or report.
- **kubeconform** needs rendered manifests (`kustomize build`, `helm template`, `flux build
  kustomization <name> --path <dir> --dry-run`):

```bash
kustomize build <path> | kubeconform -kubernetes-version "${T#v}" -strict -ignore-missing-schemas \
  -summary -output json -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

  Flux `postBuild` variables are not substituted by plain `kustomize build`, which can cause
  false failures; `-ignore-missing-schemas` hides unknown CRDs, so count them and list their
  groups as "not schema-validated".

## 4. Live evidence from the API server and CRDs

The API server records which deprecated APIs clients actually call, which catches controllers
using old versions that no repo scan sees.

```bash
for i in 1 2 3 4 5 6; do
  kubectl --context "$CTX" get --raw /metrics | grep '^apiserver_requested_deprecated_apis'
  sleep 1
done | sed 's/ [0-9.e+]*$//' | sort | uniq -c | sort -rn > evidence/apiserver-deprecated-apis.txt
```

- **Sample repeatedly.** HA control planes sit behind a load balancer, so one scrape can miss a
  series another API server has. The leading count is how many samples saw the series; record
  the sample count.
- Labels: `group`, `version`, `resource`, `removed_release`. A series with `removed_release`
  less than or equal to the target is a **blocker** until its caller is upgraded.
  `removed_release` is often blank for non-core (CRD) groups: treat those as `crd` findings and
  look up the removal in the owning component's release notes.
- The metric does not name the caller; correlate the API group to the CRD owner and its
  controller, or use audit logs (`k8s.io/deprecated=true`) if available. The metric resets when
  an API server restarts.
- **CRD stored versions**: from `evidence/crds.tsv`, CRDs with more than one stored version or a
  deprecated stored version are `crd` findings owned by the operator, and a prerequisite step
  (the operator's storage-migration procedure) before it upgrades. Confirm the removal version
  in the operator's release notes.
- Managed providers may offer their own readiness checks (EKS upgrade insights, GKE deprecation
  insights, AKS deprecated API detection); cite and save them if available.

## 5. Fallback when tools are missing

1. Read the deprecation guide for each minor from current to target; extract removed APIs and
   replacements into a short list.
2. `kubectl api-resources --verbs=list -o wide`, and CRDs with deprecated served versions
   (`evidence/crds.tsv`).
3. Grep the GitOps repos for the removed `apiVersion`/`kind` pairs, and grep rendered Helm and
   Kustomize output too (templates hide versions behind helpers).
4. State in the report that scanning was manual and confidence is lower.

## 6. Finding format

Each finding becomes one row in the report's "API deprecations" section:

| Field | Meaning |
| --- | --- |
| Severity | `blocker`, `warn`, `info` |
| Scope | `core` (Kubernetes removes the API) or `crd` (a component drops an API or stored version) |
| API | `group/version Kind` |
| Removed in | free text with the product: `k8s 1.25`, `flux 2.8` |
| Count / Owner / Where | affected objects (sample, do not list hundreds); responsible component; `live`, `repo:<path>:<line>`, or `rendered:<release>` |
| Fix | replacement version, or the migration/prerequisite step |

Severity: `blocker` blocks the upgrade path (a `core` API removed at or below the target, or a
`crd` removal caused by a prerequisite component upgrade); `warn` is deprecated with removal
within two minors (core) or the next one or two component releases (crd); `info` is further
out or unknown. Deduplicate by API plus owner, group by owner, and map every `blocker` to a
plan batch.

## Anti-patterns

- Reporting "no deprecations" with an out-of-date scanner, an RBAC-denied probe, or a single
  API server scrape.
- Scanning only the repo or only the cluster; run both and reconcile.
- Trusting a chart's `appVersion` as proof its rendered manifests are clean; render them.
- Dumping raw tool output in the report; redirect into `evidence/` and summarize.
