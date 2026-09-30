# CI

`github-actions-ci.yml` is the intended GitHub Actions workflow: it verifies the
localizations are regenerated, checks formatting, runs `flutter analyze` and
`flutter test`, and builds a debug-signed release APK as an artifact.

It is **not** at `.github/workflows/` because the token used to create this
repository lacks GitHub's `workflow` scope, and a push that creates a workflow
file is refused without it. Nothing was worked around to get past that.

To enable it, either:

```bash
gh auth refresh -s workflow          # grant the scope, then:
git mv ci/github-actions-ci.yml .github/workflows/ci.yml
git commit -m "Enable CI" && git push
```

or paste the file's contents into a new workflow via the GitHub web UI, which
needs no extra token scope.
