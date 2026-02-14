{{/*
Reusable PodDisruptionBudget template.

Params (dict):
  .Values
  .ApplicationGroup (string)
  .Name (string)
  .Namespace (string, optional)
  .ModuleValues (dict, optional)
    pdb (dict, optional)
      disabled (bool)
      minAvailable (int|string)
      maxUnavailable (int|string)
  .Selector (template name, optional) -> matchLabels block
  .AnnotationData, .LabelData (template names, optional)

Default behavior:
  - Creates a PDB with maxUnavailable: 10% (unless minAvailable/maxUnavailable provided)
  - Fails if both minAvailable and maxUnavailable are set
*/}}

{{/* Adapter: accept the same dict style used by other resources */}}
{{- define "ag-template.pdb" -}}
{{- $p := . -}}
{{- $vals := default (dict) $p.Values -}}
{{- $mv := default (dict) $p.ModuleValues -}}
{{- $pdb := default (dict) (get $mv "pdb") -}}
{{- if and (empty $pdb) (hasKey $vals "pdb") -}}
{{- $pdb = (get $vals "pdb") -}}
{{- end -}}
{{- if not (default false (get $pdb "disabled")) -}}
{{- if and (hasKey $pdb "minAvailable") (hasKey $pdb "maxUnavailable") -}}
{{- fail "pdb: set only one of minAvailable or maxUnavailable" -}}
{{- end -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
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
{{ include "ag-template.commonLabels" $p | nindent 4 }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- $hasAnn := false }}
{{- if $p.AnnotationData }}{{ $hasAnn = true }}{{- end }}
{{- if $hasAnn }}
  annotations:
{{- with (include $p.AnnotationData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
spec:
  {{- if hasKey $pdb "minAvailable" }}
  minAvailable: {{ get $pdb "minAvailable" }}
  {{- else if hasKey $pdb "maxUnavailable" }}
  maxUnavailable: {{ get $pdb "maxUnavailable" }}
  {{- else }}
  maxUnavailable: {{ default "10%" (get $pdb "defaultMaxUnavailable") }}
  {{- end }}
  selector:
    matchLabels:
{{- if $p.Selector }}
{{ include $p.Selector $p | nindent 6 }}
{{- else }}
      app.kubernetes.io/name: {{ $p.Name }}
      app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{- end }}
{{- end -}}
{{- end -}}
