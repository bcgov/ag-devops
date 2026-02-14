{{/* Reusable NetworkPolicy template
Accepts either structured lists (.Ingress/.Egress) or fragment template names
(.IngressTemplate/.EgressTemplate) that render list items.
*/}}

{{/*
ag-template.networkpolicy: single public entrypoint.

Supports:
- intent-style inputs (AllowIngressFrom / AllowEgressTo, etc.)
- simple convenience inputs (IngressPorts, EgressHTTPS)
- raw inputs (Ingress/Egress or IngressTemplate/EgressTemplate)
*/}}
{{- define "ag-template.networkpolicy" -}}
{{- $in := . -}}
{{- $p := $in -}}
{{- if or
  (hasKey $in "AllowIngressFrom")
  (hasKey $in "AllowEgressTo")
  (hasKey $in "IngressFromNamespace")
  (hasKey $in "IngressFromAppNames")
  (hasKey $in "IngressFromPodSelectors")
  (hasKey $in "EgressToApps")
  (hasKey $in "InternetEgress")
}}
{{/* App/intent API */}}
{{- $p = dict -}}

{{- $_ := set $p "ApplicationGroup" (default "app" $in.ApplicationGroup) -}}
{{- $_ := set $p "Name" (required "Name is required" $in.Name) -}}
{{- if $in.Namespace }}
{{- $_ := set $p "Namespace" $in.Namespace -}}
{{- else if $.Release }}
{{- $_ := set $p "Namespace" $.Release.Namespace -}}
{{- end }}

{{- if $in.LabelData }}{{- $_ := set $p "LabelData" $in.LabelData -}}{{- end }}
{{- if $in.Labels }}{{- $_ := set $p "Labels" $in.Labels -}}{{- end }}
{{- if $in.AnnotationData }}{{- $_ := set $p "AnnotationData" $in.AnnotationData -}}{{- end }}
{{- if $in.Annotations }}{{- $_ := set $p "Annotations" $in.Annotations -}}{{- end }}
{{- if $in.PodSelector }}{{- $_ := set $p "PodSelector" $in.PodSelector -}}{{- end }}
{{- if hasKey $in "Values" }}{{- $_ := set $p "Values" $in.Values -}}{{- end }}
{{- if hasKey $in "ModuleValues" }}{{- $_ := set $p "ModuleValues" $in.ModuleValues -}}{{- end }}

{{- $policyTypes := (default (list "Ingress" "Egress") $in.PolicyTypes) -}}
{{- $_ := set $p "PolicyTypes" $policyTypes -}}

{{/* Ingress */}}
{{- $ingress := list -}}

{{- $allowIngress := (default (dict) $in.AllowIngressFrom) -}}
{{- $defaultIngressPortsIn := (default (default (list 80) $in.IngressPorts) (dig "ports" (list) $allowIngress)) -}}
{{- $defaultIngressPorts := list -}}
{{- range $defaultIngressPortsIn -}}
  {{- if kindIs "map" . -}}
    {{- $defaultIngressPorts = append $defaultIngressPorts (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
  {{- else -}}
    {{- $defaultIngressPorts = append $defaultIngressPorts (dict "protocol" "TCP" "port" .) -}}
  {{- end -}}
{{- end -}}

{{- $ingressPeers := list -}}

{{/* Back-compat: IngressFromNamespace bool */}}
{{- if (default false $in.IngressFromNamespace) -}}
  {{- $nsName := (default (default "default" $in.Namespace) (and $.Release $.Release.Namespace)) -}}
  {{- $ingressPeers = append $ingressPeers (dict "namespaceSelector" (dict "matchLabels" (dict "kubernetes.io/metadata.name" $nsName))) -}}
{{- end -}}

{{/* Back-compat: IngressFromAppNames */}}
{{- range (default (list) $in.IngressFromAppNames) -}}
  {{- $ingressPeers = append $ingressPeers (dict "podSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" .))) -}}
{{- end -}}

{{/* Back-compat: IngressFromPodSelectors */}}
{{- range (default (list) $in.IngressFromPodSelectors) -}}
  {{- $ingressPeers = append $ingressPeers (dict "podSelector" .) -}}
{{- end -}}

{{/* Preferred: AllowIngressFrom.apps */}}
{{- range (default (list) (dig "apps" (list) $allowIngress)) -}}
  {{- $name := .name -}}
  {{- $portsIn := (default (list) .ports) -}}
  {{- if gt (len $portsIn) 0 -}}
    {{- $ports := list -}}
    {{- range $portsIn -}}
      {{- if kindIs "map" . -}}
        {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
      {{- else -}}
        {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
      {{- end -}}
    {{- end -}}
    {{- $peer := dict "podSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" $name)) -}}
    {{- $ingress = append $ingress (dict "from" (list $peer) "ports" $ports) -}}
  {{- else -}}
    {{- $ingressPeers = append $ingressPeers (dict "podSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" $name))) -}}
  {{- end -}}
{{- end -}}

