# Hohte Matgna Mobile - Project Structure

Below is the structured folder tree for the project.

```text
mobile/
├── android/                # Android native project files
├── ios/                    # iOS native project files
├── lib/                    # Main Dart source code
│   ├── main.dart           # Application entry point
│   ├── core/               # Shared constants, utilities, and core logic
│   ├── models/             # Data models (Hymn, Practice, etc.)
│   ├── providers/          # State management (ChangeNotifier/Provider)
│   ├── services/           # API and infrastructure services
│   │   ├── auth_service.dart
│   │   ├── hymn_service.dart
│   │   ├── metadata_service.dart
│   │   └── practice_service.dart
│   ├── screens/            # UI Screens
│   │   ├── auth/           # Authentication flow (Login, Register, Splash)
│   │   └── home/           # Main application screens
│   │       ├── home_screen.dart
│   │       ├── detail/     # Hymn details and practice interface
│   │       │   ├── hymn_detail_screen.dart
│   │       │   └── widgets/  # Detail-specific components
│   │       │       ├── audio_player_widget.dart
│   │       │       ├── compare_widget.dart
│   │       │       ├── full_lyrics_widget.dart
│   │       │       ├── interactive_lyrics_widget.dart
│   │       │       ├── main_audio_player.dart
│   │       │       ├── practice_history_widget.dart
│   │       │       ├── recording_widget.dart
│   │       │       └── section_widget.dart
│   │       └── widgets/      # Home-specific components (HymnCard, etc.)
│   ├── theme/              # App themes and styling
│   └── widgets/            # Global reusable UI widgets
├── test/                   # Unit and widget tests
├── web/                    # Web platform files
├── windows/                # Windows platform files
├── pubspec.yaml            # Project dependencies and assets
└── README.md               # Project documentation
```
