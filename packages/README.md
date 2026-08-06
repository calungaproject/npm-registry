# Package recipes

Each onboarded npm package lives at:

```text
packages/<name>/<version>/
  manifest.json
  build.entrypoint.sh
  verify.smoke.sh
  out/                  # factory output (gitignored)
```

Add a **new** `packages/<name>/<version>/` in a dedicated PR following
[CONTRIBUTING.md](../CONTRIBUTING.md). Do not modify an existing name/version directory
after it has merged — onboard the next version instead.