{{/* Preferred: AllowIngressFrom.namespaces */}}
{{- range (default (list) (dig "namespaces" (list) $allowIngress)) -}}
  {{- $nsSel := dict -}}
  {{- if .matchLabels -}}
    {{- $_ := set $nsSel "matchLabels" .matchLabels -}}
  {{- else if .name -}}
    {{- $_ := set $nsSel "matchLabels" (dict "kubernetes.io/metadata.name" .name) -}}
  {{- end -}}
  {{- $peer := dict -}}
  {{- if gt (len $nsSel) 0 -}}
    {{- $_ := set $peer "namespaceSelector" $nsSel -}}
  {{- end -}}
  {{- if .podSelector -}}
    {{- $_ := set $peer "podSelector" .podSelector -}}
  {{- end -}}

  {{- if gt (len $peer) 0 -}}
    {{- $portsIn := (default (list) .ports) -}}
    {{- $ports := list -}}
    {{- if gt (len $portsIn) 0 -}}
      {{- range $portsIn -}}
        {{- if kindIs "map" . -}}
          {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
        {{- else -}}
          {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
        {{- end -}}
      {{- end -}}
      {{- $ingress = append $ingress (dict "from" (list $peer) "ports" $ports) -}}
    {{- else -}}
      {{- $ingressPeers = append $ingressPeers $peer -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Preferred: AllowIngressFrom.ipBlocks */}}
{{- range (default (list) (dig "ipBlocks" (list) $allowIngress)) -}}
  {{- $ipb := dict "cidr" .cidr -}}
  {{- if .except }}{{- $_ := set $ipb "except" .except -}}{{- end -}}
  {{- $peer := dict "ipBlock" $ipb -}}
  {{- $portsIn := (default (list) .ports) -}}
  {{- $ports := list -}}
  {{- if gt (len $portsIn) 0 -}}
    {{- range $portsIn -}}
      {{- if kindIs "map" . -}}
        {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
      {{- else -}}
        {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
      {{- end -}}
    {{- end -}}
  {{- else -}}
    {{- $ports = $defaultIngressPorts -}}
  {{- end -}}
  {{- $ingress = append $ingress (dict "from" (list $peer) "ports" $ports) -}}
{{- end -}}

{{- if gt (len $ingressPeers) 0 -}}
  {{- $ingress = append $ingress (dict "from" $ingressPeers "ports" $defaultIngressPorts) -}}
{{- end -}}

{{- if gt (len $ingress) 0 -}}
  {{- $_ := set $p "Ingress" $ingress -}}
{{- end -}}

{{/* Egress */}}
{{- $egress := list -}}

{{- $allowEgress := (default (dict) $in.AllowEgressTo) -}}

{{/* Back-compat: EgressToApps */}}
{{- range (default (list) $in.EgressToApps) -}}
  {{- $egress = append $egress (dict
    "to" (list (dict "podSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" .name))))
    "ports" (list (dict "protocol" "TCP" "port" .port))
  ) -}}
{{- end -}}

{{/* Preferred: AllowEgressTo.apps */}}
{{- range (default (list) (dig "apps" (list) $allowEgress)) -}}
  {{- $name := .name -}}
  {{- $portsIn := (default (list) .ports) -}}
  {{- if eq (len $portsIn) 0 -}}
    {{- $portsIn = (default (list 443) (dig "ports" (list) $allowEgress)) -}}
  {{- end -}}
  {{- $ports := list -}}
  {{- range $portsIn -}}
    {{- if kindIs "map" . -}}
      {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
    {{- else -}}
      {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
    {{- end -}}
  {{- end -}}
  {{- $egress = append $egress (dict
    "to" (list (dict "podSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" $name))))
    "ports" $ports
  ) -}}
{{- end -}}

{{/* Preferred: AllowEgressTo.namespaces */}}
{{- range (default (list) (dig "namespaces" (list) $allowEgress)) -}}
  {{- $nsSel := dict -}}
  {{- if .matchLabels -}}
    {{- $_ := set $nsSel "matchLabels" .matchLabels -}}
  {{- else if .name -}}
    {{- $_ := set $nsSel "matchLabels" (dict "kubernetes.io/metadata.name" .name) -}}
  {{- end -}}
  {{- $peer := dict -}}
  {{- if gt (len $nsSel) 0 -}}
    {{- $_ := set $peer "namespaceSelector" $nsSel -}}
  {{- end -}}
  {{- if .podSelector -}}
    {{- $_ := set $peer "podSelector" .podSelector -}}
  {{- end -}}
  {{- if gt (len $peer) 0 -}}
    {{- $portsIn := (default (list) .ports) -}}
    {{- $ports := list -}}
    {{- range $portsIn -}}
      {{- if kindIs "map" . -}}
        {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
      {{- else -}}
        {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
      {{- end -}}
    {{- end -}}
    {{- if gt (len $ports) 0 -}}
      {{- $egress = append $egress (dict "to" (list $peer) "ports" $ports) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/* Preferred: AllowEgressTo.ipBlocks */}}
{{- range (default (list) (dig "ipBlocks" (list) $allowEgress)) -}}
  {{- $ipb := dict "cidr" .cidr -}}
  {{- if .except }}{{- $_ := set $ipb "except" .except -}}{{- end -}}
  {{- $peer := dict "ipBlock" $ipb -}}
  {{- $portsIn := (default (list) .ports) -}}
  {{- $ports := list -}}
  {{- range $portsIn -}}
    {{- if kindIs "map" . -}}
      {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
    {{- else -}}
      {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
    {{- end -}}
  {{- end -}}
  {{- if gt (len $ports) 0 -}}
    {{- $egress = append $egress (dict "to" (list $peer) "ports" $ports) -}}
  {{- end -}}
{{- end -}}

{{/* Internet egress: explicit intent or moduleValues fallback */}}
{{- $internetFromIntent := (default (dict) (dig "internet" (dict) $allowEgress)) -}}
{{- $internetFromDirect := (default (dict) $in.InternetEgress) -}}
{{- $internetFromModule := dict -}}
{{- if hasKey $in "ModuleValues" -}}
  {{- $internetFromModule = (dig "networkPolicy" "internetEgress" (dict) $in.ModuleValues) -}}
{{- end -}}
{{- $internet := (default $internetFromModule $internetFromDirect) -}}
{{- if gt (len $internetFromIntent) 0 -}}
  {{- $internet = $internetFromIntent -}}
{{- end -}}

{{- if (dig "enabled" false $internet) -}}
  {{- $cidrs := (dig "cidrs" (list) $internet) -}}
  {{- if gt (len $cidrs) 0 -}}
    {{- $to := list -}}
    {{- range $cidrs -}}
      {{- $to = append $to (dict "ipBlock" (dict "cidr" .)) -}}
    {{- end -}}
    {{- $ports := list -}}
    {{- range (dig "ports" (list 443) $internet) -}}
      {{- if kindIs "map" . -}}
        {{- $ports = append $ports (dict "protocol" (default "TCP" .protocol) "port" .port) -}}
      {{- else -}}
        {{- $ports = append $ports (dict "protocol" "TCP" "port" .) -}}
      {{- end -}}
    {{- end -}}
    {{- $egress = append $egress (dict "to" $to "ports" $ports) -}}
  {{- end -}}
{{- end -}}

{{- if gt (len $egress) 0 -}}
  {{- $_ := set $p "Egress" $egress -}}
{{- end -}}

{{- else if or (hasKey $in "IngressPorts") (hasKey $in "EgressHTTPS") -}}
{{/* Simple API */}}
{{- $p = dict -}}
{{- $ns := (default "default" $in.Namespace) -}}
{{- $_ := set $p "ApplicationGroup" (default "app" $in.ApplicationGroup) -}}
{{- $_ := set $p "Name" (required "Name is required" $in.Name) -}}
{{- $pt := (default (list "Ingress") $in.PolicyTypes) -}}
{{- $fromNs := dict "namespaceSelector" (dict "matchLabels" (dict "kubernetes.io/metadata.name" $ns)) -}}
{{- $ingPorts := list -}}
{{- range (default (list 80) $in.IngressPorts) -}}
{{- $ingPorts = append $ingPorts (dict "protocol" "TCP" "port" .) -}}
{{- end -}}
{{- $_ := set $p "Ingress" (list (dict "from" (list $fromNs) "ports" $ingPorts)) -}}
{{- $eg := list -}}
{{- if (default false $in.EgressHTTPS) -}}
{{- $eg = append $eg (dict "to" (list (dict "ipBlock" (dict "cidr" "0.0.0.0/0"))) "ports" (list (dict "protocol" "TCP" "port" 443))) -}}
{{- end -}}
{{- if gt (len $eg) 0 -}}
{{- $_ := set $p "Egress" $eg -}}
{{- $hasEgress := false -}}
{{- range $pt }}
  {{- if eq . "Egress" }}
    {{- $hasEgress = true -}}
  {{- end -}}
{{- end -}}
{{- if not $hasEgress -}}
  {{- $pt = append $pt "Egress" -}}
{{- end -}}
{{- end -}}
{{- $_ := set $p "PolicyTypes" $pt -}}
{{- end -}}

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ printf "%s-%s" $p.ApplicationGroup $p.Name | trunc 63 | trimSuffix "-" }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- else if $.Release }}
  namespace: {{ $.Release.Namespace }}
  {{- end }}
  labels:
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{- with $p | include "ag-template.commonLabels" }}
{{ . | nindent 4 }}
{{- end }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
  {{- $hasAnn := false }}
  {{- if $p.AnnotationData }}{{ $hasAnn = true }}{{- end }}
  {{- if $p.Annotations }}{{ $hasAnn = true }}{{- end }}
  {{- if $hasAnn }}
  annotations:
  {{- if $p.AnnotationData }}
{{ include $p.AnnotationData $p | nindent 4 }}
  {{- end }}
  {{- if $p.Annotations }}
{{ toYaml $p.Annotations | nindent 4 }}
  {{- end }}
  {{- end }}
spec:
  podSelector:
{{- if $p.PodSelector }}
{{ toYaml $p.PodSelector | nindent 4 }}
{{- else }}
    matchLabels:
      app.kubernetes.io/name: {{ $p.Name }}
      app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{- end }}
  policyTypes:
{{- range (default (list "Ingress") $p.PolicyTypes) }}
  - {{ . }}
{{- end }}
{{- if $p.IngressTemplate }}
  ingress:
{{ include $p.IngressTemplate $p | nindent 2 }}
{{- else if hasKey $p "Ingress" }}
{{- $ing := $p.Ingress -}}
{{- if eq (len $ing) 0 }}
  ingress: []
{{- else }}
  ingress:
{{ toYaml $ing | nindent 2 }}
{{- end }}
{{- end }}
{{- if $p.EgressTemplate }}
  egress:
{{ include $p.EgressTemplate $p | nindent 2 }}
{{- else if hasKey $p "Egress" }}
{{- $eg := $p.Egress -}}
{{- if eq (len $eg) 0 }}
  egress: []
{{- else }}
  egress:
{{ toYaml $eg | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}

