
# Hohte Matgna (mobile)

This repository contains the Flutter mobile application for "Hohte Matgna" — a hymn/app content app. The project uses Provider for state management and basic HTTP/shared preferences for persistence.

## Overview

- Platform: Flutter (mobile/web/desktop-ready)
- Language: Dart
- State management: `provider`
- Key directories: `lib/` (app code), `android/`, `ios/`, `web/`

## Features

- Authentication flow (login/register)
- Hymn listing with details and search/filter UI
- Theming via `lib/core/theme` (centralized colors & text styles)
- Services and providers for API access and app state

## Quick Start

Prerequisites:

- Install Flutter (see https://docs.flutter.dev/get-started)
- A device or emulator

Run locally:

```bash
flutter pub get
flutter run
```

Build:

```bash
# Android
flutter build apk

# Web
flutter build web
```

## Project Structure (high level)

- `lib/main.dart` — app entry, providers, routing wrapper
- `lib/core/theme` — `app_theme.dart`, colors, text styles
- `lib/providers` — `AuthProvider`, `MetadataProvider`, `HymnProvider`
- `lib/services` — API wrappers (`auth_service.dart`, `hymn_service.dart`, etc.)
- `lib/screens` — UI screens (`login_screen.dart`, `home_screen.dart`, details)
- `lib/widgets` — reusable widgets (buttons, loaders, inputs)

## Notable Dependencies

- `provider` — state management
- `http` — network requests
- `shared_preferences` — local storage

See `pubspec.yaml` for exact versions.

## Development Notes

- Centralized theming lives in `lib/core/theme` (`AppTheme.lightTheme`).
- Providers are registered in `main.dart` using `MultiProvider`.
- The app uses a simple auth wrapper (`AppWrapper`) to switch between `HomeScreen` and `LoginScreen`.

## Tests

Run unit/widget tests with:

```bash
flutter test
```

## Contributing

1. Fork the repo
2. Create a feature branch
3. Open a PR with a clear description

If you want, I can open a PR template and contributing guide.

## License

Add your license here (e.g., MIT).
