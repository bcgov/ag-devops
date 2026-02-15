# AG Reusable DevOps Template and Library

Shared CI/CD templates and policy-as-code for application teams.

[![CI](https://img.shields.io/badge/CI-.NET%208-blue)](#ci)
[![CD](https://img.shields.io/badge/CD-Helm%20%2B%20Policies-purple)](#cd)
[![Helm](https://img.shields.io/badge/Helm-Library%20Chart-0F1689)](#cd)
[![Policies](https://img.shields.io/badge/Policies-Datree%20%7C%20Polaris%20%7C%20kube--linter%20%7C%20OPA-orange)](#cd)

## Quick links

- Start here: [docs/CI-CD-START-HERE.md](docs/CI-CD-START-HERE.md)
- Developer guide (deny-by-default cluster): [docs/DEVELOPERS-GUIDE.md](docs/DEVELOPERS-GUIDE.md)
- CI documentation (full reference): [docs/CI.md](docs/CI.md)
- CD documentation (full reference): [docs/CD.md](docs/CD.md)

## What this repo is

This repository is a **shared library** of:

- GitHub Actions templates for .NET 8 CI
- A Helm **library chart** for consistent Kubernetes/OpenShift resources
- Kubernetes manifest policy configurations (Datree, Polaris, kube-linter, Conftest/OPA)

It is not an application. Your app repo consumes these assets.

## Why this exists

- Consistency: teams build/test/package/deploy the same way.
- Security & compliance: manifests are validated against required policies before deployment.
- Reuse: avoid copy/paste YAML drift across repositories.
- Faster onboarding: new repos start with a known-good baseline.

## Repository structure

- [ci/dotnetcore/](ci/dotnetcore/) — reusable workflows + composite actions
- [cd/shared-lib/ag-helm/](cd/shared-lib/ag-helm/) — Helm library chart (ag-helm-templates)
- [cd/shared-lib/example-app/](cd/shared-lib/example-app/) — example consumer chart
- [cd/policies/](cd/policies/) — policy configs and Rego rules

## How to use

- For CI: follow [docs/CI.md](docs/CI.md) (choose either “copy workflows” or “use composite actions”).
- For CD: follow [docs/CD.md](docs/CD.md) (consume the Helm library + run the policy checks on rendered manifests).

---

## CI

> ✅ Use the CI templates when you want consistent .NET 8 build/test/pack steps across repos.

- Templates and actions live under [ci/dotnetcore/](ci/dotnetcore/).
- Start with: [docs/CI.md](docs/CI.md).

---

## CD

> ✅ Use the CD assets when you deploy via Helm and want enforced Kubernetes/OpenShift standards.

- Helm library chart: [cd/shared-lib/ag-helm/](cd/shared-lib/ag-helm/)
- Example consumer: [cd/shared-lib/example-app/](cd/shared-lib/example-app/)
- Policy configs: [cd/policies/](cd/policies/)
- Start with: [docs/CD.md](docs/CD.md).

