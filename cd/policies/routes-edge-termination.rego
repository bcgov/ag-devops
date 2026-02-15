# OpenShift Route exposure policy
#
# Goal
# - Prevent accidental creation of publicly accessible, edge-terminated Routes for internal microservices.
# - Make public exposure an explicit, reviewable decision.
#
# Default stance
# - Edge-terminated Routes are DENIED unless explicitly allowlisted.
#
# Allowlist
# - Frontend component Routes are allowed (common valid public entrypoint).
# - Any Route can be allowed if an explicit approval annotation is present.
#
# Usage
# - conftest test rendered.yaml --policy policy/ --all-namespaces --fail-on-warn
#
package main

import future.keywords.in

approval_annotation := "isb.gov.bc.ca/edge-termination-approval"

# Deny edge termination unless explicitly approved / allowlisted.
deny[msg] {
  input.kind == "Route"
  is_edge_terminated(input)
  not is_allowlisted_edge_route(input)

  name := object.get(input.metadata, "name", "<unknown>")
  ns := object.get(input.metadata, "namespace", "<unknown>")
  host := object.get(input.spec, "host", "<unknown>")

  msg := sprintf("Route %s/%s (%s) is edge-terminated without explicit approval. Remove the Route for internal services, or add annotation %q with the ISB approval/ticket reference.", [ns, name, host, approval_annotation])
}

is_edge_terminated(route) {
  route.spec.tls.termination == "edge"
}

# Allow frontend Routes by label (template already labels frontend component).
is_allowlisted_edge_route(route) {
  labels := object.get(route.metadata, "labels", {})
  labels["app.kubernetes.io/component"] == "frontend"
}

# Allow if an explicit approval annotation is present and non-empty.
is_allowlisted_edge_route(route) {
  ann := object.get(route.metadata, "annotations", {})
  approval := object.get(ann, approval_annotation, "")
  approval != ""
}
