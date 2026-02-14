{{/* Reusable PersistentVolumeClaim template */}}
{{- define "ag-template.pvc" -}}
{{- $p := . -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ printf "%s-%s" $p.ApplicationGroup $p.Name | trunc 63 | trimSuffix "-" }}
  labels:
    app.kubernetes.io/name: {{ $p.Name }}
    app.kubernetes.io/part-of: {{ $p.ApplicationGroup }}
{{- with $p | include "ag-template.commonLabels" }}
{{ . | nindent 2 }}
{{- end }}
{{- if $p.Annotations }}
  annotations:
{{ toYaml $p.Annotations | nindent 4 }}
{{- end }}
spec:
  accessModes:
{{- range (default (list "ReadWriteOnce") $p.AccessModes) }}
  - {{ . }}
{{- end }}
  resources:
    requests:
      storage: {{ default $p.Size $p.Storage | required "PVC Storage size is required (e.g., 1Gi)" }}
{{- if $p.StorageClassName }}
  storageClassName: {{ $p.StorageClassName }}
{{- end }}
{{- if $p.VolumeMode }}
  volumeMode: {{ $p.VolumeMode }}
{{- end }}
{{- if $p.Selector }}
  selector:
{{ toYaml $p.Selector | nindent 4 }}
{{- end }}
{{- end -}}
