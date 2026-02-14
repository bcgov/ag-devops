{{/* HorizontalPodAutoscaler template. Expects dict with:
  .Name (string) - resource basename
  .Namespace (string, optional)
  .MinReplicas (int)
  .MaxReplicas (int)
  .TargetRefName (string) - target Deployment name
  .TargetRefKind (string, default Deployment)
  .Metrics (yaml string or templated content) - metrics block
*/}}
{{/* Public entrypoint: HPA from deployment-like config dict */}}
{{- define "ag-template.hpa" -}}
{{- $c := . -}}
{{- $mv := (default (dict) $c.ModuleValues) -}}
{{- /* Support both legacy ModuleValues.hpa and chart-native autoscaling */ -}}
{{- $h := (default (dict) $mv.hpa) -}}
{{- $as := (default (dict) $mv.autoscaling) -}}
{{- if and (empty $h) (not (empty $as)) -}}
{{- $h = dict
    "minReplicas" (get $as "minReplicas")
    "maxReplicas" (get $as "maxReplicas")
    "targetAverageUtilizationCpu" (get $as "targetCPUUtilizationPercentage")
    "targetAverageUtilizationMemory" (get $as "targetMemoryUtilizationPercentage")
  -}}
{{- end -}}
{{- $name := printf "%s-%s" $c.ApplicationGroup $c.Name -}}

{{- $p := dict
  "Name" $name
  "Namespace" $c.Namespace
  "MinReplicas" (default 1 $h.minReplicas)
  "MaxReplicas" (default 3 $h.maxReplicas)
  "TargetRefKind" "Deployment"
  "TargetRefName" $name
  "LabelData" $c.LabelData
  "ApplicationGroup" $c.ApplicationGroup
  "ModuleValues" $c.ModuleValues
  "Values" $c.Values
  "Chart" $c.Chart
  "Release" $c.Release
  -}}

{{- if or $h.targetAverageUtilizationCpu $h.targetAverageUtilizationMemory -}}
{{- $_ := set $p "CPUUtilization" $h.targetAverageUtilizationCpu -}}
{{- $_ := set $p "MemoryUtilization" $h.targetAverageUtilizationMemory -}}
{{- end -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $p.Name }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- end }}
  {{- if or $p.LabelData (include "ag-template.commonLabels" $p) }}
  labels:
{{- with (include "ag-template.commonLabels" $p) }}
{{ . | nindent 4 }}
{{- end }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
  {{- end }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ default "Deployment" $p.TargetRefKind }}
    name: {{ required "TargetRefName is required" $p.TargetRefName }}
  minReplicas: {{ default 1 $p.MinReplicas }}
  maxReplicas: {{ required "MaxReplicas is required" $p.MaxReplicas }}
  {{- if or $p.CPUUtilization $p.MemoryUtilization }}
  metrics:
    {{- if $p.CPUUtilization }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $p.CPUUtilization }}
    {{- end }}
    {{- if $p.MemoryUtilization }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $p.MemoryUtilization }}
    {{- end }}
  {{- end }}
{{- end -}}
