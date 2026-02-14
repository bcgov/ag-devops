{{/* ServiceAccount template. Expects dict with:
  .Name (string) - application name (when ApplicationGroup is set) OR full resource name (legacy)
  .ApplicationGroup (string, optional) - when set, metadata.name becomes <ApplicationGroup>-<Name>
  .Namespace (string, optional)
  .Annotations (map, optional)
  .Labels (map, optional)
  .ImagePullSecrets (list[string], optional)
*/}}
{{- define "ag-template.serviceaccount" -}}
{{- $c := . -}}
{{- $mv := default (dict) $c.ModuleValues -}}
{{- $v := default (dict) $c.Values -}}
{{- /* Prefer module-level serviceAccount (chart-native), fallback to root */ -}}
{{- $sa := default (dict) $mv.serviceAccount -}}
{{- if and (empty $sa) (hasKey $v "serviceAccount") -}}
{{- $sa = default (dict) $v.serviceAccount -}}
{{- end -}}
{{- if $sa.create }}
{{- $p := dict "Name" $c.Name "ApplicationGroup" $c.ApplicationGroup "Namespace" $c.Namespace "Values" $c.Values -}}
{{- if $c.ModuleValues }}{{- $_ := set $p "ModuleValues" $c.ModuleValues -}}{{- end }}
{{- $_ := set $p "LabelData" $c.LabelData -}}
{{- $_ := set $p "AnnotationData" $c.AnnotationData -}}
{{- $_ := set $p "Labels" (default (dict) $c.Labels) -}}
{{- $_ := set $p "Annotations" (default (dict) $sa.annotations) -}}
{{- if $c.ImagePullSecrets }}{{- $_ := set $p "ImagePullSecrets" $c.ImagePullSecrets -}}{{- end }}
{{- if hasKey $sa "automount" }}
{{- $_ := set $p "AutomountServiceAccountToken" $sa.automount -}}
{{- else if hasKey $mv "automountServiceAccountToken" }}
{{- $_ := set $p "AutomountServiceAccountToken" $mv.automountServiceAccountToken -}}
{{- end }}

{{- $resName := $p.Name -}}
{{- if $p.ApplicationGroup -}}
{{- $resName = (printf "%s-%s" $p.ApplicationGroup $p.Name | trunc 63 | trimSuffix "-") -}}
{{- end -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $resName }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- else if $.Release }}
  namespace: {{ $.Release.Namespace }}
  {{- end }}
  labels:
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/instance: {{ $resName }}
    {{- if $p.ApplicationGroup }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
    {{- end }}
    {{ include "ag-template.commonLabels" $p | nindent 4 }}
{{- if $p.LabelData }}
{{- with (include $p.LabelData $p | fromYaml) }}
{{ toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- if $p.Labels }}
{{ toYaml $p.Labels | nindent 4 }}
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
{{- if $p.ImagePullSecrets }}
imagePullSecrets:
{{- range $p.ImagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- if hasKey $p "AutomountServiceAccountToken" }}
automountServiceAccountToken: {{ $p.AutomountServiceAccountToken }}
{{- else }}
automountServiceAccountToken: false
{{- end }}
{{- end }}
{{- end }}
