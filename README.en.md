# Purrcept Go

[简体中文](README.md) · [Architecture](docs/purrcept-architecture.md) · [Protocol](docs/purrcept-protocol.md)

The Android social companion and remote device app for Purrcept Engine. **The agent runs on your
computer. The phone runs neither Purrcept nor a model.** Phone messages (text, stickers, voice clips,
photos, and quote-replies) enter Engine as stimuli. The agent explicitly sends replies or starts
conversations, and can connect to the authorized phone to read its screen and perform operations.

## Implemented

- **Purrcept Cel v0.4 Design System**: Clear Academy (sky × peach atmosphere glow, halftone accents, zero-blur cel hard shadows, asymmetric speech bubbles) × Warm Notebook cards, supporting light/dark mode, large text, and reduced motion.
- **Custom Companion & User Avatars**: Album avatars, 6 built-in presets, and a user nickname. The Bot can set its own app avatar through `me.phone.chat.set_avatar(media_id=...)`; offline changes sync after reconnect.
- **Rich Social Chat**: 12 built-in companion stickers, the user's personal sticker favorites, hold-to-talk / slide-to-cancel 16 kHz mono WAV voice recording and waveform playback, photos, quote-replies, and time groups. Text entry and attachment controls use separate rows on narrow screens.
- **Independent Sticker Ownership**: The app's My favorites collection stays on the phone and supports offline add/delete. The Bot's `me.stickers` library lives in Engine and serves its QQ and phone messages. Membership changes never affect the other collection.
- **Backward-Compatible Feature Negotiation**: Negotiates `rich_chat` via `welcome.features`, degrading cleanly to strict 3-field text frames when paired with an older Engine while keeping local rich rendering intact.
- Certificate-pinned HTTPS/WSS pairing and connection; durable local enqueue and idempotent reconnect replay.
- A native Kotlin foreground service owns networking, Room, and audio recording/playback; Flutter presents committed state.
- Chat and control sessions are independent; disconnecting revokes control; uncertain operations are never automatically repeated.
- Engine supplies the subject name and actual processing, thought, and action stages, anchored by a peeking mascot foreground status banner (static when quiet, dual-tone wave or cel sweep when active).

This is a development implementation. Continuous observation, floating desktop pets, and agent read
receipts are not connected yet. Android permissions, background behavior, and actual operations still
require test-device validation.

## Connect

Computer-side setup lives in **Engine WebUI → Devices → Connect Android phone**.

1. If Phone is not enabled, open its connection settings, choose the computer address and port, preview and save.
2. Restart Engine normally to apply plugin or listener changes. Configuration is backed up and existing certificates are retained.
3. Select Show pairing QR code. Follow the phone’s guide to scan, review the computer and connect.
4. Refresh an expired QR directly in WebUI, without restarting Engine. An already paired phone can connect directly.

Go owns only the phone-side scanner and connection. No desktop Go program or manual JSON is required.
See the sibling [Engine phone guide](../purrcept_engine/docs/phone.md). Scanning needs no Google Play;
chat needs neither accessibility nor device control, and microphone access is requested only when recording voice.

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

Purrcept Cel v0.4.0 tokens are frozen from Purrcept Design. Run `python tooling/export_cel.py`
to regenerate their Flutter mapping and add `--check` to verify it.

Active Dart sources are `app/lib/purrcept/`; Android sources are selected from
`app/android/app/src/purrcept/`. Unused DSH sources, models, runtimes, SDKs, sites and old UI images have been
removed. Git history retains upstream implementations; licensing notices remain here.

## Attribution and license

Derived from [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) by
[ccch1mneyyy](https://github.com/ccch1mneyyy). Purrcept modifications include the
remote device protocol, native service, social companion chat UI and Engine integration. Original
AGPL-3.0 and third-party notices are retained in [LICENSE](LICENSE) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The app uses its own name and icon;
upstream assets retain their separate terms in [ASSETS.md](ASSETS.md).
