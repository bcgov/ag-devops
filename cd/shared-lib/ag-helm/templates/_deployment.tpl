{{/*
A top-level deployment template to construct a full Kubernetes Deployment.
Parameters (dict):
  .Values
  .ApplicationGroup (string)
  .Name (string)
  .Registry (string)
  .ModuleValues (dict)
    disabled (bool, optional)
    image.tag (string, required)
    terminationGracePeriod (int, optional)
    progressDeadlineSeconds (int, optional; default 600)
    serviceAccountName (string, optional)
  .Lang (string; only 'dotnetcore' used for DD setup)
  .Ports (template name)
  .Env (template name)
  .Lifecycle (template name)
  .InitContainers (template name)
  .Probes (template name)
  .Volumes (template name)
  .VolumeMounts (template name)
  .AnnotationData (template name)
  .LabelData (template name)
  .SecurityContext (template name)
  .SidecarContainers (template name)
  .PullSecret (template name)
  .Tolerations (template name)
  .Resources (template name)
*/}}
{{- define "ag-template.deployment" -}}
{{- $p := . -}}
{{- $mv := default (dict) $p.ModuleValues -}}
{{- $autoscalingEnabled := (dig "autoscaling" "enabled" false $mv) -}}
{{- $replicas := 1 -}}
{{- if hasKey $mv "replicas" -}}
{{- $replicas = $mv.replicas -}}
{{- else if hasKey $mv "replicaCount" -}}
{{- $replicas = $mv.replicaCount -}}
{{- end -}}
{{- $replicaHint := (int $replicas) -}}
{{- if $autoscalingEnabled -}}
{{- $replicaHint = (int (dig "autoscaling" "minReplicas" 1 $mv)) -}}
{{- end -}}
{{- if not ($mv.disabled | default false) }}
{{- $resName := (printf "%s-%s" $p.ApplicationGroup $p.Name | trunc 63 | trimSuffix "-") -}}
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
kind: Deployment
metadata:
  name: {{ $resName }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- else if $.Release }}
  namespace: {{ $.Release.Namespace }}
  {{- end }}
  labels:
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
    app.kubernetes.io/instance: {{ $resName }}
{{ include "ag-template.commonLabels" $p | nindent 4 }}
{{- if gt (len $labelData) 0 }}
{{- toYaml $labelData | nindent 4 }}
{{- end }}
{{- $hasTopAnn := false }}
{{- if or $p.AnnotationData $isOpenShift }}
{{- $hasTopAnn = true }}
{{- end }}
{{- if $hasTopAnn }}
  annotations:
{{- if $p.AnnotationData }}
{{- with (include $p.AnnotationData $p | fromYaml) }}
{{- toYaml . | nindent 4 }}
{{- end }}
{{- end }}
{{- if $isOpenShift }}
    checkov.io/skip999: CKV_K8S_40=OpenShift SCC assigns runtime UID/GID; do not pin runAsUser/runAsGroup in manifests.
{{- end }}
{{- end }}
spec:
  {{- if not $autoscalingEnabled }}
  replicas: {{ $replicas }}
  {{- end }}
  revisionHistoryLimit: {{ default 3 $mv.revisionHistoryLimit }}
  progressDeadlineSeconds: {{ default 600 $mv.progressDeadlineSeconds }}
  {{- if or $mv.maxUnavailable $mv.maxSurge }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      {{- if $mv.maxUnavailable }}
      maxUnavailable: {{ $mv.maxUnavailable }}
      {{- end }}
      {{- if $mv.maxSurge }}
      maxSurge: {{ $mv.maxSurge }}
      {{- end }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ $p.Name }}
      app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ $p.Name }}
        app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
        app.kubernetes.io/instance: {{ $resName }}
        {{- if not (hasKey $labelData "DataClass") }}
        DataClass: {{ title $dc }}
        {{- end }}
{{- if gt (len $labelData) 0 }}
{{- toYaml $labelData | nindent 8 }}
{{- end }}
{{- $hasPodAnn := false }}
{{- if eq (default "" $p.Lang) "dotnetcore" }}
{{- $hasPodAnn = true }}
{{- end }}
{{- if and (not $hasPodAnn) $p.AnnotationData }}
{{- $hasPodAnn = true }}
{{- end }}
{{- if $hasPodAnn }}
      annotations:
{{- if eq (default "" $p.Lang) "dotnetcore" }}
        ad.datadoghq.com/{{ $p.Name }}.check_names: '["openmetrics"]'
        ad.datadoghq.com/{{ $p.Name }}.init_configs: '[{}]'
        ad.datadoghq.com/{{ $p.Name }}.instances: '[{"openmetrics_endpoint": "http://%%host%%:%%port%%/metrics"}]'
{{- end }}
{{- if $p.AnnotationData }}
{{- with (include $p.AnnotationData $p | fromYaml) }}
{{- toYaml . | nindent 8 }}
{{- end }}
{{- end }}
{{- end }}
    spec:
      automountServiceAccountToken: {{ default false $mv.automountServiceAccountToken }}
      securityContext:
{{ include "ag-template.defaultPodSecurityContext" . | nindent 8 }}
      {{- if or $mv.serviceAccountName $p.ServiceAccountName }}
      serviceAccountName: {{ default $p.ServiceAccountName $mv.serviceAccountName }}
      {{- end }}
      {{- if $p.PullSecret }}
      imagePullSecrets:
{{ include $p.PullSecret $p | nindent 8 }}
      {{- end }}
      {{- if or $mv.priorityClassName $p.PriorityClassName }}
      priorityClassName: {{ default $p.PriorityClassName $mv.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ default 30 $mv.terminationGracePeriod }}
      {{- if $mv.affinity }}
      affinity:
{{ toYaml $mv.affinity | nindent 8 }}
      {{- else if and (ge $replicaHint 2) (not $mv.disableDefaultAntiAffinity) }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: {{ $p.Name }}
                    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
      {{- end }}
      {{- if $mv.topologySpreadConstraints }}
      topologySpreadConstraints:
{{ toYaml $mv.topologySpreadConstraints | nindent 8 }}
      {{- else if and (ge $replicaHint 2) (not $mv.disableDefaultTopologySpread) }}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: {{ $p.Name }}
              app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
      {{- end }}
      {{- if $p.Tolerations }}
      tolerations:
{{ include $p.Tolerations $p | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ $p.Name }}
          {{ $img := get $mv "image" | default (dict) }}
          {{ $tag := get $img "tag" }}
          {{- $digest := get $img "digest" -}}
          {{- if $digest }}
          image: {{ printf "%s/%s@%s" $p.Registry $p.Name $digest }}
          {{- else }}
          image: {{ printf "%s/%s:%s" $p.Registry $p.Name (required "ModuleValues.image.tag is required when image.digest is not set" $tag) }}
          {{- end }}
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
          {{- if $p.Lifecycle }}
          lifecycle:
{{ include $p.Lifecycle $p | nindent 12 }}
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
      {{- if $p.SidecarContainers }}
{{ include $p.SidecarContainers $p | nindent 6 }}
      {{- end }}
      {{- if $p.InitContainers }}
      initContainers:
{{ include $p.InitContainers $p | nindent 8 }}
      {{- end }}
      {{- if $p.Volumes }}
      volumes:
{{ include $p.Volumes $p | nindent 8 }}
      {{- end }}
{{- end }}
{{- end }}


{{/* Convenience wrapper: simple Deployment API for common cases */}}
