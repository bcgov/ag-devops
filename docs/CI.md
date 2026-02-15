# CI documentation — shared GitHub Actions templates (.NET 8)

This document is the **full reference** for consuming the CI building blocks in this repository.

If you are looking for CD (Helm + policies), see: `docs/CD.md`.

---

## Scope and design

**What this repo provides**

- Reusable GitHub Actions workflows under `ci/dotnetcore/*.yml` using `on: workflow_call`
- Composite actions under `ci/dotnetcore/composite/*/action.yml`

**What it does not provide**

- A single “complete CI pipeline workflow” for every repo (because each app repo has its own structure)
- Repository-specific secrets, approvals, environments

---

## Consumption models (pick one)

### Model A — Copy reusable workflows into your repo (recommended)

Because GitHub reusable workflows can only be called **from `.github/workflows/`** in the called repo, the typical pattern is:

1. Copy needed templates from this repo: `ci/dotnetcore/*.yml`
2. Place them into your app repo: `.github/workflows/`
3. Create a small entry workflow that calls them

Benefits
- Easiest to understand and debug
- No cross-repo permission surprises
- Your pipeline does not break if this repo changes

Tradeoffs
- You must manually sync updates from this repo

### Model B — Use composite actions directly from this repo

Composite actions can be referenced cross-repo.

Example:

```yaml
- uses: bcgov-c/ag-devops/ci/dotnetcore/composite/dotnet-8-build@vX.Y.Z
  with:
    dotnet_build_path: ./MySolution.sln
```

Benefits
- Centralized updates

Tradeoffs
- You must pin a ref (`@tag` or `@sha`)
- Any breaking change in this repo requires coordination

---

## Required runner assumptions

Most workflows assume:

- `ubuntu-latest` for build/test/lint/nuget
- `windows-latest` for `dotnet publish` win-x64 packaging

The test workflows install Linux utilities:

- `libxml2-utils` (`xmllint`)
- `bc`

If you use self-hosted runners, ensure these tools exist (or remove threshold/report steps).

---

## Quick-start: minimal CI pipeline for a typical .NET repo

Example “entry workflow” in your app repo: `.github/workflows/ci.yml`

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  restore:
    uses: ./.github/workflows/dotnet-8-dependencies.yml
    with:
      dotnet_build_path: ./MySolution.sln

  build:
    needs: restore
    uses: ./.github/workflows/dotnet-8-build.yml
    with:
      dotnet_build_path: ./MySolution.sln
      warn_as_error: true

  test:
    needs: build
    uses: ./.github/workflows/dotnet-8-tests-msbuild.yml
    with:
      unit_test_folder: "tests/MyProject.Tests"
      coverage_threshold: 80
      coverage_threshold_type: "line,branch"
