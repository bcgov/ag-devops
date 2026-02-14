{{/* PriorityClass template. Expects dict with:
  .Name (string)
  .Value (int)
  .GlobalDefault (bool, optional)
  .Description (string, optional)
  .PreemptionPolicy (string, optional)
  .LabelData (template name, optional)
  .Labels (map, optional)
*/}}
{{- define "ag-template.priorityclass" -}}
{{- $p := . -}}
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: {{ required "Name is required" $p.Name | quote }}
  labels:
{{- with (include "ag-template.commonLabels" $p) }}
{{ . | nindent 4 }}
{{- end }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{ toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- if $p.Labels }}
{{ toYaml $p.Labels | nindent 4 }}
{{- end }}
value: {{ required "Value is required" $p.Value }}
globalDefault: {{ default false $p.GlobalDefault }}
description: {{ default "" $p.Description | quote }}
{{- if $p.PreemptionPolicy }}
preemptionPolicy: {{ $p.PreemptionPolicy | quote }}
{{- end }}
{{- end }}
