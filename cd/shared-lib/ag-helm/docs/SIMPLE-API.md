# Simple API: helm-library

This document defines the public interface for the `ag-helm` Helm *library chart*.
It describes the templates you can `include` (inputs) and what they render (outputs).

This is not an application API specification (it does not document HTTP endpoints or OpenAPI schemas).

## Usage pattern

Library templates are called by passing a dictionary to `include`:

```tpl
{{- include "ag-template.deployment" (dict
    "Values" .Values
    "ApplicationGroup" .Values.applicationGroup
    "Name" "my-service"
    "Registry" .Values.registry
    "ModuleValues" .Values.myService
) -}}
```

## Conventions

- Unless marked as **(define)**, all names are keys in the dict passed to `include`.
- **Required** keys must be present; otherwise templating may fail (or produce invalid YAML).
- **Optional** keys may be omitted; when omitted, the corresponding YAML fields are not emitted.
- `ModuleValues` is used by workload templates (Deployment/StatefulSet/Job). Other templates may ignore it.
- **Fragment hooks** are optional `define` blocks that allow callers to extend or override specific sections.
- “Outputs” describes the Kubernetes manifest(s) emitted by the template. Output is YAML text returned by `include`.

## Template reference

### ag-template.deployment

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `Registry` (string)
- `ModuleValues` (map)
  - `image.digest` (string) **OR** `image.tag` (string)
    - If `image.digest` is set, `image.tag` is not required.
    - If `image.digest` is not set, `image.tag` is required.

**Optional inputs**
- `Values` (map): parent `.Values` (used when the template reads shared configuration)
- `Namespace` (string): overrides the namespace; otherwise uses the Helm release namespace
- `Lang` (string): supports `dotnetcore` for Datadog autodiscovery annotations
- `ServiceAccountName` (string)
- `ModuleValues.disabled` (bool): when true, the template renders nothing
- `ModuleValues.image.pullPolicy` (string)
- `ModuleValues.replicas` (int)
- `ModuleValues.revisionHistoryLimit` (int)
- `ModuleValues.progressDeadlineSeconds` (int; default 600)
- `ModuleValues.terminationGracePeriod` (int)
- `ModuleValues.serviceAccountName` (string)
- `ModuleValues.automountServiceAccountToken` (bool)
- `ModuleValues.resources` (object)
- `ModuleValues.maxUnavailable` / `ModuleValues.maxSurge` (rolling update tuning)
- **Fragment hooks (define):** `Ports`, `Env`, `Probes`, `Volumes`, `VolumeMounts`, `InitContainers`, `Lifecycle`,
  `SecurityContext`, `SidecarContainers`, `Resources`, `AnnotationData`, `LabelData`, `PullSecret`, `Tolerations`

**Outputs**
- If `ModuleValues.disabled=true`: renders nothing
- Otherwise: one `apps/v1` Deployment with standard labels and the `data-class` label on the pod template

### ag-template.statefulset

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `Registry` (string)
- `ServiceName` (string): required for StatefulSet stable network identity
- `ModuleValues` (map)
  - `image.tag` (string)

**Optional inputs**
- `Values` (map)
- `Namespace` (string)
- `ModuleValues.disabled` (bool): when true, the template renders nothing
- `ModuleValues.image.pullPolicy` (string)
- `ModuleValues.replicas` (int)
- `ModuleValues.terminationGracePeriod` (int; default 30)
- `ModuleValues.resources` (object)
- **Fragment hooks (define):** `Ports`, `Env`, `Probes`, `Volumes`, `VolumeMounts`, `Resources`, `VolumeClaims`

**Outputs**
- If `ModuleValues.disabled=true`: renders nothing
- Otherwise: one `apps/v1` StatefulSet with the `data-class` label on the pod template and optional `volumeClaimTemplates`

### ag-template.job

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `Registry` (string)

**Optional inputs**
- `Values` (map)
- `Namespace` (string)
- `ModuleValues` (map)
  - `image.tag` (string; default `latest`)
  - `image.pullPolicy` (string)
  - `terminationGracePeriod` (int; default 30)
  - `resources` (object)
- Job spec tuning:
  - `BackoffLimit` (int; default 6)
  - `TTLSecondsAfterFinished` (int; default 86400)
  - `RestartPolicy` (string; default `Never`)
- Container:
  - `Command` (list)
  - `Args` (list)
- `ServiceAccountName` (string)
- `Annotations` (map): top-level Job metadata annotations
- **Fragment hooks (define):** `Env`, `VolumeMounts`, `Volumes`, `Resources`, `SecurityContext`,
  `InitContainers`, `SidecarContainers`, `AnnotationData`, `LabelData`, `PullSecret`, `Tolerations`, `PodAnnotationData`

**Outputs**
- One `batch/v1` Job with the `data-class` label on the pod template

### ag-template.service

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `ServicePorts` (**define**): renders the list of service ports

