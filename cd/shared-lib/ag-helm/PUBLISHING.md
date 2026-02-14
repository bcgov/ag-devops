# Publishing ag-helm-templates to GHCR

This Helm library chart is automatically published to GitHub Container Registry (GHCR) via GitHub Actions.

## Published Locations

**Development builds** (on every push to `main`):
```
oci://ghcr.io/bcgov-c/helm/ag-helm-templates:1.0.3-dev.xxxxxxx
```

**Release builds** (on version tags):
```
oci://ghcr.io/bcgov-c/helm/ag-helm-templates:1.0.3
```

## How to Use in Your Charts

### Option 1: Reference Published OCI Package (Recommended)

Update your `Chart.yaml`:

```yaml
apiVersion: v2
name: myapp-gitops
description: GitOps deployment chart for myapp
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: ag-helm-templates
    version: "1.0.3"  # or "1.0.3-dev.xxxxxxx" for dev builds
    repository: "oci://ghcr.io/bcgov-c/helm"
```

Then run:
```bash
# Login to GHCR (if using private packages)
export GITHUB_TOKEN=your_token_here
echo $GITHUB_TOKEN | helm registry login ghcr.io -u your-github-username --password-stdin

# Update dependencies
helm dependency update

# Deploy
helm install myapp . --values values.yaml
```

### Option 2: Use File Reference (Local Development)

For local development, you can still use file references:

```yaml
dependencies:
  - name: ag-helm-templates
    version: 1.0.3
    repository: file://../../../shared-lib/ag-helm
```

## Publishing Workflow

### Automatic Publishing

1. **On every push to `main`**: Creates a dev version like `1.0.3-dev.abc1234`
2. **On version tags** (e.g., `v1.0.3`): Creates a stable release `1.0.3`

### Manual Release Process

1. Update version in `shared-lib/ag-helm/Chart.yaml`:
   ```yaml
   version: 1.0.4
   ```

2. Commit and push to `main`:
   ```bash
   git add shared-lib/ag-helm/Chart.yaml
   git commit -m "chore: bump ag-helm version to 1.0.4"
   git push origin main
   ```

3. Create and push tag:
   ```bash
   git tag v1.0.4
   git push origin v1.0.4
   ```

4. GitHub Actions will automatically:
   - Package the Helm chart
   - Push to `ghcr.io/bcgov-c/helm/ag-helm-templates:1.0.4`
   - Create a GitHub Release

## Viewing Published Packages

Visit: https://github.com/bcgov-c?tab=packages

## Authentication

For public packages, no authentication is required for `helm pull` or `helm dependency update`.

For private packages:
```bash
echo $GITHUB_TOKEN | helm registry login ghcr.io -u your-username --password-stdin
```

## Troubleshooting

**Issue**: `Error: failed to download "oci://ghcr.io/bcgov-c/helm/ag-helm-templates"`

**Solution**: 
1. Check package visibility (public vs private) in GitHub
2. Ensure you're logged in if package is private
3. Verify the version exists: `helm show chart oci://ghcr.io/bcgov-c/helm/ag-helm-templates --version 1.0.3`
