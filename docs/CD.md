# CD documentation — Helm library + Kubernetes policy requirements

![Helm](https://img.shields.io/badge/Helm-Library%20Chart-blue)
![OpenShift](https://img.shields.io/badge/OpenShift-Route%20first-red)
![NetworkPolicy](https://img.shields.io/badge/NetworkPolicy-Required-important)
![OPA](https://img.shields.io/badge/OPA%20%2F%20Conftest-Rego%20policies-purple)
![Datree](https://img.shields.io/badge/Datree-Policy%20as%20Code-brightgreen)
![Polaris](https://img.shields.io/badge/Polaris-Audit%20rules-informational)
![kube--linter](https://img.shields.io/badge/kube--linter-Lint%20rules-yellow)

This document is the **full reference** for consuming the CD assets in this repository:

- Helm library chart: `https://github.com/bcgov/ag-devops/tree/main/cd/shared-lib/ag-helm/`
- Example consumer chart: `https://github.com/bcgov/ag-devops/tree/main/cd/shared-lib/example-app/`
- OCI registry: `ghcr.io/bcgov/helm/ag-helm-templates:{version}`
- Policy configuration: `https://github.com/bcgov/ag-devops/tree/main/cd/policies/`

If you are looking for CI (GitHub Actions templates), see: `docs/CI.md`.

## Quick links

- Helm library consumption: `cd/shared-lib/ag-helm/`
- Helm library contract: `cd/shared-lib/ag-helm/docs/SIMPLE-API.md`
- Helm library examples: `cd/shared-lib/ag-helm/docs/EXAMPLES.md`
- Policy configs (Datree/Polaris/kube-linter/Rego): `cd/policies/`

---

## 1) Helm library chart: `ag-helm-templates`

Location: `cd/shared-lib/ag-helm/`

This is a Helm **library chart** providing reusable resource templates under `ag-template.*`.

Source of truth inside this repo:

- Public interface/required inputs: `cd/shared-lib/ag-helm/docs/SIMPLE-API.md`
- Copy/paste examples: `cd/shared-lib/ag-helm/docs/EXAMPLES.md`
- Implementation: `cd/shared-lib/ag-helm/templates/`

### 1.1 Design goals

- A consistent “**set + define + include**” authoring pattern
- Standardized naming/labels
- OpenShift-first networking (Routes as the default external exposure)
- Strong NetworkPolicy support with intent-based authoring

### 1.2 Key concepts (Helm glossary)

- **Parameter dict**: Helm can pass only one object into `include`, so the library uses a dict (commonly `$p`).
- **Fragment hook**: a string naming a `define` block that emits YAML (ports/env/probes/selectors).
- **Entrypoint**: the public templates you call: `ag-template.*`.
- **ModuleValues**: values subtree for a single component (e.g., `.Values.backend`).

### 1.3 How to consume the library

#### Option A (recommended): Depend on the published OCI chart from GHCR

Publishing details: `cd/shared-lib/ag-helm/PUBLISHING.md`

In your app chart `Chart.yaml`:

```yaml
dependencies:
  - name: ag-helm-templates
    version: "1.0.3"
    repository: "oci://ghcr.io/bcgov-c/helm"
```

Then:

```bash
# if private
echo $GITHUB_TOKEN | helm registry login ghcr.io -u <github-user> --password-stdin

helm dependency update
```

#### Option B (contributors only): Local development dependency (file reference)

This option is intended for **working on the Helm library chart itself inside this repo**.
Application teams should consume the library via **OCI** so everyone is on an immutable, released version.

```yaml
dependencies:
  - name: ag-helm-templates
    version: 1.0.3
    repository: file://../shared-lib/ag-helm
```

### 1.4 Public entrypoints you can call (`ag-template.*`)

Workloads
- `ag-template.deployment`
- `ag-template.statefulset`
- `ag-template.job`

Networking
- `ag-template.service`
- `ag-template.route.openshift` (preferred on OpenShift)
- `ag-template.ingress` (optional)
- `ag-template.networkpolicy` (central / most important)

Reliability & scheduling
- `ag-template.hpa`
- `ag-template.pdb`
- `ag-template.pvc`
- `ag-template.priorityclass`

Identity
- `ag-template.serviceaccount`

Notes
- ConfigMap/Secret/CronJob templates are intentionally not provided by the library.

### 1.4.1 Contract cheat sheet (required inputs + key behaviors)

This is the “what do I *have* to pass?” view. For the full contract, use `cd/shared-lib/ag-helm/docs/SIMPLE-API.md`.

Workloads

- `ag-template.deployment`
  - Required: `ApplicationGroup`, `Name`, `Registry`, `ModuleValues` (`image.digest` **or** `image.tag`)
  - Common optional: `Values` (enables `commonLabels` + `global.openshift`), `Namespace`
  - Key behaviors:
    - If `ModuleValues.disabled=true`, renders nothing
    - If `image.digest` is set, the image is rendered as `registry/name@sha256:...` (tag not required)
    - Otherwise `image.tag` is required
    - `DataClass` label is derived from `ModuleValues.dataClass` (or the parameter dict `DataClass`), defaults to `low`, and invalid values fail the render
    - If `Lang=dotnetcore`, the pod gets Datadog autodiscovery annotations for OpenMetrics at `/metrics`

- `ag-template.statefulset`
  - Required: `ApplicationGroup`, `Name`, `Registry`, `ServiceName`, `ModuleValues.image.tag`

- `ag-template.job`
  - Required: `ApplicationGroup`, `Name`, `Registry`

Networking

- `ag-template.service`
  - Required: `ApplicationGroup`, `Name`, and a ports fragment (recommended: `ServicePorts` **define**)

- `ag-template.route.openshift` (OpenShift preferred)
  - Required: `Values`, `ApplicationGroup`, `Name`, `Namespace`
  - Values-driven:
    - Reads `.ModuleValues.route` first, then falls back to `.Values.route`
    - Renders only when `route.enabled: true`
    - Requires `route.host`
    - Requires `route.annotations["aviinfrasetting.ako.vmware.com/name"]` (template uses `required`)

- `ag-template.ingress`
  - Required: `Name`, `Capabilities`, `Hosts`, `ServiceName`, `ServicePort`
  - Requires `Annotations["aviinfrasetting.ako.vmware.com/name"]` (template uses `required`)

- `ag-template.networkpolicy`
  - Required: `ApplicationGroup`, `Name`
  - Supports raw rules (`Ingress`/`Egress`), fragments (`IngressTemplate`/`EgressTemplate`), and intent inputs (`AllowIngressFrom`/`AllowEgressTo`).

Reliability & scheduling

- `ag-template.hpa`: `ApplicationGroup`, `Name`, `MinReplicas`, `MaxReplicas`
- `ag-template.pdb`: values-driven (`.ModuleValues.pdb` first, else `.Values.pdb`)
- `ag-template.pvc`: `ApplicationGroup`, `Name`, `Storage`
- `ag-template.priorityclass`: `Name`, `Value`

Identity

- `ag-template.serviceaccount`
  - Required: `ApplicationGroup`, `Name`
  - Optional: `AnnotationData`/`LabelData` fragments, plus explicit `Annotations`/`Labels`

### 1.5 Authoring pattern (set + define + include)

Typical shape for a Deployment:

```yaml
{{- $p := dict "Values" .Values -}}
{{- $_ := set $p "ApplicationGroup" .Values.project -}}
{{- $_ := set $p "Name" "web-api" -}}
{{- $_ := set $p "Namespace" $.Release.Namespace -}}
{{- $_ := set $p "Registry" "ghcr.io/my-org" -}}
{{- $_ := set $p "ModuleValues" .Values.backend -}}

{{- $_ := set $p "Ports" "webapi.ports" -}}
{{- $_ := set $p "Env" "webapi.env" -}}
{{- $_ := set $p "Probes" "webapi.probes" -}}

{{ include "ag-template.deployment" $p }}

{{- define "webapi.ports" -}}
- name: http
  containerPort: 8080
  protocol: TCP
{{- end }}

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

Practical tips:

- Prefer passing `Values: .Values` even when not strictly required; the library reads shared knobs from it (for example `global.openshift` and `commonLabels`).
- Prefer digest pinning (`ModuleValues.image.digest`) when available; otherwise set `ModuleValues.image.tag`.
- Set `ModuleValues.dataClass` to `low|medium|high` (defaults to `low`). Invalid values fail the render.
- Set `ModuleValues.image.pullPolicy: Always` if your platform policy requires it (Datree policy in `cd/policies/datree-policies.yaml`).

### 1.6 Fragment output shapes (critical)

Your fragments must emit YAML in the shape the library expects:

List item fragments (must emit `- ...` items)
- `Ports`, `Env`, `ServicePorts`, `PullSecret`, `Tolerations`, `VolumeMounts`, `Volumes`, `InitContainers`, `SidecarContainers`
- NetworkPolicy: `IngressTemplate`, `EgressTemplate`

Map fragments (must emit a map)
- `LabelData`, `AnnotationData`, `Selector`

Inline object fragments (emit full keys)
- `Probes`, `Lifecycle`, `SecurityContext`, `Resources`

### 1.7 OpenShift Routes vs Kubernetes Ingress

- On OpenShift, prefer `ag-template.route.openshift`.
- Route/Ingress must include the AVI infra setting annotation `aviinfrasetting.ako.vmware.com/name` (the templates fail rendering if it’s missing).
- If you expose anything externally (Route/Ingress), your NetworkPolicy must allow ingress from the platform router/ingress pods to your workload ports.

### 1.8 OpenShift mode (`global.openshift`)

Enable OpenShift mode in your chart values:

```yaml
global:
  openshift: true
```

Observed behaviors in the library:

- Default container `securityContext` does **not** pin `runAsUser`/`runAsGroup` when `global.openshift=true` (OpenShift SCC assigns runtime UID/GID).
- Workload manifests add a `checkov.io/skip999` annotation explaining the above (for `CKV_K8S_40`).

### 1.9 NetworkPolicy guidance

The library’s `ag-template.networkpolicy` supports:

- Intent-based inputs (recommended)
- Raw ingress/egress lists when you need full control

Important constraints enforced by policies in this repo:

- Deployments should have a matching NetworkPolicy (Polaris `networkPolicyRequired` / `missingNetworkPolicy`)
- NetworkPolicies must not contain allow-all patterns (empty rules, missing `from/to`, missing ports)
- Internet-wide egress (`0.0.0.0/0` or `::/0`) requires approval metadata

> **Why the rules are strict**
> 
> The Rego policy in `cd/policies/network-policies.rego` explicitly denies “accidental allow-all” shapes such as:
> 
> - `ingress: - {}` / `egress: - {}`
> - ingress rules without `from` (would allow all sources)
> - ingress rules without `ports` (would allow all ports)
> - egress rules without `to` (would allow all destinations)
> - egress rules without `ports` (would allow all ports)
> - wildcard peers inside `from/to` (empty objects or `podSelector: {}`)

#### 1.9.1 Default deny vs allow rules

- Emerald supports “default deny” NetworkPolicies (no ingress/egress rules). However, **this repo’s policy tooling expects explicit allow rules** for workloads (for example to prove intent and avoid accidental breakage).
- Treat default deny as an *implementation detail* of the cluster. For application charts in this repo, start with a minimal allow policy and then add only what your service needs.

Rule of thumb:

- If you add `ingress`/`egress` rules, make them explicit: **always** specify peers and ports.

#### 1.9.2 Internet egress approvals (required annotations)

If you add egress to `0.0.0.0/0` (or `::/0`), `cd/policies/network-policies.rego` requires the NetworkPolicy to include BOTH annotations:

```yaml
metadata:
  annotations:
    justification: "Why this service needs internet-wide egress"
    approvedBy: "Name or ticket reference"
```

Without both, Conftest denies the manifest.

#### 1.9.3 Recommended authoring: intent inputs

Start with `AllowIngressFrom` / `AllowEgressTo`. This keeps policies readable and avoids accidental allow-all.

**Copy/paste starter (most services)**

```tpl
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}

{{- /* Make intent explicit */ -}}
{{- $_ := set $np "PolicyTypes" (list "Ingress" "Egress") -}}

{{- /* Ingress: allow from specific apps in the same namespace */ -}}
{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8080)
  "apps" (list (dict "name" "frontend"))
) -}}

{{- /* Egress: allow to database app + HTTPS to a specific CIDR */ -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list (dict "port" 5432 "protocol" "TCP"))))
  "ipBlocks" (list (dict "cidr" "142.34.208.0/24" "ports" (list 443)))
) -}}