**Optional inputs**
- `Type` (string: `ClusterIP` | `NodePort` | `LoadBalancer`)
- `Headless` (bool)
- `IPFamilies` (**define**)

**Outputs**
- One `v1` Service (headless when requested)

### ag-template.serviceaccount

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)

**Optional inputs**
- `AnnotationData` (**define**)
- `LabelData` (**define**)
- `Annotations` (map)

**Outputs**
- One `v1` ServiceAccount with optional annotations/labels

### ag-template.ingress

**Required inputs**
- `Name` (string)
- `Capabilities` (object): pass `.Capabilities` so the template can select the correct Ingress apiVersion
- `Hosts` (list): items are `{ host: string, paths: [{ path: string, pathType: string (optional) }] }`
- `ServiceName` (string)
- `ServicePort` (int)

**Optional inputs**
- `Namespace` (string)
- `ClassName` (string)
- `Tls` (list): items are `{ secretName: string, hosts: [string] }`
- `Annotations` (map)
  - Required by repository policy: `aviinfrasetting.ako.vmware.com/name`
    - Allowed values: `dataclass-low`, `dataclass-medium`, `dataclass-high`, `dataclass-public`
- `LabelData` (**define**)
- `Labels` (map)
- `Values` (map): only used if you want `ag-template.commonLabels` merged into labels

**Outputs**
- One Kubernetes Ingress. The apiVersion is chosen based on `.Capabilities.KubeVersion.GitVersion`.

### ag-template.route.openshift

This template is values-driven and renders only when route is enabled.

**Required inputs**
- `Values` (map)
- `ApplicationGroup` (string)
- `Name` (string)
- `Namespace` (string)

**Optional inputs**
- `ModuleValues` (map)
- `LabelData` (**define**)
- `Labels` (map)

**Values read**
- Preferred: `.ModuleValues.route` (map)
- Fallback: `.Values.route` (map)
- When `route.enabled` is true, the template reads:
  - `route.host` (string, required)
  - `route.targetPort` (string, optional; default `http`)
  - `route.annotations` (map, required by repository policy)
    - Required key: `aviinfrasetting.ako.vmware.com/name`
      - Allowed values: `dataclass-low`, `dataclass-medium`, `dataclass-high`, `dataclass-public`

**Outputs**
- If route is disabled: renders nothing
- Otherwise: one `route.openshift.io/v1` Route

### ag-template.pdb

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)

**Optional inputs**
- `Values` (map)
- `Namespace` (string)
- `ModuleValues` (map)
- `Selector` (**define**): emits a `matchLabels` map under `spec.selector`
- `AnnotationData` (**define**)
- `LabelData` (**define**)

**Values read**
- Preferred: `.ModuleValues.pdb` (map)
- Fallback: `.Values.pdb` (map)
- Fields:
  - `pdb.disabled` (bool)
  - `pdb.minAvailable` (int|string)
  - `pdb.maxUnavailable` (int|string)
  - `pdb.defaultMaxUnavailable` (int|string; default `10%`)

**Outputs**
- If disabled: renders nothing
- Otherwise: one `policy/v1` PodDisruptionBudget

### ag-template.priorityclass

**Required inputs**
- `Name` (string)
- `Value` (int)

**Optional inputs**
- `GlobalDefault` (bool)
- `Description` (string)
- `PreemptionPolicy` (string)
- `LabelData` (**define**)
- `Labels` (map)
- `Values` (map): only used if you want `ag-template.commonLabels` merged into labels

**Outputs**
- One `scheduling.k8s.io/v1` PriorityClass

### ag-template.hpa (autoscaling/v2)

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `MinReplicas` (int)
- `MaxReplicas` (int)

**Optional inputs**
- `TargetAverageUtilizationCpu` (int)
- `TargetAverageUtilizationMemory` (int)

**Outputs**
- One `autoscaling/v2` HorizontalPodAutoscaler with CPU/memory metrics when provided

### ag-template.pvc

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)
- `Storage` (string; example: `1Gi`)

**Optional inputs**
- `StorageClassName` (string)
- `AccessModes` (list; default `[ReadWriteOnce]`)
- `VolumeMode` (string)
- `Selector` (object)

**Outputs**
- One `v1` PersistentVolumeClaim

### ag-template.networkpolicy

**Required inputs**
- `ApplicationGroup` (string)
- `Name` (string)

**Optional inputs**
- `Namespace` (string): overrides the namespace; otherwise uses the Helm release namespace
- `PodSelector` (map; defaults to the standard app labels)
- `PolicyTypes` (list; values: `Ingress` and/or `Egress`)
- Labels/annotations:
  - `LabelData` (**define**) or `Labels` (map)
  - `AnnotationData` (**define**) or `Annotations` (map)
- Ingress/Egress rules (choose one approach):
  - Raw rule lists: `Ingress` / `Egress` (lists), OR
  - Fragment templates: `IngressTemplate` / `EgressTemplate` (**define**) that render YAML *list items*

