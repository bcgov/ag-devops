# ag-helm Helm Library Chart

This is a Helm **library chart** that provides reusable, consistent templates for common Kubernetes resources.
It is designed for a “set + define” authoring style:

- **set** a small dictionary (your inputs)
- **define** small, file-local YAML fragments (ports, env, probes, selectors)
- **include** an `ag-template.*` template

The most important template in this repo is the NetworkPolicy helper:

- `ag-template.networkpolicy` — single entrypoint supporting **intent-based** inputs (recommended) and raw ingress/egress

Reference: see `docs/SIMPLE-API.md` for a full, precise input/output contract.

## OpenShift focus

This library is primarily used in OpenShift-based deployments.

- For external HTTP(S) access, prefer **OpenShift Routes** via `ag-template.route.openshift`.
- Kubernetes Ingress (`ag-template.ingress`) is available for clusters where an Ingress controller is used, but it is typically secondary in OpenShift.
- If you expose a service externally (Route/Ingress), your NetworkPolicy must allow ingress from the platform router/ingress pods to your workload on the service port.

## Glossary (read this first)

These docs use Helm-isms that are easy to miss if you don’t live in templates every day.

- **Dict / `$p`**: a Helm map you build and pass into a library template.
  - Helm `include` can only pass **one** object, so the library uses a dict as the “parameter object”.
  - `$p` is just a variable name (short for “params”). It can be `$params`, `$cfg`, etc.
- **Fragment / Hook**: a *string* containing the name of a `define` block.
  - Example: setting `Ports: "webapi.ports"` tells the library to run `include "webapi.ports" $p`.
  - Fragments let you keep small YAML snippets next to the resource that uses them.
- **Entrypoint**: a public template under `ag-template.*` that renders a full Kubernetes resource.
  - Example: `ag-template.deployment` renders an `apps/v1` Deployment.
- **`ModuleValues`**: the section of values for *this one component* (replicas, image tag/digest, resources, etc.).
  - Example: if your chart has `.Values.backend`, you typically pass that as `ModuleValues`.

## Quick start

### 1) Depend on the library chart

In your chart `Chart.yaml`:

```yaml
dependencies:
  - name: ag-helm-templates
    version: 1.0.3
    repository: file://../shared-lib/ag-helm
    # Optional: set an alias if you prefer a shorter dependency name.
    # alias: ag-helm
```

### 2) Use the public entrypoints

The public library templates are available under `ag-template.*`.

## Public templates (what you can call)

Workloads:
- `ag-template.deployment` — `apps/v1` Deployment
- `ag-template.statefulset` — `apps/v1` StatefulSet
- `ag-template.job` — `batch/v1` Job

Networking:
- `ag-template.service` — `v1` Service
- `ag-template.route.openshift` — OpenShift Route (preferred on OpenShift; renders only when `.Values.route.enabled` or `.ModuleValues.route.enabled` is true)
- `ag-template.ingress` — Kubernetes Ingress (optional; apiVersion selected from `.Capabilities.KubeVersion.GitVersion`)
- `ag-template.networkpolicy` — `networking.k8s.io/v1` NetworkPolicy (intent inputs + raw inputs)

Reliability and scheduling:
- `ag-template.hpa` — `autoscaling/v2` HorizontalPodAutoscaler
- `ag-template.pdb` — `policy/v1` PodDisruptionBudget
- `ag-template.pvc` — `v1` PersistentVolumeClaim
- `ag-template.priorityclass` — `scheduling.k8s.io/v1` PriorityClass

Notes:
- `ConfigMap`, `Secret`, and `CronJob` templates are intentionally not provided by this library.
- Helper templates like `ag-template.commonLabels` are used internally and may be useful in advanced cases.

## Conventions (what the library enforces)

### Naming

Most resources are named:

```
<ApplicationGroup>-<Name>
```

This is why **both** `ApplicationGroup` and `Name` matter.

### Labels

All resources get baseline labels:

- `app.kubernetes.io/name: <Name>`
- `app.kubernetes.io/part-of: <ApplicationGroup>`

Workloads (Deployments/StatefulSets/Jobs) also set a **pod label**:

- `data-class: "low|medium|high"` (default: `low`)

