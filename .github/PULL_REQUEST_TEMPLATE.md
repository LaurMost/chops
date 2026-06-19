<!--
Title should follow Conventional Commits, e.g. "feat: install-to-tool menu".
See CONTRIBUTING.md for branch naming and commit conventions.
-->

## Summary

<!-- What does this PR do and why? -->

## Type of change

<!-- Delete the ones that don't apply. -->

- feat — new feature
- fix — bug fix
- improve — enhancement to an existing feature
- refactor — no behavior change
- docs — documentation only
- style — formatting only
- test — tests only
- build — build system / dependencies
- chore — maintenance

## How tested

<!--
Required. Describe how you manually verified this change — build, run, and
exercise the feature. "Build succeeded" is not enough. Include screenshots for
UI changes.
-->

## Checklist

- [ ] `swiftformat Chops ChopsTests --lint` passes
- [ ] `swiftlint lint --strict` passes
- [ ] `xcodebuild -scheme Chops -configuration Debug -destination 'platform=macOS' test` passes
- [ ] I built, launched, and manually exercised the changed feature
- [ ] Docs updated if behavior or setup changed
- [ ] Linked the related issue (e.g. `Closes #123`)