{{ include "ag-template.networkpolicy" $np }}
```

> If you need internet-wide egress, set the approval annotations on the NetworkPolicy (and keep ports specific):
>
> ```tpl
> {{- $_ := set $np "Annotations" (dict
>   "justification" "Reason for internet-wide egress"
>   "approvedBy" "Ticket/approver"
> ) -}}
> ```

For the full intent schema (what `apps`, `namespaces`, `ipBlocks`, and `ports` can look like), see:

- `cd/shared-lib/ag-helm/docs/SIMPLE-API.md` → `ag-template.networkpolicy` → “Intent schemas”

#### 1.9.4 OpenShift Route: allow router ingress (common gotcha)

If you expose a service via an OpenShift Route, you typically need ingress allowed from the router pods.

The Helm library examples include a copy/paste pattern that allows ingress from the `openshift-ingress` namespace while still restricting to the ingress controller labels. Use it as your starting point and confirm labels in your cluster:

- `cd/shared-lib/ag-helm/docs/EXAMPLES.md` (“OpenShift Route + NetworkPolicy allowing router ingress”)

#### 1.9.5 Raw rules and fragments (advanced)

Use raw `Ingress`/`Egress` or fragments (`IngressTemplate`/`EgressTemplate`) only when intent inputs can’t express what you need.

Key rule: fragment templates must emit **list items only** (lines starting with `-`), and must not emit `ingress:`/`egress:` keys.

#### 1.9.6 NetworkPolicy checklist (ship-ready)

- [ ] Every workload has a matching NetworkPolicy (render and test all manifests together so cross-resource checks are possible).
- [ ] No rules shaped like allow-all (`- {}`, missing peers, missing ports).
- [ ] Router/ingress traffic is explicitly allowed for externally exposed services.
- [ ] Internet egress is avoided; when required it has `justification` and `approvedBy` annotations.

> **DO** keep peers and ports explicit.
>
> **DON'T** rely on implicit defaults (they usually become allow-all).

#### 1.9.7 NetworkPolicy cookbook (copy/paste recipes)

These recipes are designed to be compatible with:

- Helm library intent inputs (`AllowIngressFrom` / `AllowEgressTo`)
- The deny rules in `cd/policies/network-policies.rego` (no accidental allow-all)

All snippets assume you’re building a `$np` dict like this (adjust `Name` and ports):

```tpl
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
```

**Recipe A: Allow ingress from another app in the same namespace**

```tpl
{{- $_ := set $np "PolicyTypes" (list "Ingress") -}}
{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8080)
  "apps" (list (dict "name" "frontend"))
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

