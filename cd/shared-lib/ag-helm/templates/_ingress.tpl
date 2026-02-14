{{/* Ingress template. Expects dict with:
  .Name (string)
  .Namespace (string, optional)
  .Capabilities (object, required for apiVersion selection)
  .ClassName (string, optional)
  .Annotations (map, optional)
  .LabelData (template name, optional)
  .Labels (map, optional)
  .Tls (list, optional) - items: {secretName: string, hosts: [string]}
  .Hosts (list, required) - items: {host: string, paths: [{path: string, pathType: string (optional)}]}
  .ServiceName (string, required)
  .ServicePort (int, required)
*/}}
{{- define "ag-template.ingress" -}}
{{- $p := . -}}
{{- $gv := (default "" $p.Capabilities.KubeVersion.GitVersion) -}}
{{- $ann := default (dict) $p.Annotations -}}

{{- /* Organization policy: Route/Ingress must carry AviInfraSetting classification */ -}}
{{- $aviKey := "aviinfrasetting.ako.vmware.com/name" -}}
{{- $_ := required (printf "Annotations.%s is required (allowed: dataclass-low|dataclass-medium|dataclass-high|dataclass-public)" $aviKey) (get $ann $aviKey) -}}

{{- if and $p.ClassName (not (semverCompare ">=1.18-0" $gv)) -}}
  {{- if not (hasKey $ann "kubernetes.io/ingress.class") -}}
    {{- $_ := set $ann "kubernetes.io/ingress.class" $p.ClassName -}}
  {{- end -}}
{{- end -}}
{{- if semverCompare ">=1.19-0" $gv }}
apiVersion: networking.k8s.io/v1
{{- else if semverCompare ">=1.14-0" $gv }}
apiVersion: networking.k8s.io/v1beta1
{{- else }}
apiVersion: extensions/v1beta1
{{- end }}
kind: Ingress
metadata:
  name: {{ required "Name is required" $p.Name }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- end }}
  {{- if or $p.LabelData $p.Labels (include "ag-template.commonLabels" $p) }}
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
  {{- end }}
  {{- if $ann }}
  annotations:
{{ toYaml $ann | nindent 4 }}
  {{- end }}
spec:
  {{- if and $p.ClassName (semverCompare ">=1.18-0" $gv) }}
  ingressClassName: {{ $p.ClassName }}
  {{- end }}
  {{- if $p.Tls }}
  tls:
    {{- range $p.Tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $p.Hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- if and .pathType (semverCompare ">=1.18-0" $gv) }}
            pathType: {{ .pathType }}
            {{- end }}
            backend:
              {{- if semverCompare ">=1.19-0" $gv }}
              service:
                name: {{ required "ServiceName is required" $p.ServiceName }}
                port:
                  number: {{ required "ServicePort is required" $p.ServicePort }}
              {{- else }}
              serviceName: {{ required "ServiceName is required" $p.ServiceName }}
              servicePort: {{ required "ServicePort is required" $p.ServicePort }}
              {{- end }}
          {{- end }}
    {{- end }}
{{- end -}}
