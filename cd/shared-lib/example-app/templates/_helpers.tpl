{{/*
Helper: compute the application group used in names/labels.

Preference order:
- .Values.project (explicit)
- .Release.Name (helm release)
- "app" (fallback for lint/template contexts)
*/}}
{{- define "example.appGroup" -}}
{{- default (default "app" .Release.Name) .Values.project -}}
{{- end -}}