**Recipe B: Allow ingress from OpenShift router pods (when using Routes/Ingress)**

Start from the library example and **confirm router labels in your cluster**:

- `cd/shared-lib/ag-helm/docs/EXAMPLES.md` (“OpenShift Route + NetworkPolicy allowing router ingress”)

Typical starting point:

```tpl
{{- $_ := set $np "PolicyTypes" (list "Ingress") -}}
{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8080)
  "namespaces" (list (dict
    "name" "openshift-ingress"
    "podSelector" (dict "matchLabels" (dict
      "ingresscontroller.operator.openshift.io/deployment-ingresscontroller" "default"
    ))
  ))
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

**Recipe C: Allow egress to a database app (same namespace)**

```tpl
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list (dict "port" 5432 "protocol" "TCP"))))
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

**Recipe D: Allow egress HTTPS to a specific CIDR (preferred over internet-wide)**

```tpl
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "ipBlocks" (list (dict
    "cidr" "142.34.208.0/24"
    "ports" (list 443)
  ))
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

**Recipe E: Approved internet-wide egress (last resort)**

This will be denied unless you include both approval annotations.

```tpl
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}
{{- $_ := set $np "Annotations" (dict
  "justification" "Reason for internet-wide egress"
  "approvedBy" "Ticket/approver"
) -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "internet" (dict
    "enabled" true
    "cidrs" (list "0.0.0.0/0")
    "ports" (list 443)
  )
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

**Recipe F: Raw rules (advanced; use when intent isn’t enough)**

Raw rules must stay explicit: include peers *and* ports.

```tpl
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}
{{- $_ := set $np "Egress" (list
  (dict
    "to" (list (dict "ipBlock" (dict "cidr" "142.34.208.0/24")))
    "ports" (list (dict "protocol" "TCP" "port" 443))
  )
) -}}
{{ include "ag-template.networkpolicy" $np }}
```

---

## 2) Example consumer chart

Location: `cd/shared-lib/example-app/`

This chart demonstrates:

- Consuming the library via Helm dependencies
- Using “set + define” fragments
- NetworkPolicy usage

Local run:

```powershell
helm dependency update .\cd\shared-lib\example-app
helm lint .\cd\shared-lib\example-app
helm template ex .\cd\shared-lib\example-app --values .\cd\shared-lib\example-app\values-examples.yaml --debug
```

---

## 3) Policy-as-code (required manifest checks)

Location: `cd/policies/`

### 3.1 Pipeline pattern (how you apply policies)

All policy tools assume you have rendered YAML.

Recommended pattern:

1. Render: `helm template ... > rendered.yaml`
2. Validate: run Datree + Polaris + kube-linter + Conftest
3. Fail the pipeline if any tool reports violations

### 3.2 Tools, configs, and what each checks

#### Datree

Configs:
- `cd/policies/datree-policies.yaml`

Use for
- Org rules and schema-like validations

Representative checks
- Workload `DataClass` label must exist and be `Low|Medium|High`
- Route/Ingress must set `metadata.annotations["aviinfrasetting.ako.vmware.com/name"]` to one of:
  - `dataclass-low|dataclass-medium|dataclass-high|dataclass-public`
- Workload `metadata.labels.owner` required
- Workload `metadata.labels.environment` must be one of: `production`, `test`, `development`
- Avoid wildcard `host: "*"` for Ingress
- Image must include a version/tag (no floating)
- Resource requests/limits required
- Probes required
- `imagePullPolicy` must be `Always`

Run example

```bash
datree test rendered.yaml --policy-config cd/policies/datree-policies.yaml
```

#### Polaris

Config:
- `cd/policies/polaris.yaml`

Use for
- Security and reliability best practices with custom checks

Configured rules (what each one means and why it exists)

These are the checks enabled in `cd/policies/polaris.yaml`.

Security (pod isolation & least privilege)

- `hostIPCSet`: Pod uses the host IPC namespace.
  - Why: breaks isolation; can leak/observe host-level IPC objects.
  - Fix: remove `hostIPC: true`.

- `hostPIDSet`: Pod uses the host PID namespace.
  - Why: allows visibility into host processes; increases blast radius.
  - Fix: remove `hostPID: true`.

- `hostNetworkSet`: Pod uses the host network namespace.
  - Why: bypasses network isolation and can expose node networking.
  - Fix: remove `hostNetwork: true`.

- `privilegeEscalationAllowed`: container allows privilege escalation.
  - Why: enables setuid/setcap escalation paths.
  - Fix: set `securityContext.allowPrivilegeEscalation: false`.

- `runAsRootAllowed`: container may run as root.
  - Why: root in container is a common escalation pivot.
  - Fix: set `runAsNonRoot: true` and avoid `runAsUser: 0`.

- `runAsPrivileged`: container runs privileged.
  - Why: privileged containers are close to “host root”.
  - Fix: set `securityContext.privileged: false` and drop capabilities.

- `notReadOnlyRootFilesystem`: root filesystem is writable.
  - Why: writable root enables persistence and easier exploitation.
  - Fix: set `securityContext.readOnlyRootFilesystem: true`.

- `sensitiveContainerEnvVar`: likely secret-like values placed directly in env vars.
  - Why: env vars are easy to dump via process inspection and logs.
  - Fix: use `Secret` + `valueFrom.secretKeyRef` (or external secret operator patterns).

- `sensitiveConfigmapContent`: ConfigMap contains secret-like values.
  - Why: ConfigMaps are not protected like Secrets.
  - Fix: move sensitive values to `Secret`.

- `missingNetworkPolicy` (custom override in this repo): ensures a NetworkPolicy *matches the pod labels* and contains at least one rule direction.
  - Why: prevents “workload exists without any policy coverage” in deny-by-default clusters.
  - Fix: add a NetworkPolicy with `spec.podSelector.matchLabels` matching your pod labels and include either `spec.ingress` or `spec.egress`.

Reliability (availability & rollout safety)

- `statefulSetMissingReplicas` (custom): StatefulSet should explicitly set `spec.replicas`.
  - Why: avoids ambiguous scaling defaults and drift across environments.
  - Fix: set `spec.replicas`.

- `metadataAndInstanceMismatched`: instance metadata/labels don’t line up.
  - Why: inconsistent labels break selectors, dashboards, and policy matching.
  - Fix: ensure consistent `app.kubernetes.io/instance`/naming labels across resources.

- `hpaMaxAvailability`: HPA max replicas does not meet expected availability.
  - Why: prevents accidental “max=1” autoscaling configs.
  - Fix: set a sensible `maxReplicas`.

- `hpaMinAvailability`: HPA min replicas does not meet expected availability.
  - Why: avoids scaling to 0/1 when the service must stay available.
  - Fix: set a sensible `minReplicas`.

Images (supply chain hygiene)

- `tagNotSpecified`: image tag is missing.
  - Why: floating tags make rollbacks and auditability difficult.
  - Fix: pin tags or (preferred) use digest pinning.

- `pullPolicyNotAlways`: imagePullPolicy is not `Always`.
  - Why: enforces consistent pull behavior per platform policy.
  - Fix: set `imagePullPolicy: Always` when required by your cluster standards.

- `imageRegistry` (custom regex): image must come from an approved registry.
  - Why: reduces supply-chain risk by restricting sources.
  - Fix: use OpenShift internal registry, `ghcr.io`, `docker.io`, or approved Artifactory/JFrog endpoints.

Health checks (safe rollouts)

- `readinessProbeMissing`: container has no readiness probe.
  - Why: traffic may route to an unready app.
  - Fix: add `readinessProbe`.

- `livenessProbeMissing`: container has no liveness probe.
  - Why: deadlocks can persist indefinitely.
  - Fix: add `livenessProbe`.

Networking

- `tlsSettingsMissing`: missing TLS-related settings on applicable resources.
  - Why: encourages secure-by-default ingress exposure.
  - Fix: configure TLS where the platform expects it.

Project-specific checks

- `deploymentMissingReplicas` (custom): Deployment should explicitly set `spec.replicas`.
  - Why: avoids accidental single-replica deployments.
  - Fix: set `spec.replicas` (or enable HPA and set sane minReplicas).

- `priorityClassNotSet`: workload should set a PriorityClass.
  - Why: prevents critical workloads from being evicted before less important ones.
  - Fix: set `spec.template.spec.priorityClassName`.

- `networkPolicyRequired` (custom): Deployment should have a NetworkPolicy.
  - Why: ensures policy coverage is always present.
  - Fix: add a matching NetworkPolicy.

- `dataClassLabelRequired` (custom): pod must have `DataClass` label.
  - Why: ties routing/security controls to data classification.
  - Fix: set `ModuleValues.dataClass` (library will render `DataClass: Low|Medium|High`).

- `routeAviAnnotationRequired` (custom): Route must include `aviinfrasetting.ako.vmware.com/name`.
  - Why: required for platform ingress classification.
  - Fix: set the annotation to one of `dataclass-low|dataclass-medium|dataclass-high|dataclass-public`.

Run example

```bash
polaris audit --config cd/policies/polaris.yaml --format pretty rendered.yaml
```

#### kube-linter

Config:
- `cd/policies/kube-linter.yaml`

Use for
- Kubernetes lint checks and security posture checks

Included checks (partial)
- `run-as-non-root`, `privilege-escalation-container`, `privileged-container`
- `default-service-account`
- `latest-tag`
- `env-var-secret`
- `host-ipc`, `host-network`, `host-pid`
- selector mismatches / dangling services
- PDB min/max availability

Run example

```bash
kube-linter lint rendered.yaml --config cd/policies/kube-linter.yaml
```

#### Conftest / OPA (Rego)

Policies:
- `cd/policies/network-policies.rego`
- `cd/policies/routes-edge-termination.rego`
- `cd/policies/avi-infrasetting-annotation.rego`

Use for
- Hard deny rules that are easiest to express in Rego

Policy breakdown

1) `network-policies.rego`
- Deny Deployments without a matching NetworkPolicy
- Deny Deployments without `DataClass` or with invalid `DataClass`
- NetworkPolicy must have `policyTypes` and `podSelector`
- Deny empty `podSelector: {}` unless it is a default-deny policy
- Deny allow-all ingress/egress patterns:
  - `- {}` rules
  - missing `from/to`
  - missing ports
  - empty peer selectors / `podSelector: {}` peers
- Deny internet egress without justification/approval annotations

2) `routes-edge-termination.rego`
- Deny edge-terminated Routes unless:
  - allowlisted by label `app.kubernetes.io/component=frontend`, or
  - approved via annotation `isb.gov.bc.ca/edge-termination-approval`

