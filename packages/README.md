# Package recipes

Each onboarded npm package lives at:

```text
packages/<name>/<version>/
  manifest.json
  build.entrypoint.sh
  verify.smoke.sh
  out/                  # factory output (gitignored)
```

Add a new package in a dedicated PR following [CONTRIBUTING.md](../CONTRIBUTING.md).
