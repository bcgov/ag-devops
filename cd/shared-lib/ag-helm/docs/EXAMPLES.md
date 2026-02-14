# ag-helm library chart: Examples

This document provides copy/paste-ready examples for using the `ag-helm` Helm library chart.

All examples follow the same pattern:

1. Build a parameter dictionary (`$p`)
2. Set required identity keys
3. Optionally set fragment hooks (names of `define` blocks)
4. Call the library entrypoint with `include "ag-template.*"`

For the authoritative input/output contract for each entrypoint, see `SIMPLE-API.md`.

---

## Example 1: Deployment + Service + intent-based NetworkPolicy (typical service)
In OpenShift, prefer Routes (see the next example) unless your platform explicitly standardizes on Kubernetes Ingress.

This is the recommended starting point for a standard HTTP service inside a namespace.

Minimal values shape:

```yaml

---

## Example 5b: OpenShift Route + NetworkPolicy allowing router ingress

If you expose a service via an OpenShift Route, you typically need NetworkPolicy rules that allow ingress from the OpenShift router pods.

Important: router labels can vary by cluster configuration (and by ingress controller name). Confirm the labels on your cluster (for example with `oc -n openshift-ingress get pods --show-labels`).

This example allows ingress from the `openshift-ingress` namespace, restricted to the default ingresscontroller deployment label (common default on OpenShift):

```tpl
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}

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
project: myapp
registry: ghcr.io/my-org

webApi:
  image:
    # Prefer digest pinning when available.
    # digest: sha256:...
    tag: "1.2.3"
    pullPolicy: IfNotPresent
  replicas: 2
  dataClass: medium
```

```tpl
{{- $app := dict "Values" .Values -}}
{{- $_ := set $app "ApplicationGroup" .Values.project -}}
{{- $_ := set $app "Name" "web-api" -}}
{{- $_ := set $app "Namespace" $.Release.Namespace -}}
{{- $_ := set $app "Registry" .Values.registry -}}
{{- $_ := set $app "ModuleValues" .Values.webApi -}}

{{- /* Hook fragments */ -}}
{{- $_ := set $app "Ports" "webapi.ports" -}}
{{- $_ := set $app "Env" "webapi.env" -}}
{{- $_ := set $app "Probes" "webapi.probes" -}}

{{ include "ag-template.deployment" $app }}
---
{{- $svc := dict "Values" .Values -}}
{{- $_ := set $svc "ApplicationGroup" .Values.project -}}
{{- $_ := set $svc "Name" "web-api" -}}
{{- $_ := set $svc "Namespace" $.Release.Namespace -}}
{{- $_ := set $svc "ServicePorts" "webapi.servicePorts" -}}
{{ include "ag-template.service" $svc }}
---
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}

{{- /* Ingress from frontend within same namespace */ -}}
{{- $_ := set $np "AllowIngressFrom" (dict
  "ports" (list 8080)
  "apps" (list (dict "name" "frontend"))
) -}}

{{- /* Egress to postgres + HTTPS to a specific CIDR */ -}}
{{- $_ := set $np "AllowEgressTo" (dict
  "apps" (list (dict "name" "postgresql" "ports" (list (dict "port" 5432 "protocol" "TCP"))))
  "ipBlocks" (list (dict "cidr" "142.34.208.0/24" "ports" (list 443)))
) -}}

{{ include "ag-template.networkpolicy" $np }}

{{- define "webapi.ports" -}}
- name: http
  containerPort: 8080
  protocol: TCP
{{- end -}}

{{- define "webapi.env" -}}
- name: ASPNETCORE_URLS
  value: http://+:8080
{{- end -}}

{{- define "webapi.probes" -}}
livenessProbe:
  httpGet:
    path: /health/live
    port: http
readinessProbe:
  httpGet:
    path: /health/ready
    port: http
{{- end -}}

{{- define "webapi.servicePorts" -}}
- name: http
  port: 8080
  targetPort: http
  protocol: TCP
{{- end -}}
```

---

## Example 2: NetworkPolicy using raw rules (no intent inputs)

Use this when you already know exactly what you want under `spec.ingress`/`spec.egress`.

Minimal values shape:

```yaml
project: myapp
```

```tpl
{{- $np := dict "Values" .Values -}}
{{- $_ := set $np "ApplicationGroup" .Values.project -}}
{{- $_ := set $np "Name" "worker" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Egress") -}}

{{- $_ := set $np "Egress" (list
  (dict
    "to" (list (dict "ipBlock" (dict "cidr" "0.0.0.0/0")))
    "ports" (list (dict "protocol" "TCP" "port" 443))
  )
) -}}

{{ include "ag-template.networkpolicy" $np }}
```

---

## Example 3: NetworkPolicy using fragments (`IngressTemplate` / `EgressTemplate`)

Use this when it’s easier to generate rules as YAML rather than building Helm dictionaries.

Important: the fragment must emit list items (lines starting with `-`) and must *not* emit `ingress:`/`egress:` keys.

Minimal values shape:

```yaml
project: myapp
```

```tpl
{{- $np := dict "ApplicationGroup" .Values.project "Name" "web-api" -}}
{{- $_ := set $np "Namespace" $.Release.Namespace -}}
{{- $_ := set $np "PolicyTypes" (list "Ingress") -}}
{{- $_ := set $np "IngressTemplate" "webapi.np.ingress" -}}
{{ include "ag-template.networkpolicy" $np }}

{{- define "webapi.np.ingress" -}}
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Namespace | quote }}
  ports:
  - protocol: TCP
    port: 8080
{{- end -}}
```

---

## Example 4: Kubernetes Ingress (`ag-template.ingress`)

This template selects the Ingress apiVersion based on `.Capabilities`.

Minimal values shape:

```yaml
project: myapp
```

```tpl
{{- $ing := dict "Values" .Values -}}
{{- $_ := set $ing "Name" "web-api" -}}
{{- $_ := set $ing "Namespace" $.Release.Namespace -}}
{{- $_ := set $ing "Capabilities" .Capabilities -}}
{{- $_ := set $ing "ClassName" "nginx" -}}
{{- $_ := set $ing "Annotations" (dict
  "aviinfrasetting.ako.vmware.com/name" "dataclass-medium"
) -}}
{{- $_ := set $ing "ServiceName" (printf "%s-%s" .Values.project "web-api") -}}
{{- $_ := set $ing "ServicePort" 8080 -}}
{{- $_ := set $ing "Hosts" (list (dict
  "host" "web-api.example.com"
  "paths" (list (dict "path" "/" "pathType" "Prefix"))
)) -}}

