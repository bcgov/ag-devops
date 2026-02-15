# AviInfraSetting annotation policy (AKO)
#
# Goal
# - Enforce the repo requirement that externally reachable entrypoints (Route/Ingress)
#   declare their AviInfraSetting classification.
#
# This mirrors the schema enforced in .github/policies.yaml:
# - metadata.annotations["aviinfrasetting.ako.vmware.com/name"] is required
# - value must be one of: dataclass-low|dataclass-medium|dataclass-high|dataclass-public
#
# Usage
# - conftest test rendered.yaml --policy policy/ --all-namespaces

package main

import future.keywords.in

avi_key := "aviinfrasetting.ako.vmware.com/name"

allowed_values := {
  "dataclass-low",
  "dataclass-medium",
  "dataclass-high",
  "dataclass-public",
}

deny[msg] {
  is_entrypoint(input)
  not has_avi_annotation(input)

  name := object.get(input.metadata, "name", "<unknown>")
  ns := object.get(input.metadata, "namespace", "<unknown>")

  msg := sprintf("%s %s/%s is missing required annotation %q (allowed: %v)", [input.kind, ns, name, avi_key, sorted_allowed_values])
}

deny[msg] {
  is_entrypoint(input)
  has_avi_annotation(input)

  ann := object.get(input.metadata, "annotations", {})
  v := object.get(ann, avi_key, "")
  not (v in allowed_values)

  name := object.get(input.metadata, "name", "<unknown>")
  ns := object.get(input.metadata, "namespace", "<unknown>")

  msg := sprintf("%s %s/%s has invalid %q value %q (allowed: %v)", [input.kind, ns, name, avi_key, v, sorted_allowed_values])
}

is_entrypoint(obj) {
  obj.kind in {"Route", "Ingress"}
}

has_avi_annotation(obj) {
  ann := object.get(obj.metadata, "annotations", {})
  v := object.get(ann, avi_key, "")
  v != ""
}

sorted_allowed_values := sort([v | v := allowed_values[_]])
