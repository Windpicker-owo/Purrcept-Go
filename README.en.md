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

This is a development implementation. Continuous observation, chat attachments,
voice, pets and agent read receipts are not connected yet. Android
permissions, background behavior and actual operations still require test-device validation.

## Connect

Install the `phone` extra in the sibling `purrcept_engine` repository and follow
its `docs/phone.md` to generate TLS files and enable the Phone plugin. Start Engine
with pairing enabled, then run this command from this repository's root:

```sh
uv run tooling/pair_phone.py
```

A local browser window displays the QR code. Tap **Scan to pair** on the phone,
review the computer address and certificate fingerprint, then **Pair and connect**.
No manual JSON entry is needed. Camera permission is requested only for scanning;
cancelling the scan or review performs no pairing. Scanning needs no Google Play
services. Chat requires neither accessibility nor device-control authorization,
and pairing does not grant either permission.

The tool reads the sibling `purrcept_engine/.purrcept/phone-invitation.json` by
default. Override with `--invitation <path>`. Invitations last 120 seconds; reopen
Engine's pairing window after expiry. The display follows file changes and removes
expired or consumed invitations. It only reads existing invitations, without
starting or changing Engine. Keep it running until finished, then press Ctrl+C.
If scanning is unavailable, expand **Other option: paste an invitation** on the phone.

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
Test the local pairing display with
`uv run --with qrcode==8.2 python -m unittest discover -s tooling -p test_pair_phone.py -v`.

Active Dart sources are `app/lib/purrcept/`; Android sources are selected from
`app/android/app/src/purrcept/`. Upstream DSH sources remain porting references,
outside active dependencies and source sets. The new app does not enable the old
runtime, market, sharing or analytics services.

## Attribution and license

Derived from [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) by
[ccch1mneyyy](https://github.com/ccch1mneyyy). Purrcept modifications include the
remote device protocol, native service, chat UI and Engine integration. Original
AGPL-3.0 and third-party notices are retained in [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The app uses its own name and icon;
upstream assets retain their separate terms in [ASSETS.md](ASSETS.md).
