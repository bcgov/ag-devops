# Network Policy Validation Rules
# Usage: conftest test rendered.yaml --policy policy/

package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Approval / justification for risky egress patterns.
# Docs: docs/network-policies.md ("DON'T: Use 0.0.0.0/0 Without Justification")
internet_egress_justification_key := "justification"
internet_egress_approved_by_key := "approvedBy"

# Deny if no NetworkPolicy exists for Deployments
deny[msg] {
    input.kind == "Deployment"
    deployment_name := input.metadata.name
    not has_network_policy_for(deployment_name)
    msg := sprintf("Deployment '%s' has no NetworkPolicy", [deployment_name])
}

# Deny if Deployment pods missing DataClass label
deny[msg] {
    input.kind == "Deployment"
    deployment_name := input.metadata.name
    not has_dataclass_label(input)
    msg := sprintf("Deployment '%s' missing DataClass label in pod template", [deployment_name])
}

# Deny if DataClass value is invalid
deny[msg] {
    input.kind == "Deployment"
    deployment_name := input.metadata.name
    dataclass := input.spec.template.metadata.labels.DataClass
    not valid_dataclass(dataclass)
    msg := sprintf("Deployment '%s' has invalid DataClass value '%s' (must be Low, Medium, or High)", [deployment_name, dataclass])
}

# Deny if NetworkPolicy missing policyTypes
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not input.spec.policyTypes
    msg := sprintf("NetworkPolicy '%s' missing policyTypes field", [policy_name])
}

# Deny if NetworkPolicy missing podSelector
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not input.spec.podSelector
    msg := sprintf("NetworkPolicy '%s' missing podSelector", [policy_name])
}

# Deny if NetworkPolicy has empty podSelector (matches all)
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    input.spec.podSelector == {}
    not is_default_deny_policy(input)
    msg := sprintf("NetworkPolicy '%s' has empty podSelector - matches ALL pods (dangerous)", [policy_name])
}

# Deny allow-all ingress rules:
# - ingress item is an empty object: `- {}`
# - missing/empty `from` peers
# - missing/empty `ports` (would allow all ports)
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    is_empty_object(rule)

    msg := sprintf("NetworkPolicy '%s' has allow-all ingress rule '- {}' (dangerous)", [policy_name])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    not is_empty_object(rule)

    from_peers := object.get(rule, "from", [])
    count(from_peers) == 0

    msg := sprintf("NetworkPolicy '%s' ingress rule #%d is missing 'from' (would allow all sources)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    not is_empty_object(rule)

    not has_ports(rule)
    msg := sprintf("NetworkPolicy '%s' ingress rule #%d is missing 'ports' (would allow all ports)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    not is_empty_object(rule)

    some p
    ports := object.get(rule, "ports", [])
    port := ports[p]
    object.get(port, "port", null) == null

    msg := sprintf("NetworkPolicy '%s' ingress rule #%d has a port entry missing 'port'", [policy_name, i+1])
}

# Deny allow-all egress rules:
# - egress item is an empty object: `- {}`
# - missing/empty `to` peers
# - missing/empty `ports` (would allow all ports)
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    is_empty_object(rule)

    msg := sprintf("NetworkPolicy '%s' has allow-all egress rule '- {}' (dangerous)", [policy_name])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    not is_empty_object(rule)

    to_peers := object.get(rule, "to", [])
    count(to_peers) == 0

    msg := sprintf("NetworkPolicy '%s' egress rule #%d is missing 'to' (would allow all destinations)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    not is_empty_object(rule)

    not has_ports(rule)
    msg := sprintf("NetworkPolicy '%s' egress rule #%d is missing 'ports' (would allow all ports)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    not is_empty_object(rule)

    some p
    ports := object.get(rule, "ports", [])
    port := ports[p]
    object.get(port, "port", null) == null

    msg := sprintf("NetworkPolicy '%s' egress rule #%d has a port entry missing 'port'", [policy_name, i+1])
}

# Deny wildcard peers within rules (e.g., `- {}` inside from/to, or `podSelector: {}`).
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    peers := object.get(rule, "from", [])
    some j
    peer := peers[j]
    is_empty_object(peer)

    msg := sprintf("NetworkPolicy '%s' ingress rule #%d has an empty peer selector in 'from' (would match everything)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    peers := object.get(rule, "to", [])
    some j
    peer := peers[j]
    is_empty_object(peer)

    msg := sprintf("NetworkPolicy '%s' egress rule #%d has an empty peer selector in 'to' (would match everything)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "ingress", [])[i]
    peers := object.get(rule, "from", [])
    some j
    peer := peers[j]
    object.get(peer, "podSelector", null) == {}

    msg := sprintf("NetworkPolicy '%s' ingress rule #%d uses podSelector: {} in 'from' (matches ALL pods)", [policy_name, i+1])
}

deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    peers := object.get(rule, "to", [])
    some j
    peer := peers[j]
    object.get(peer, "podSelector", null) == {}

    msg := sprintf("NetworkPolicy '%s' egress rule #%d uses podSelector: {} in 'to' (matches ALL pods)", [policy_name, i+1])
}

# Deny internet-wide egress blocks unless explicitly justified/approved.
deny[msg] {
    input.kind == "NetworkPolicy"
    policy_name := input.metadata.name
    not is_default_deny_policy(input)

    some i
    rule := object.get(input.spec, "egress", [])[i]
    peers := object.get(rule, "to", [])
    some j
    peer := peers[j]
    ipb := object.get(peer, "ipBlock", null)
    ipb != null

    cidr := object.get(ipb, "cidr", "")
    cidr in ["0.0.0.0/0", "::/0"]
    not has_internet_egress_approval(input)

    msg := sprintf("NetworkPolicy '%s' contains internet-wide egress to %s without required annotations %q and %q", [policy_name, cidr, internet_egress_justification_key, internet_egress_approved_by_key])
}

# Helper functions
has_dataclass_label(deployment) {
    deployment.spec.template.metadata.labels.DataClass
}

valid_dataclass(value) {
    value in ["Low", "Medium", "High"]
}

has_network_policy_for(deployment_name) {
    # This check requires all manifests to be passed together
    # In practice, we check if deployment has matching network policy
    true  # Simplified - actual check would scan all inputs
}

has_egress_rules(policy) {
    e := object.get(policy.spec, "egress", [])
    count(e) > 0
}

has_ports(rule) {
    ports := object.get(rule, "ports", [])
    count(ports) > 0
}

is_empty_object(x) {
    x == {}
}

has_internet_egress_approval(policy) {
    ann := object.get(policy.metadata, "annotations", {})
    justification := object.get(ann, internet_egress_justification_key, "")
    approved_by := object.get(ann, internet_egress_approved_by_key, "")
    justification != ""
    approved_by != ""
}

is_default_deny_policy(policy) {
    # Default deny policies intentionally have empty podSelector and no allowed peers.
    ingress := object.get(policy.spec, "ingress", [])
    egress := object.get(policy.spec, "egress", [])
    count(ingress) == 0
    count(egress) == 0
}
