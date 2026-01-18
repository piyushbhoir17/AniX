# AniX 🎬

An open-source Flutter app to watch anime in Hindi with offline download support.

![Flutter](https://img.shields.io/badge/Flutter-3.38.7-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android%20|%20iOS%20|%20Web-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## ✨ Features

- 🎨 **Beautiful UI** - Material You design with Dracula theme
- 🌙 **Light & Dark Mode** - System-adaptive theming
- 📚 **Anime Library** - Bookmark and organize your favorite anime
- 📥 **Offline Downloads** - Download episodes with smart M3U8/HLS handling
- 🎬 **Custom Player** - Feature-rich video player inspired by Dartatsu
- 🔍 **Smart Search** - Find anime quickly with episode search
- 📊 **Download Manager** - Track and manage downloads
- 💾 **Progress Tracking** - Auto-save watch progress
- 🔄 **Resume Support** - Continue watching where you left off
- 📺 **Multi-Season Support** - Browse all seasons with dropdown selector
- 🔎 **Episode Search** - Quickly find episodes in large series

## 📱 Screenshots

*Coming soon*

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── app.dart                     # MaterialApp configuration
├── core/
│   ├── constants/               # App constants
│   ├── theme/                   # Material You Dracula theme
│   ├── utils/                   # Helpers and extensions
│   └── errors/                  # Error handling, crash logger
├── data/
│   ├── models/                  # Data models (Isar)
│   ├── database/                # Isar setup & repositories
│   └── services/                # Scraper, M3U8, Download services
├── features/
│   ├── home/                    # Library screen
│   ├── anime_details/           # Anime info with seasons & episodes
│   ├── downloads/               # Downloaded content
│   ├── download_manager/        # Active downloads
│   ├── player/                  # Video player
│   ├── search/                  # Search screen
│   ├── settings/                # App settings
│   └── permissions/             # First-run permissions
├── providers/                   # Riverpod providers
└── widgets/                     # Reusable UI components
```

## 🛠️ Tech Stack

- **Framework**: Flutter 3.38.7+
- **State Management**: Riverpod
- **Database**: Isar Community
- **Video Player**: media_kit
- **WebView**: flutter_inappwebview
- **HTTP**: Dio

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.38.7+
- Android Studio / VS Code
- Android SDK (for Android builds)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Dreamyboyyt/anix.git
cd anix
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code (Isar schemas, Riverpod):
```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
flutter run
```

### Building

#### Debug APK
```bash
flutter build apk --debug
```

#### Release APK
```bash
flutter build apk --release
```

#### App Bundle (Play Store)
```bash
flutter build appbundle --release
```

## 📦 Download

Download the latest release from [Releases](../../releases).

## 🔐 Permissions

The app requires the following permissions:

| Permission | Purpose |
|------------|---------|
| Internet | Fetch anime data and stream videos |
| Notifications | Show download progress |
| Storage | Save downloaded episodes to `/storage/emulated/0/AniX` (customizable) |

## 🎯 Roadmap

- [ ] Episode auto-update notifications
- [ ] Background downloads
- [ ] Picture-in-Picture mode
- [ ] Chromecast support
- [ ] Multiple language support
- [ ] Sync across devices

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This app is for educational purposes only. Please support the official anime releases.

## 🙏 Acknowledgments

- [Dartatsu](https://github.com/dartatsu) for video player inspiration
- [Dracula Theme](https://draculatheme.com/) for the color palette
- All the amazing Flutter package authors

---

Made with ❤️ using Flutter