```

---

## Reusable workflows reference (ci/dotnetcore/*.yml)

This section documents each reusable workflow in this repo: inputs, secrets, artifacts, and expected repo layout.

### 1) dotnet-8-dependencies.yml

File: `ci/dotnetcore/dotnet-8-dependencies.yml`

Purpose
- `dotnet restore`
- Optional NuGet auth setup
- Vulnerability scan via `dotnet list package --vulnerable`

Runner
- `ubuntu-latest`

Inputs
- `dotnet_build_path` (string, optional): solution/project path to restore

Secrets
- `NUGET_AUTH_TOKEN` (optional): used in a best-effort `dotnet nuget update source` command

Artifacts / cache
- Caches `**/obj/` via `actions/cache`

Notes
- The NuGet auth step updates the `nuget.org` source; if you use Azure Artifacts or another feed, prefer explicitly configuring that feed.

### 2) dotnet-8-build.yml

File: `ci/dotnetcore/dotnet-8-build.yml`

Purpose
- Build in Release, optionally treating warnings as errors, optionally stamping version

Runner
- `ubuntu-latest`

Inputs
- `dotnet_build_path` (string, optional)
- `warn_as_error` (boolean, default `false`)
- `version_prefix` (string, optional)
- `version_suffix` (string, optional)

Artifacts
- Uploads `**/bin/` and `**/obj/` as `build-artifacts` (retention 1 day)

### 3) dotnet-8-build-grpc.yml

File: `ci/dotnetcore/dotnet-8-build-grpc.yml`

Purpose
- Same as build, but installs `protoc` (for gRPC/protobuf builds)

Runner
- `ubuntu-latest`

Inputs
- Same as `dotnet-8-build.yml`

Notes
- Uses `arduino/setup-protoc@v3` and `secrets.GITHUB_TOKEN`.

### 4) dotnet-8-tests-msbuild.yml

File: `ci/dotnetcore/dotnet-8-tests-msbuild.yml`

Purpose
- Run unit tests across one or more folders
- Collect coverage via coverlet msbuild properties
- Enforce coverage thresholds (line/branch)
- Generate HTML report via `reportgenerator`

Runner
- `ubuntu-latest`

Inputs
- `unit_test_folder` (string, required): **space-separated** list of test project folders
- `coverage_threshold` (number, default `80`)
- `coverage_threshold_type` (string, default `line,branch`)
- `coverage_exclusions` (string, default `DebuggerNonUserCodeAttribute`)
- `coverage_exclude_filter` (string, optional)
- `dotnet_build_path` (string, optional): restore path

Artifacts
- Uploads `test-results` containing `**/*TestResults.xml` and `TestResults/` (retention 7 days)

Important details
- This workflow assumes your test projects support `dotnet test` and that the logger `junit` is available (via test SDK / logger package depending on your setup).

### 5) dotnet-8-tests-msbuild-combined.yml

File: `ci/dotnetcore/dotnet-8-tests-msbuild-combined.yml`

Purpose
- Same approach as msbuild tests, but runs both unit and integration test folders
- Merges coverage using `MergeWith=coverage.json`

Inputs
- Everything from `dotnet-8-tests-msbuild.yml`, plus:
  - `integration_test_folder` (string, required): **space-separated** list of integration test folders

### 6) dotnet-8-tests-collector.yml

File: `ci/dotnetcore/dotnet-8-tests-collector.yml`

Purpose
- Run tests using the `XPlat Code Coverage` collector (`--collect:"XPlat Code Coverage"`)
- Generate HTML report from `coverage.cobertura.xml`

Inputs
- `unit_test_folder` (string, required)
- `coverage_exclusions` (string, default `DebuggerNonUserCodeAttribute`)
- `coverage_exclude_filter` (string, optional)
- `dotnet_build_path` (string, optional)

Notes
- Uses `--no-build` so you typically run it after a build step or ensure restore/build is done.

### 7) dotnet-8-lint.yml

File: `ci/dotnetcore/dotnet-8-lint.yml`

Purpose
- `dotnet format --verify-no-changes --severity error`

Inputs
- `project_path` (string, default `.`)
- `runner` (string, default `ubuntu-latest`)

### 8) dotnet-8-package.yml

File: `ci/dotnetcore/dotnet-8-package.yml`

Purpose
- `dotnet publish` a self-contained, single-file `win-x64` output

Runner
- `windows-latest`

Inputs
- `dotnet_publish_subpath` (string, required): relative path under `./src` to publish
- `version_prefix` (string, optional)
- `version_suffix` (string, optional)
- `dotnet_publish_skip_publishtrimmed` (boolean, default `false`)
  - NOTE: despite the name, the script sets `-p:PublishTrimmed=true` when this is `true`.

Artifacts
- Uploads `win-x64-package` from `**/bin/Release/**/win-x64/` (retention 1 day)

### 9) dotnet-8-nuget-pack.yml

File: `ci/dotnetcore/dotnet-8-nuget-pack.yml`

Purpose
- `dotnet pack` and output `.nupkg` into `.cinuget/`
- Sets `RepositoryUrl` and `PackageProjectUrl`

Runner
- `ubuntu-latest`

Inputs
- `version_prefix` (string, optional)
- `version_suffix` (string, optional)
- `no_default_excludes` (boolean, default `false`)

Artifacts
- Uploads `nupkg` from `.cinuget/*.nupkg` (retention 1 day)

### 10) dotnet-8-nuget-deploy.yml

File: `ci/dotnetcore/dotnet-8-nuget-deploy.yml`

Purpose
- Downloads the `nupkg` artifact to `.cinuget`
- Adds a NuGet source
- Pushes all `.nupkg` (skip duplicates)

Runner
- `ubuntu-latest`

Inputs
- `nuget_feed` (string, optional)
  - defaults to `https://nuget.pkg.github.com/${GITHUB_REPOSITORY_OWNER}/index.json`

Secrets (one of these auth methods)
- `NUGET_USERNAME` + `NUGET_PASSWORD` (basic auth)
- OR `NUGET_API_KEY` (API key style)

### 11) dotnet-8-ef.yml

File: `ci/dotnetcore/dotnet-8-ef.yml`

Purpose
- Generates an EF migrations script (`dotnet-ef migrations script`)

Inputs
- `dotnet_ef_project` (string, required): startup project for `-s`
- `dotnet_ef_script` (string, required): output file path

Artifacts
- Uploads `ef-script`

---

## Composite actions reference (ci/dotnetcore/composite)

These mostly mirror the workflows, but are easier to share cross-repo.

- `dotnet-8-build` / `dotnet-8-build-grpc`
- `dotnet-8-dependencies`
- `dotnet-8-lint`
- `dotnet-8-tests-msbuild` / `dotnet-8-tests-msbuild-combined` / `dotnet-8-tests-collector`
- `dotnet-8-package`
- `dotnet-8-nuget-pack` / `dotnet-8-nuget-deploy`
- `dotnet-8-ef`

You can reference them as:

```yaml
- uses: bcgov-c/ag-devops/ci/dotnetcore/composite/dotnet-8-lint@vX.Y.Z
```

---

## Troubleshooting

### NuGet auth / private feeds

Symptoms
- `NU1301: Unable to load the service index for source ...`

Fix
- Prefer configuring your private feed explicitly.
- If using GitHub Packages, make sure `permissions: packages: read` and use a token that can read packages.

### Coverage parsing failures

Symptoms
- `xmllint: ...` or `bc: command not found`

Fix
- Ensure you run the test workflows on Ubuntu runners, or adjust the steps to install equivalent tools.

### Packaging fails (Windows)

Symptoms
- Publish step fails to find project under `./src/...`

Fix
- Verify your repo layout matches the expected `src/<subpath>` convention, or modify `dotnet_publish_subpath` usage.
