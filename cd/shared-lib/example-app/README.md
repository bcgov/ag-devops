# Example Application Chart

This chart showcases how to consume the shared `helm-library` using a clean “set + define” style.

Contents
- StatefulSet and headless Service for `redis`
- Optional: OpenFGA API (`openfga`) with Postgres egress + strict NetworkPolicy (disabled by default)

Values overview
- Top-level service root: `redis`
- Optional service root: `openfga` (disabled by default)
- Feature flags under roots:
	- `redis.enabled: true`
	- `openfga.enabled: true`
	- `openfga.networkPolicy.create: true`

Usage pattern (set + define)
- Templates build a small dict via `set` and pass it to an `ag-template.*` function.
- Inline `define` blocks render named YAML fragments (ports, env, probes, etc.).

How to run (PowerShell)
```powershell
helm dependency update c:\Users\Stanley.Okeke\helm\example-app
helm lint c:\Users\Stanley.Okeke\helm\example-app
helm template ex c:\Users\Stanley.Okeke\helm\example-app --values c:\Users\Stanley.Okeke\helm\example-app\values-examples.yaml --debug
```

Notes
- Pods are labeled with data-class: low|medium|high (default low).
- NetworkPolicy fragments accept `.Namespace` explicitly.
- Indent fragments with spaces, not tabs.