{{ include "ag-template.ingress" $ing }}
```

---

## Example 5: OpenShift Route (`ag-template.route.openshift`)

This template is values-driven: it only renders when `route.enabled: true`.
It reads route configuration from `.ModuleValues.route` first, then falls back to `.Values.route`.

Minimal values shape:

```yaml
project: myapp

webApi:
  route:
    enabled: true
    host: web-api.apps.example.com
    targetPort: http
    annotations:
      aviinfrasetting.ako.vmware.com/name: dataclass-medium
```

```tpl
{{- $r := dict "Values" .Values -}}
{{- $_ := set $r "ApplicationGroup" .Values.project -}}
{{- $_ := set $r "Name" "web-api" -}}
{{- $_ := set $r "Namespace" $.Release.Namespace -}}
{{- $_ := set $r "ModuleValues" .Values.webApi -}}
{{ include "ag-template.route.openshift" $r }}
```

The Route template reads the `route` block above and emits a single OpenShift Route when enabled.

---

## Example 6: StatefulSet + Headless Service

Stateful workloads typically use a headless Service and a StatefulSet.

Minimal values shape:

```yaml
project: myapp
registry: ghcr.io/my-org

redis:
  image:
    tag: "7.2"
  replicas: 3
  dataClass: medium
```

```tpl
{{- $svc := dict "Values" .Values -}}
{{- $_ := set $svc "ApplicationGroup" .Values.project -}}
{{- $_ := set $svc "Name" "redis" -}}
{{- $_ := set $svc "Namespace" $.Release.Namespace -}}
{{- $_ := set $svc "Headless" true -}}
{{- $_ := set $svc "ServicePorts" "redis.servicePorts" -}}
{{ include "ag-template.service" $svc }}
---
{{- $ss := dict "Values" .Values -}}
{{- $_ := set $ss "ApplicationGroup" .Values.project -}}
{{- $_ := set $ss "Name" "redis" -}}
{{- $_ := set $ss "Namespace" $.Release.Namespace -}}
{{- $_ := set $ss "Registry" .Values.registry -}}
{{- $_ := set $ss "ServiceName" (printf "%s-%s" .Values.project "redis") -}}
{{- $_ := set $ss "ModuleValues" .Values.redis -}}
{{- $_ := set $ss "Ports" "redis.ports" -}}
{{ include "ag-template.statefulset" $ss }}

{{- define "redis.servicePorts" -}}
- name: redis
  port: 6379
  targetPort: redis
  protocol: TCP
{{- end -}}

{{- define "redis.ports" -}}
- name: redis
  containerPort: 6379
  protocol: TCP
{{- end -}}
```

---

## Example 7: Job

Minimal values shape:

```yaml
project: myapp
registry: ghcr.io/my-org

dbMigrate:
  image:
    tag: "1.2.3"
  # Optional: keep jobs low impact by default.
  resources: {}
  dataClass: low
```

```tpl
{{- $job := dict "Values" .Values -}}
{{- $_ := set $job "ApplicationGroup" .Values.project -}}
{{- $_ := set $job "Name" "db-migrate" -}}
{{- $_ := set $job "Namespace" $.Release.Namespace -}}
{{- $_ := set $job "Registry" .Values.registry -}}
{{- $_ := set $job "ModuleValues" .Values.dbMigrate -}}
{{- $_ := set $job "Command" (list "/bin/sh" "-c") -}}
{{- $_ := set $job "Args" (list "./migrate") -}}
{{- $_ := set $job "Env" "dbmigrate.env" -}}
{{ include "ag-template.job" $job }}

{{- define "dbmigrate.env" -}}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: my-db
      key: url
{{- end -}}
```

---

## Troubleshooting

- If a rendered manifest is invalid YAML, check your fragment output shape (list vs map vs inline object).
- If a template fails with `required ... is required`, confirm the dict key name matches the documented contract.
- If NetworkPolicy behavior is unexpected, check `policyTypes`. Including `Egress` without any egress rules results in default-deny egress.
