{{/*
Reusable StatefulSet template.
Params similar to ag-template.deployment, plus:
  .ServiceName (string) - headless service name for stable network IDs
  .VolumeClaims (template name) - list of PVC templates
  .SecurityContext (template name) - container securityContext fragment
*/}}
{{- define "ag-template.statefulset" -}}
{{- $p := . -}}
{{- $mv := default (dict) $p.ModuleValues -}}
{{- if not ($mv.disabled | default false) }}
{{- $labelData := dict -}}
{{- if $p.LabelData -}}
{{- $tmp := (include $p.LabelData $p | fromYaml) -}}
{{- if and (kindIs "map" $tmp) (not (hasKey $tmp "Error")) -}}
{{- $labelData = $tmp -}}
{{- end -}}
{{- end -}}
{{- $dc := (include "ag-template.getDataClass" $p) -}}
{{- /* Determine OpenShift mode: read global.openshift from chart values */ -}}
{{- $vals := $p.Values -}}
{{- if and (kindIs "map" $p) (hasKey $p "Values") -}}
{{- $vals = (get $p "Values") -}}
{{- end -}}
{{- $isOpenShift := (index (index $vals "global" | default dict) "openshift" | default false) -}}
apiVersion: apps/v1
kind: StatefulSet
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
{{- if gt (len $labelData) 0 }}
{{- toYaml $labelData | nindent 4 }}
{{- end }}
  {{- if $isOpenShift }}
  annotations:
    checkov.io/skip999: CKV_K8S_40=OpenShift SCC assigns runtime UID/GID; do not pin runAsUser/runAsGroup in manifests.
  {{- end }}
spec:
  replicas: {{ default 1 $mv.replicas }}
  serviceName: {{ required "ServiceName is required for StatefulSet" $p.ServiceName }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ $p.Name }}
      app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ $p.Name }}
        app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
        {{- if not (hasKey $labelData "DataClass") }}
        DataClass: {{ title $dc }}
        {{- end }}
{{- if gt (len $labelData) 0 }}
{{- toYaml $labelData | nindent 8 }}
{{- end }}
    spec:
      terminationGracePeriodSeconds: {{ default 30 $mv.terminationGracePeriod }}
      containers:
        - name: {{ $p.Name }}
          {{ $img := get $mv "image" | default (dict) }}
          {{ $tag := get $img "tag" }}
          image: {{ printf "%s/%s:%s" $p.Registry $p.Name (required "ModuleValues.image.tag is required" $tag) }}
          {{ $pullPolicy := get $img "pullPolicy" }}
          imagePullPolicy: {{ default "IfNotPresent" $pullPolicy }}
          {{- if $p.Ports }}
          ports:
{{ include $p.Ports $p | nindent 12 }}
          {{- end }}
          {{- if $p.Env }}
          env:
{{ include $p.Env $p | nindent 12 }}
          {{- end }}
          {{- if $p.Probes }}
{{ include $p.Probes $p | nindent 10 }}
          {{- end }}
          {{- if $p.VolumeMounts }}
          volumeMounts:
{{ include $p.VolumeMounts $p | nindent 12 }}
          {{- end }}
          {{- if $p.Resources }}
          resources:
{{ include $p.Resources $p | nindent 12 }}
          {{- else if $mv.resources }}
          resources:
{{ toYaml $mv.resources | nindent 12 }}
          {{- end }}
          {{- if $p.SecurityContext }}
{{- $defaultSc := (include "ag-template.defaultSecurityContext" . | fromYaml) -}}
{{- $customSc := (include $p.SecurityContext $p | fromYaml) -}}
{{- if and (kindIs "map" $customSc) (hasKey $customSc "Error") -}}
{{- $customSc = dict -}}
{{- end -}}
{{- $enabled := (dig "enabled" true $customSc) -}}
{{- if $enabled }}
          securityContext:
{{ toYaml (merge $defaultSc (omit $customSc "enabled")) | nindent 12 }}
{{- end }}
          {{- else }}
          securityContext:
{{ include "ag-template.defaultSecurityContext" . | nindent 12 }}
          {{- end }}
      {{- if $p.Volumes }}
      volumes:
{{ include $p.Volumes $p | nindent 8 }}
      {{- end }}
  {{- if $p.VolumeClaims }}
  volumeClaimTemplates:
{{ include $p.VolumeClaims $p | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
