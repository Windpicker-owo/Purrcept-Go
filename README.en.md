# Purrcept Go

[简体中文](README.md) · [Architecture](docs/purrcept-architecture.md) · [Protocol](docs/purrcept-protocol.md)

The Android device and chat companion for Purrcept Engine. **The agent runs on your
computer. The phone runs neither Purrcept nor a model.** Phone messages enter the
Engine as stimuli. The agent explicitly sends replies or starts conversations,
and can connect to the authorized phone to read its screen and perform operations.

## Implemented

- Certificate-pinned HTTPS/WSS pairing and connection.
- Durable text messages, stable identities and reconnect synchronization.
- A native Kotlin foreground service owns networking and Room; Flutter presents committed state.
- Chat and control sessions are independent; disconnecting revokes control.
- Screen structure, screenshots, element taps, text input, scrolling, app launch and navigation keys.
- Journaled commands; uncertain operations are never automatically repeated.
- Chat distinguishes local persistence, Engine admission and synchronization. Offline messages replay automatically; early admission receipts keep the bubble visible.
- Engine supplies the subject name and actual processing, thought and action stages. Tap message status to inspect its last associated execution receipt.
- Resumable first-run guidance, system dark mode, large text, reduced motion and Purrcept’s own state-driven white cat.

This is a development implementation. Continuous observation, chat attachments,
voice, pets and agent read receipts are not connected yet. Android
permissions, background behavior and actual operations still require test-device validation.

## Connect

Computer-side setup lives in **Engine WebUI → Devices → Connect Android phone**.

1. If Phone is not enabled, open its connection settings, choose the computer address and port, preview and save.
2. Restart Engine normally to apply plugin or listener changes. Configuration is backed up and existing certificates are retained.
3. Select Show pairing QR code. Follow the phone’s guide to scan, review the computer and connect.
4. Refresh an expired QR directly in WebUI, without restarting Engine. An already paired phone can connect directly.

Go owns only the phone-side scanner and connection. No desktop Go program or manual JSON is required.
See the sibling [Engine phone guide](../purrcept_engine/docs/phone.md). Scanning needs no Google Play;
chat needs neither accessibility nor device control, and pairing does not grant control permission.

## Build

Use Flutter 3.50.0 / Dart 3.14, JDK 17+ and Android SDK 36. Android 11 is the minimum.
No Ubuntu, PRoot, Node, DSH runtime or upstream service credentials are required.

```sh
cd app
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/purrcept
flutter build apk --debug --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest --console=plain
```

The development APK is `app/build/app/outputs/flutter-apk/app-debug.apk`. Configure
your own release signing before distribution. Do not uninstall an existing app to
resolve signing conflicts.
Flutter 3.50's standard localization generator still references deprecated SDK
localization classes. Their analyzer info remains visible; errors and warnings fail validation.

Element operations compare a fresh UI tree before dispatch. Content notifications
with no observed changes keep the frame usable; window transitions, scrolling and
accepted actions revoke it, requiring another `screen` call. Local JVM tests cover
replacement, revocation and rejection of changed trees. Device behavior still
requires installing and testing the updated APK.

Purrcept Cel tokens are frozen from Purrcept Design. Run `python tooling/export_cel.py`
to regenerate their Flutter mapping and add `--check` to verify it.

Active Dart sources are `app/lib/purrcept/`; Android sources are selected from
`app/android/app/src/purrcept/`. Unused DSH sources, models, runtimes, SDKs, sites and old UI images have been
removed. Git history retains upstream implementations; licensing notices remain here.

## Attribution and license

Derived from [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) by
[ccch1mneyyy](https://github.com/ccch1mneyyy). Purrcept modifications include the
remote device protocol, native service, chat UI and Engine integration. Original
AGPL-3.0 and third-party notices are retained in [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The app uses its own name and icon;
upstream assets retain their separate terms in [ASSETS.md](ASSETS.md).
