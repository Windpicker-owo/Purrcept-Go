# Contributing

[中文](CONTRIBUTING.md) · [Project home](README.en.md)

## External pull requests are closed

This repository currently does not accept external pull requests. Use
[Issues](https://github.com/Windpicker-owo/Purrcept-Go/issues) for problems and suggestions.
Maintainers and their agents follow AGENTS.md and work on the synchronized main branch.

## Environment and ownership

Use Flutter 3.50 / Dart 3.14, JDK 17+ and Android SDK 36. Android 11 is the minimum.
The subject runs in Purrcept Engine. The phone owns its connection, durable chat cache and
explicitly authorized Android operations. Active sources live in app/lib/purrcept and
app/android/app/src/purrcept. Unused DSH sources, models, runtimes, SDKs, sites and test
images have been removed; Git history retains the upstream implementation.

Write commit subjects and bodies in Chinese. Stage explicit paths. Keep runtime data,
pairing invitations, tokens, signing keys and APKs out of Git. Retain the attribution and
terms in LICENSE, ASSETS.md and THIRD_PARTY_NOTICES.md.

## Changes and checks

Check Engine when changing protocol behavior. Edit both ARB inputs under
app/lib/purrcept/l10n and run flutter gen-l10n. Edit design/purrcept-cel.tokens.json before
regenerating tokens. Do not edit generated outputs directly. Keep contracts, comments and
necessary tests aligned with behavior.

```sh
python tooling/export_cel.py --check
python -m unittest discover -s tooling -p test_phone_eval.py
cd app
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest --console=plain
```

CI uses synthetic data and does not control phones or real accounts. Device permissions,
background recovery and operation effects require separately authorized device validation;
desktop tests cannot replace it. Explain checks that were not run. Keep signatures consistent
for an update. Preserve the installed app and its data when signatures conflict, and inspect
the certificates first. Configure your own release signing before distribution.

Report the build, Android version, connection steps, error and repeatable actions. Follow
[SECURITY.en.md](SECURITY.en.md) for private security reports.
