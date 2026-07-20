<p align="center">
  <img src="screenshots/send_view.png" width="240" alt="Send view">
  <img src="screenshots/receive_view.png" width="240" alt="Receive view">
  <img src="screenshots/settings_view.png" width="240" alt="Settings view">
</p>

# Croc

An Android-first Flutter client for [croc](https://github.com/schollz/croc). It embeds the official Go transfer engine, so transfers are fully interoperable with Croc CLI and use Croc's end-to-end encrypted PAKE protocol.

## Features

- **Send files** — pick one or several files and share the one-time code
- **Receive files** — enter a code to receive from Croc CLI or another client
- **Progress & cancellation** — real-time transfer progress with cooperative cancel
- **Native Android UX** — document picker, save dialog, and share sheet
- **Custom relay** — configure relay address, ports, and password
- **Minimal UI** — clean, responsive layout for phone and tablet

## Screenshots

| Send | Receive | Settings |
|------|---------|----------|
| ![Send](screenshots/send_view.png) | ![Receive](screenshots/receive_view.png) | ![Settings](screenshots/settings_view.png) |

## Architecture

Flutter owns presentation and app state. `native/crocbridge` wraps Croc `v10.4.13` in a small gomobile-compatible API. Kotlin connects the generated AAR to Flutter through method and event channels.

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

The generated `android/app/libs/crocbridge.aar` and sources JAR are intentionally ignored. The build script pins the Go Mobile toolchain for reproducible output.

## Verify

```bash
(cd native/crocbridge && go test ./...)
flutter analyze
flutter test
flutter build apk --debug
```

For an interoperability check, start Receive in the app and send from Croc CLI with the same code:

```bash
CROC_SECRET="your-transfer-code" croc send some-file.txt
```

## Platform Scope

The functional native bridge currently targets Android. Other generated Flutter platforms remain in the project for future UI portability, but do not yet include a Croc engine bridge.

## Licenses

This project uses Croc under the MIT License and references Croc GUI under the ISC License. Full notices are in `third_party/`.