**Outputs**
- One `networking.k8s.io/v1` NetworkPolicy

#### Raw rule schemas (recommended)

When you pass `Ingress` / `Egress`, each item must follow the Kubernetes NetworkPolicy API.

**Ingress item** (NetworkPolicyIngressRule):

```yaml
- from:                # optional; omit or [] means "all sources"
  - namespaceSelector: # optional
      matchLabels: {k: v}
    podSelector:       # optional (can be combined with namespaceSelector)
      matchLabels: {k: v}
  - ipBlock:           # optional
      cidr: 10.0.0.0/8
      except: [10.1.0.0/16]
  ports:               # optional; omit or [] means "all ports"
  - protocol: TCP      # optional; defaults to TCP when omitted
    port: 8080         # int or named port (string)
```

**Egress item** (NetworkPolicyEgressRule):

```yaml
- to:                  # optional; omit or [] means "all destinations"
  - namespaceSelector:
      matchLabels: {k: v}
    podSelector:
      matchLabels: {k: v}
  - ipBlock:
      cidr: 0.0.0.0/0
  ports:               # optional; omit or [] means "all ports"
  - protocol: TCP
    port: 443
```

Notes:
- `podSelector` and `namespaceSelector` are Kubernetes LabelSelectors (`matchLabels` / `matchExpressions`).
- `port` may be an integer or a named port string.

#### Fragment templates: `IngressTemplate` / `EgressTemplate`

If you set `IngressTemplate` or `EgressTemplate`, the named template must output YAML list items that belong under `spec.ingress:` / `spec.egress:`.

- The fragment must **not** output the `ingress:`/`egress:` keys.
- The fragment must output one or more items starting with `-`.
- If you need an empty list (`ingress: []` or `egress: []`), do **not** use the fragment approach; instead pass `Ingress: []` / `Egress: []`.

Example ingress fragment:

```tpl
{{- define "myapp.np.ingress" -}}
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Namespace | default $.Release.Namespace }}
  ports:
  - protocol: TCP
    port: 8080
{{- end -}}
```

#### Higher-level inputs supported by this template (optional)

`ag-template.networkpolicy` also accepts convenience/intent-style inputs and will translate them into raw rules:

- Convenience:
  - `IngressPorts` (list of ints; default 80): allows ingress from the caller namespace
  - `EgressHTTPS` (bool): adds an egress rule to `0.0.0.0/0` on TCP/443
- Intent:
  - `AllowIngressFrom` (map): supports `apps`, `namespaces`, `ipBlocks`, and `ports` (default ports)
  - `AllowEgressTo` (map): supports `apps`, `namespaces`, `ipBlocks`, `ports` (default ports), and `internet`
    - `internet.enabled` (bool)
    - `internet.cidrs` (list of CIDR strings)
    - `internet.ports` (list of ints or `{port, protocol}`; default 443)

##### Intent schemas

`AllowIngressFrom` schema:

```yaml
AllowIngressFrom:
  ports:              # optional default ports for peers that do not specify ports
    - 8080
    - { port: 8443, protocol: TCP }
  apps:               # optional
    - name: other-service
      ports: [8080]   # optional (int or {port, protocol})
  namespaces:         # optional
    - name: abc123-dev
      ports: [8080]   # optional
    - matchLabels: { kubernetes.io/metadata.name: abc123-dev }
      podSelector:
        matchLabels: { app.kubernetes.io/name: router }
      ports: [{ port: 443, protocol: TCP }]
  ipBlocks:           # optional
    - cidr: 10.0.0.0/8
      except: [10.1.0.0/16]
      ports: [443]
```

`AllowEgressTo` schema:

```yaml
AllowEgressTo:
  ports:               # optional default ports for app peers that do not specify ports
    - 443
  apps:
    - name: database
      ports: [{ port: 5432, protocol: TCP }]
  namespaces:
    - name: platform
      podSelector:
        matchLabels: { app.kubernetes.io/name: dns }
      ports: [53]
  ipBlocks:
    - cidr: 172.16.0.0/12
      ports: [443]
  internet:
    enabled: true
    cidrs: [0.0.0.0/0]
    ports: [443]
```

##### Legacy / back-compat inputs

The template still accepts some older keys and translates them:

- `IngressFromNamespace` (bool)
- `IngressFromAppNames` (list of strings)
- `IngressFromPodSelectors` (list of label selectors)
- `EgressToApps` (list of `{name, port}`)
- `InternetEgress` (map; same shape as `AllowEgressTo.internet`)


## Notes

- Workloads are labeled with `dataClass` (`low` | `medium` | `high`). Invalid values fail templating.
- If no `dataClass` is provided, the library defaults to `low`.
- Fragment `define` blocks must output valid YAML. Use spaces (not tabs) for indentation.