The value comes from `ModuleValues.dataClass` (preferred) or `DataClass`.

### Common labels/annotations from values

Many templates merge `Values.commonLabels` via `ag-template.commonLabels`.
This allows you to globally inject org-required labels like `environment`, `owner`, `project`.

## Authoring pattern: “set + define + include”

You typically:

1) build a dict (usually called `$p`)
2) set required keys (group/name/values/module)
3) set fragment hooks (template names)
4) include the library template

Example: Deployment

```yaml
{{- $p := dict "Values" .Values -}}
{{- /* REQUIRED identity */ -}}
{{- $_ := set $p "ApplicationGroup" .Values.project -}}
{{- $_ := set $p "Name" "web-api" -}}

{{- /* Common inputs */ -}}
{{- $_ := set $p "Namespace" $.Release.Namespace -}}
{{- $_ := set $p "Registry" "docker.io/myorg" -}}
{{- $_ := set $p "ModuleValues" .Values.backend -}}

{{- /* Fragment hooks (strings naming a define block) */ -}}
{{- $_ := set $p "Ports" "webapi.ports" -}}
{{- $_ := set $p "Env" "webapi.env" -}}
{{- $_ := set $p "Probes" "webapi.probes" -}}

{{ include "ag-template.deployment" $p }}

{{- define "webapi.ports" -}}
- name: http
  containerPort: 8080
  protocol: TCP
{{- end }}

## Fragment output shapes (common source of confusion)

Fragments are plain `define` blocks that emit YAML. What they must emit depends on where the library includes them:

- **List item fragments** (must emit items starting with `-`):
  - `Ports`, `Env`, `ServicePorts`, `PullSecret`, `Tolerations`, `VolumeMounts`, `Volumes`, `InitContainers`, `SidecarContainers`
  - NetworkPolicy: `IngressTemplate`, `EgressTemplate`
- **Map fragments** (must emit a YAML map without a leading list dash):
  - `LabelData`, `AnnotationData`, `Selector`
- **Inline object fragments** (must emit full keys like `livenessProbe:`):
  - `Probes`, `Lifecycle`, `SecurityContext`, `Resources`

If a fragment emits the wrong shape, the resulting manifest will be invalid YAML or invalid Kubernetes schema.

{{- define "webapi.env" -}}
- name: ASPNETCORE_URLS
  value: http://+:8080
{{- end }}

{{- define "webapi.probes" -}}
livenessProbe:
  httpGet:
    path: /health/live
    port: http
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
{{- end }}
```

### Deployment contract (what it actually reads)

The template `ag-template.deployment` lives in `shared-lib/ag-helm/templates/_deployment.tpl`.
It builds the final Deployment by calling an internal renderer with a normalized dict.

Required keys on your `$p`:

- `ApplicationGroup` (string)
- `Name` (string)
- `Registry` (string)
- `ModuleValues` (map)
  - `image.tag` (string) **required** unless `image.digest` is set
  - `image.digest` (string) optional (preferred if you pin images by digest)

Common optional keys on your `$p`:

- `Namespace` (string)
- `Values` (map) — used by label helpers like `ag-template.commonLabels`
- Fragment hooks (string template names): `Ports`, `Env`, `Lifecycle`, `Probes`, `Volumes`, `VolumeMounts`, `InitContainers`, `SidecarContainers`, `LabelData`, `AnnotationData`, `PullSecret`, `Tolerations`, `SecurityContext`, `Resources`

Common `ModuleValues` fields supported by `ag-template.deployment`:

- `replicas`, `revisionHistoryLimit`, `progressDeadlineSeconds`
- `resources` (if you prefer values-driven resources instead of a `Resources` fragment)
- `serviceAccountName`, `priorityClassName`, `terminationGracePeriod`, `automountServiceAccountToken`
- `affinity`, `topologySpreadConstraints`, plus toggles like `disableDefaultAntiAffinity`

## NetworkPolicy (deep dive)

### Background: what you’re modelling

Kubernetes NetworkPolicy is **selector-based**:

- A policy selects pods via `spec.podSelector`
- Adding `policyTypes: [Egress]` changes egress to **default-deny** unless allowed
- Rules allow traffic via `podSelector`, `namespaceSelector`, or `ipBlock`

This library provides one NetworkPolicy entrypoint:

