# GitHub Actions templates for .NET 8

This folder contains reusable GitHub Actions workflow equivalents for the GitLab CI templates under `dotnetcore/8.0`.

Workflows provided
- dotnet-8-dependencies.yml (restore)
- dotnet-8-build.yml (standard build)
- dotnet-8-build-grpc.yml (build with protoc available)
- dotnet-8-tests-msbuild.yml (unit tests with MSBuild + coverlet)
- dotnet-8-tests-msbuild-combined.yml (unit + integration with MSBuild + coverlet)
- dotnet-8-tests-collector.yml (unit tests with XPlat collector)
- dotnet-8-package.yml (publish self-contained win-x64)
- dotnet-8-nuget-pack.yml (dotnet pack to .cinuget)
- dotnet-8-nuget-deploy.yml (push .nupkg to a NuGet feed)
- dotnet-8-ef.yml (EF migrations script)

How to use
- These are reusable templates (on: workflow_call). To run or call them, copy the needed files into your repository's `.github/workflows/` folder. GitHub only allows calling reusable workflows that are located in `.github/workflows/` of the target repo.
- After copying, call them from another workflow with `uses: <owner>/<repo>/.github/workflows/<file>.yml@<ref>` and pass inputs/secrets as needed.
- Inputs map closely to the GitLab variables. See each file header for supported inputs and defaults.

Notes
- Tests use Ubuntu for shell utilities (xmllint, bc) and install `reportgenerator` as a .NET tool.
- Packaging runs on Windows runners to produce win-x64 self-contained binaries.
- NuGet deploy supports either username/password or API key.
