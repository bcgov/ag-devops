{{- define "ag-template.job" -}}
{{- $p := . -}}
{{- $mv := default (dict) $p.ModuleValues -}}
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
apiVersion: batch/v1
kind: Job
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
{{ toYaml $labelData | nindent 4 }}
{{- end }}
{{- $hasTopAnn := false }}
{{- if $p.AnnotationData }}{{ $hasTopAnn = true }}{{- end }}
{{- if $p.Annotations }}{{ $hasTopAnn = true }}{{- end }}
{{- if $isOpenShift }}{{ $hasTopAnn = true }}{{- end }}
{{- if $hasTopAnn }}
  annotations:
  {{- if $p.AnnotationData }}
{{ include $p.AnnotationData $p | nindent 4 }}
  {{- end }}
  {{- if $p.Annotations }}
{{ toYaml $p.Annotations | nindent 4 }}
  {{- end }}
  {{- if $isOpenShift }}
    checkov.io/skip999: CKV_K8S_40=OpenShift SCC assigns runtime UID/GID; do not pin runAsUser/runAsGroup in manifests.
  {{- end }}
{{- end }}
spec:
  backoffLimit: {{ default 6 $p.BackoffLimit }}
  ttlSecondsAfterFinished: {{ default 86400 $p.TTLSecondsAfterFinished }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ $p.Name }}
        app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
        {{- if not (hasKey $labelData "DataClass") }}
        DataClass: {{ title $dc }}
        {{- end }}
{{- if gt (len $labelData) 0 }}
{{ toYaml $labelData | nindent 8 }}
{{- end }}
{{- $hasPodAnn := false }}
{{- if $p.PodAnnotationData }}{{ $hasPodAnn = true }}{{- end }}
{{- if $hasPodAnn }}
      annotations:
{{ include $p.PodAnnotationData $p | nindent 8 }}
{{- end }}
    spec:
      {{- if $p.ServiceAccountName }}
      serviceAccountName: {{ $p.ServiceAccountName }}
      {{- end }}
      {{- if $p.PullSecret }}
      imagePullSecrets:
{{ include $p.PullSecret $p | nindent 8 }}
      {{- end }}
      restartPolicy: {{ default "Never" $p.RestartPolicy }}
      terminationGracePeriodSeconds: {{ default 30 $mv.terminationGracePeriod }}
      {{- if $p.Tolerations }}
      tolerations:
{{ include $p.Tolerations $p | nindent 8 }}
      {{- end }}
      {{- if $p.InitContainers }}
      initContainers:
{{ include $p.InitContainers $p | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ $p.Name }}
          image: {{ printf "%s/%s:%s" $p.Registry $p.Name ((get $p.ModuleValues "image").tag | default "latest") }}
          imagePullPolicy: {{ default "IfNotPresent" ((get $p.ModuleValues "image").pullPolicy) }}
{{- if $p.Command }}
          command:
{{ toYaml $p.Command | nindent 12 }}
{{- end }}
{{- if $p.Args }}
          args:
{{ toYaml $p.Args | nindent 12 }}
{{- end }}
{{- if $p.Env }}
          env:
{{ include $p.Env $p | nindent 12 }}
{{- end }}
{{- if $p.Resources }}
          resources:
{{ include $p.Resources $p | nindent 12 }}
{{- else if $mv.resources }}
          resources:
{{ toYaml $mv.resources | nindent 12 }}
{{- end }}
{{- if $p.SecurityContext }}
{{- $customSc := (include $p.SecurityContext $p | fromYaml) -}}
{{- if and (kindIs "map" $customSc) (hasKey $customSc "Error") -}}
{{- $customSc = dict -}}
{{- end -}}
{{- $enabled := (dig "enabled" true $customSc) -}}
{{- if $enabled }}
          securityContext:
{{ toYaml (omit $customSc "enabled") | nindent 12 }}
{{- end }}
{{- else }}
          securityContext:
{{ include "ag-template.defaultSecurityContext" $p | nindent 12 }}
{{- end }}
{{- if $p.VolumeMounts }}
          volumeMounts:
{{ include $p.VolumeMounts $p | nindent 12 }}
{{- end }}
{{- if $p.Volumes }}
      volumes:
{{ include $p.Volumes $p | nindent 8 }}
{{- end }}
{{- if $p.SidecarContainers }}
{{ include $p.SidecarContainers $p | nindent 6 }}
{{- end }}
{{- end -}}
