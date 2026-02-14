{{/* OpenShift Route template. Expects dict with:
  .Name (string)
  .Namespace (string, optional)
  .Host (string, required)
  .ServiceName (string, required)
  .TargetPort (string, optional; default "http")
  .Annotations (map, optional)
  .LabelData (template name, optional)
  .Labels (map, optional)
  .TlsTermination (string, optional; default "edge")
  .InsecureEdgeTerminationPolicy (string, optional; default "Redirect")
  .WildcardPolicy (string, optional; default "None")
*/}}
{{/* Public entrypoint: build OpenShift Route from module values at .Values.route */}}
{{- define "ag-template.route.openshift" -}}
{{- $c := . -}}
{{- $v := default (dict) $c.Values -}}
{{- $mv := default (dict) $c.ModuleValues -}}
{{- /* Prefer module-level route (chart-native), fallback to root */ -}}
{{- $r := default (dict) $mv.route -}}
{{- if and (empty $r) (hasKey $v "route") -}}
{{- $r = default (dict) $v.route -}}
{{- end -}}
{{- if ($r.enabled | default false) }}
{{- $p := dict -}}
{{- $_ := set $p "Name" (printf "%s-%s" $c.ApplicationGroup $c.Name | trunc 63 | trimSuffix "-") -}}
{{- $_ := set $p "Values" $c.Values -}}
{{- if $c.ModuleValues }}{{- $_ := set $p "ModuleValues" $c.ModuleValues -}}{{- end -}}
{{- $_ := set $p "Namespace" $c.Namespace -}}
{{- $_ := set $p "Host" $r.host -}}
{{- $_ := set $p "ServiceName" (printf "%s-%s" $c.ApplicationGroup $c.Name | trunc 63 | trimSuffix "-") -}}
{{- $_ := set $p "TargetPort" (default "http" $r.targetPort) -}}
{{- $_ := set $p "Annotations" (default (dict) $r.annotations) -}}
{{- $_ := set $p "LabelData" $c.LabelData -}}
{{- $_ := set $p "Labels" $c.Labels -}}

{{- /* Organization policy: Route/Ingress must carry AviInfraSetting classification */ -}}
{{- $aviKey := "aviinfrasetting.ako.vmware.com/name" -}}
{{- $_ := required (printf "route.annotations.%s is required (allowed: dataclass-low|dataclass-medium|dataclass-high|dataclass-public)" $aviKey) (get $p.Annotations $aviKey) -}}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ required "Name is required" $p.Name }}
  {{- if $p.Namespace }}
  namespace: {{ $p.Namespace }}
  {{- end }}
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
  {{- if $p.Annotations }}
  annotations:
{{ toYaml $p.Annotations | nindent 4 }}
  {{- end }}
spec:
  host: {{ required "Host is required" $p.Host }}
  to:
    kind: Service
    name: {{ required "ServiceName is required" $p.ServiceName }}
  port:
    targetPort: {{ default "http" $p.TargetPort }}
  tls:
    termination: {{ default "edge" $p.TlsTermination }}
    insecureEdgeTerminationPolicy: {{ default "Redirect" $p.InsecureEdgeTerminationPolicy }}
  wildcardPolicy: {{ default "None" $p.WildcardPolicy }}
{{- end }}
{{- end }}
