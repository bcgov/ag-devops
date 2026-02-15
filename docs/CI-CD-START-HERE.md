# CI/CD shared templates — start here

[![CI](https://img.shields.io/badge/CI-Docs-blue)](CI.md)
[![CD](https://img.shields.io/badge/CD-Docs-purple)](CD.md)
[![Helm](https://img.shields.io/badge/Helm-Library%20Chart-0F1689)](../cd/shared-lib/ag-helm/)
[![Policies](https://img.shields.io/badge/Policies-OPA%20%2B%20Linters-orange)](../cd/policies/)

Use this page as an index. The detailed references are:

- CI (GitHub Actions / .NET 8): [CI.md](CI.md)
- CD (Helm library + policy checks): [CD.md](CD.md)
- Developer onboarding (deny-by-default clusters): [DEVELOPERS-GUIDE.md](DEVELOPERS-GUIDE.md)

## Why this repo exists

- Standardize CI/CD across teams.
- Enforce required Kubernetes/OpenShift guardrails with policy-as-code.
- Make deployments repeatable, reviewable, and easier to troubleshoot.

## Where things live

- CI templates: [ci/dotnetcore/](../ci/dotnetcore/)
- Helm library: [cd/shared-lib/ag-helm/](../cd/shared-lib/ag-helm/)
- Example consumer chart: [cd/shared-lib/example-app/](../cd/shared-lib/example-app/)
- Policy configs (Datree/Polaris/kube-linter/Conftest): [cd/policies/](../cd/policies/)

## Typical usage flow

1. CI: build/test/package your app using the shared CI templates.
2. CD: render manifests (usually via Helm), then run policy checks on the rendered YAML.
3. Deploy after policy checks pass.
