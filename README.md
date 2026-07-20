<p align="center">
  <img src="screenshots/send_view.png" width="240" alt="Send view">
  <img src="screenshots/receive_view.png" width="240" alt="Receive view">
  <img src="screenshots/settings_view.png" width="240" alt="Settings view">
</p>

# Croc

A Flutter client for [croc](https://github.com/schollz/croc) on Android, Linux, and Windows. It embeds the official Go transfer engine, so transfers are fully interoperable with Croc CLI and use Croc's end-to-end encrypted PAKE protocol.

## Features

- **Send files** — pick one or several files and share the one-time code
- **Receive files** — enter a code to receive from Croc CLI or another client
- **Progress & cancellation** — real-time transfer progress with cooperative cancel
- **QR transfer codes** - show a scannable code or scan one with the Android camera
- **Native Android UX** — document picker, save dialog, and share sheet
- **Desktop transfers** - send and receive encrypted files on Linux and Windows without installing Croc CLI
- **Custom relay** — configure relay address, ports, and password
- **Adaptive layout** - bottom navigation on phones, compact navigation in small windows, and a two-column workspace on wide Linux and Windows windows

## Screenshots

| Send | Receive | Settings |
|------|---------|----------|
| ![Send](screenshots/send_view.png) | ![Receive](screenshots/receive_view.png) | ![Settings](screenshots/settings_view.png) |

<p align="center">
  <img src="screenshots/qr_code.png" width="300" alt="Transfer code QR dialog">
</p>

## Architecture

Flutter owns presentation and app state. `native/crocbridge` wraps Croc `v10.4.13`. Android uses a generated gomobile AAR through method and event channels. Linux and Windows bundle a statically linked Go helper and exchange JSON events with it over standard streams.

Received files are staged in app-private cache storage. Android's Storage Access Framework is used to save copies elsewhere, so the app does not request broad storage permissions.

## Build

Requirements:

- Flutter 3.44 or newer
- Go 1.25 or newer
- Android SDK and NDK configured for Flutter

Generate the native Croc AAR before building the Flutter application:

```bash
./tool/build_croc_bridge.sh
flutter pub get
flutter build apk
```

Desktop builds compile and bundle the Go transfer helper automatically:

```bash
flutter build linux
flutter build windows
```

The generated `android/app/libs/crocbridge.aar` and sources JAR are intentionally ignored. The build script pins the Go Mobile toolchain for reproducible output.

## Verify

```bash
(cd native/crocbridge && go test ./...)
flutter analyze
flutter test
flutter build apk --debug
flutter build linux --debug
```

The desktop process bridge also has a local-relay smoke test. In separate terminals, run:

```bash
croc relay --host 127.0.0.1
flutter test tool/desktop_engine_smoke.dart
```

For an interoperability check, start Receive in the app and send from Croc CLI with the same code:

```bash
CROC_SECRET="your-transfer-code" croc send some-file.txt
```

## Platform Scope

Encrypted sending and receiving are supported on Android, Linux, and Windows. Camera QR scanning and system sharing of received files currently target Android; desktop supports QR display and native file selection/save dialogs. Linux builds are verified locally, while the Windows helper is cross-compiled and the Windows UI is viewport-tested because Windows Flutter binaries must be assembled on a Windows host.

## Licenses

This project uses Croc under the MIT License and references Croc GUI under the ISC License. Full notices are in `third_party/`.
