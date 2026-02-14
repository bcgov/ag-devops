{{/*
Reusable Service template.
Params (dict):
  .ApplicationGroup, .Name
  .Type (default ClusterIP)
  .Ports or .ServicePorts (template name) -> list of ServicePorts
  .Selector (template name) optional; defaults to standard labels
  .AnnotationData, .LabelData (template names)
  .ClusterIP (string) optional
  .Headless (bool) optional -> sets clusterIP: None, publishNotReadyAddresses
  .SessionAffinity (string) optional
  .ExternalTrafficPolicy (string) optional
  .LoadBalancerIP (string) optional
  .LoadBalancerClass (string) optional
  .IPFamilyPolicy (string) optional
  .IPFamilies (template name) optional -> list of string
*/}}
{{- define "ag-template.service" -}}
{{- $p := . -}}
{{- $portsTmpl := (default $p.Ports $p.ServicePorts) -}}
apiVersion: v1
kind: Service
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
  type: {{ default "ClusterIP" $p.Type }}
  {{- if $p.Headless }}
  clusterIP: None
  publishNotReadyAddresses: true
  {{- else if $p.ClusterIP }}
  clusterIP: {{ $p.ClusterIP }}
  {{- end }}
  {{- if $p.SessionAffinity }}
  sessionAffinity: {{ $p.SessionAffinity }}
  {{- end }}
  {{- if $p.ExternalTrafficPolicy }}
  externalTrafficPolicy: {{ $p.ExternalTrafficPolicy }}
  {{- end }}
  {{- if $p.LoadBalancerIP }}
  loadBalancerIP: {{ $p.LoadBalancerIP }}
  {{- end }}
  {{- if $p.LoadBalancerClass }}
  loadBalancerClass: {{ $p.LoadBalancerClass }}
  {{- end }}
  {{- if $p.IPFamilyPolicy }}
  ipFamilyPolicy: {{ $p.IPFamilyPolicy }}
  {{- end }}
  {{- if $p.IPFamilies }}
  ipFamilies:
{{ include $p.IPFamilies $p | nindent 4 }}
  {{- end }}
  selector:
{{- if $p.Selector }}
{{ include $p.Selector $p | nindent 4 }}
{{- else }}
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{- end }}
  ports:
{{- if $portsTmpl }}
{{ include $portsTmpl $p | nindent 4 }}
{{- end }}
{{- end }}