3) `avi-infrasetting-annotation.rego`
- Deny Route/Ingress without `aviinfrasetting.ako.vmware.com/name`
- Deny invalid values outside the `dataclass-*` allowlist

Run example

```bash
conftest test rendered.yaml --policy cd/policies --all-namespaces --fail-on-warn
```

### 3.3 Which policy checks what (matrix)

| Concern | Datree | Polaris | kube-linter | Conftest/OPA |
|---|---:|---:|---:|---:|
| DataClass label present/valid | ✅ | ✅ (custom) | ❌ | ✅ |
| Owner/environment labels | ✅ | ❌ | ✅ (owner check) | ❌ |
| Image tags / latest tag | ✅ (version required) | ✅ (tagNotSpecified) | ✅ (latest-tag) | ❌ |
| Privileged / host namespaces | ✅ (some) | ✅ | ✅ | ❌ |
| Requests/limits | ✅ | ✅ | ❌ | ❌ |
| Probes | ✅ | ✅ | ❌ (excluded) | ❌ |
| NetworkPolicy exists | ✅ (custom) | ✅ (custom) | ❌ | ✅ |
| NetworkPolicy not allow-all | ✅ (custom) | (partial) | ❌ | ✅ |
| Route AVI annotation | ✅ | ✅ (custom) | ❌ | ✅ |
| Route edge termination approval | ❌ | ❌ | ❌ | ✅ |

---

## 4) Releases/publishing for the Helm library

- `cd/shared-lib/ag-helm/PUBLISHING.md` documents OCI tags and how to consume them.
- This repo’s release process uses Semantic Release to tag versions and push the chart to GHCR OCI:
  - `.github/workflows/release.yml`

---