- **Recommended**: `ag-template.networkpolicy` (supports intent-style inputs, and also supports raw lists/fragments when needed)

### Recommended: `ag-template.networkpolicy`

Use this when you want to say *what* is allowed without hand-writing full ingress/egress YAML.

#### Core inputs

- `ApplicationGroup` (required)
- `Name` (required)
- `Namespace` (optional; defaults to release namespace)
- `PolicyTypes` (optional; defaults to `["Ingress", "Egress"]`)
- `PodSelector` (optional; defaults to `app.kubernetes.io/name` + `app.kubernetes.io/part-of`)

#### Intent inputs

Ingress intent (`AllowIngressFrom`):

- `apps`: list of app names (matches `app.kubernetes.io/name`) with optional per-app ports
- `namespaces`: namespaceSelector + optional podSelector + ports
- `ipBlocks`: CIDR blocks + ports
- `ports`: default ports when a peer omits ports

Egress intent (`AllowEgressTo`):

- `apps`: same idea as ingress (service-to-service)
- `namespaces`: namespaceSelector + optional podSelector + ports
- `ipBlocks`: CIDR blocks + ports
- `internet`: explicit internet egress via `ipBlock` CIDRs

#### Example: backend policy (service-to-service + external CIDR)

```yaml
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}

{{- /* Select only backend pods */ -}}
{{- $_ := set $np "PodSelector" (dict "matchLabels" (dict
  "app.kubernetes.io/name" "web-api"
  "app.kubernetes.io/part-of" .Values.project
)) -}}

{{- /* Ingress: allow from frontend within same namespace */ -}}
{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8080)
  "apps" (list (dict "name" "react-baseapp"))
) -}}

{{- /* Egress: allow to postgres + a specific external CIDR on 443 */ -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list 5432)))
  "ipBlocks" (list (dict "cidr" "142.34.208.0/24" "ports" (list 443)))
) -}}

{{ include "ag-template.networkpolicy" $np }}
```

#### Example: lock a job down (egress-only)

```yaml
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "backup-egress" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}

{{- /* The policy selects ONLY the backup job pod */ -}}
{{- $_ := set $np "PodSelector" (dict "matchLabels" (dict
  "app.kubernetes.io/component" "pg_dumpall"
  "job" "postgres-job"
)) -}}

{{- /* Allow egress only to postgres */ -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list 5432)))
) -}}

{{ include "ag-template.networkpolicy" $np }}
```

### Advanced: raw inputs (same entrypoint)

Use this when you need full control or already have explicit ingress/egress YAML.

You can provide either:

- `IngressTemplate` / `EgressTemplate` (define blocks that emit list items)
- `Ingress` / `Egress` (structured lists)

Example: raw ingress template

```yaml
{{- $np := dict "ApplicationGroup" .Values.project "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Ingress") -}}
{{- $_ := set $np "IngressTemplate" "webapi.np.ingress" -}}
{{ include "ag-template.networkpolicy" $np }}

{{- define "webapi.np.ingress" -}}
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Namespace }}
  ports:
  - protocol: TCP
    port: 8080
{{- end }}
```

### Common NetworkPolicy pitfalls

- If `PolicyTypes` includes `Egress` and you provide **no** egress rules, the selected pods become **egress-denied**.
- `podSelector` defaults matter: if you don’t provide `PodSelector`, the policy matches pods with
  `app.kubernetes.io/name=<Name>` and `app.kubernetes.io/part-of=<ApplicationGroup>`.
- NetworkPolicy cannot allow by hostname; use `ipBlock` CIDRs or platform egress controls.

## Other resources (brief)

This library also includes templates for:

- `ag-template.service`
- `ag-template.serviceaccount`
- `ag-template.pdb` / `ag-template.hpa` / `ag-template.pvc`
- `ag-template.job`
- `ag-template.route.openshift` (if you use OpenShift Routes)
- `ag-template.ingress` (if you use Kubernetes Ingress)
- `ag-template.priorityclass`

## Further reading

- `docs/SIMPLE-API.md` (input/output contract and schemas)
- `docs/EXAMPLES.md` (copy/paste examples for common patterns)
- `templates/_networkpolicy.tpl` (implementation of intent inputs)
