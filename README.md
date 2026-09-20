<div align="center">

# 📱 ConnectCall

### Real-time 1-to-1 audio and video calling, built with Flutter

Connect with people instantly through secure, cross-platform voice and video calls powered by WebRTC and Supabase.

<p>
  <a href="https://github.com/Bhishamt/ConnectCall/stargazers"><img src="https://img.shields.io/github/stars/Bhishamt/ConnectCall?style=for-the-badge&logo=github&color=F5B301" alt="GitHub stars"></a>
  <a href="https://github.com/Bhishamt/ConnectCall/network/members"><img src="https://img.shields.io/github/forks/Bhishamt/ConnectCall?style=for-the-badge&logo=github&color=6C63FF" alt="GitHub forks"></a>
  <a href="https://github.com/Bhishamt/ConnectCall/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-22C55E?style=for-the-badge" alt="MIT license"></a>
</p>

<p>
  <img src="https://img.shields.io/badge/Flutter-3.47.2-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter 3.47.2">
  <img src="https://img.shields.io/badge/Dart-3.13.2-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart 3.13.2">
  <img src="https://img.shields.io/badge/WebRTC-Peer--to--peer-333333?style=flat-square" alt="WebRTC">
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white" alt="Supabase">
</p>

[Features](#-features) · [Architecture](#-architecture) · [Getting started](#-getting-started) · [Configuration](#-configuration) · [Contributing](#-contributing)

</div>

---

## ✨ What is ConnectCall?

**ConnectCall** is a feature-rich Flutter application for seamless peer-to-peer audio and video calling across mobile, web, and desktop. Supabase handles authentication, persistence, and signaling while WebRTC delivers low-latency media directly between participants.

> Built for focused 1-to-1 conversations—with a clean foundation that is easy to extend.

### Why it stands out

- ⚡ Built for speed with direct peer-to-peer media routing
- 🔒 Secure-by-default architecture using Supabase authentication and RLS
- 📱 Cross-platform support for modern app ecosystems
- 🧩 Clean feature-first structure that is ready for extension

## 📸 App Preview

> A dedicated visual showcase can be added here as the app evolves.

```text
┌──────────────────────────────────────────────┐
│ Upcoming UI Preview                          │
│ - Auth screen                                │
│ - User directory                             │
│ - In-call audio/video interface              │
│ - Call history dashboard                     │
└──────────────────────────────────────────────┘
```

<p align="center">
  <img src="https://via.placeholder.com/1200x400?text=ConnectCall+App+Preview" alt="ConnectCall app preview placeholder" width="100%" />
</p>

## 🗺️ Roadmap

Planned improvements and next milestones for the project:

- ✅ Core real-time calling flow
- ✅ Authentication and user discovery
- ✅ Call history and presence tracking
- 🔜 Group calling support
- 🔜 Enhanced push notification handling
- 🔜 Better call quality controls and adaptive bandwidth tuning
- 🔜 Native desktop polish and accessibility improvements

## 🚀 Features

| | Capability | Details |
|---|---|---|
| 🔐 | **Authentication** | Email/password registration, persistent sessions, and automatic session restoration |
| 👥 | **User discovery** | Searchable directory with profiles and real-time online presence |
| 📞 | **Audio calling** | Mute/unmute, speakerphone controls, and call duration tracking |
| 🎥 | **Video calling** | Picture-in-picture preview, camera switching, and video controls |
| 📝 | **Call history** | Direction, type, duration, timestamps, and missed-call status |
| 🔔 | **Notifications** | Incoming-call alerts with accept and reject workflows |
| 🛡️ | **Permissions** | Graceful camera and microphone permission handling |
| 🌍 | **Cross-platform** | Android, iOS, Web, macOS, Windows, and Linux support |

## 🧱 Architecture

ConnectCall uses a clean, layered, feature-first structure:

```text
lib/
├── core/              Shared constants, errors, theme, and utilities
├── models/            User and call data models
├── repositories/      Supabase data-access layer
├── services/          WebRTC, signaling, notifications, permissions, presence
├── features/          Auth, home, contacts, calling, profile, history, users
└── main.dart          Application entry point
```

### Call flow

```text
Authenticate with Supabase
          ↓
Browse contacts and presence
          ↓
Start a call
          ↓
Exchange SDP / ICE through Supabase Realtime
          ↓
Stream audio and video peer-to-peer with WebRTC
          ↓
Persist call details in Supabase Postgres
```

## 🛠️ Tech stack

| Layer | Technologies |
|---|---|
| **UI** | Flutter, Dart, Material 3 |
| **State** | Riverpod |
| **Media** | `flutter_webrtc`, WebRTC, DTLS-SRTP |
| **Backend** | Supabase Auth, Postgres, RLS, Realtime |
| **Platform services** | Permissions, audio session, connectivity, local notifications |

## 📦 Getting started

### Prerequisites

- Flutter SDK `>= 3.13.2`
- Dart SDK `>= 3.13.2` (bundled with Flutter)
- Android SDK API 34+ and JDK 17 for Android
- Xcode 14+ for iOS/macOS
- A Supabase project

### 1. Clone and install

```bash
git clone https://github.com/Bhishamt/ConnectCall.git
cd ConnectCall
flutter pub get
```

### 2. Configure Supabase

1. Create a project at [supabase.com](https://supabase.com/).
2. Copy the project URL and anonymous key from **Project Settings → API**.
3. Run `supabase/migrations/01_schema.sql` in the Supabase **SQL Editor**.

### 3. Run with environment variables

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

> Keep credentials out of source control. Runtime `--dart-define` values are recommended for local and release builds.

### 4. Verify the project

```bash
flutter analyze
flutter test
flutter run
```

## ⚙️ Configuration

### TURN servers

The default signaling configuration includes public STUN servers. For users behind symmetric NATs or strict enterprise firewalls, add a TURN server in `lib/services/webrtc_calling_service.dart`:

```dart
'iceServers': [
  {'urls': 'stun:stun.l.google.com:19302'},
  {
    'urls': 'turn:your-turn-server.com',
    'username': 'user',
    'credential': 'pass',
  },
],
```

Possible TURN providers include [Metered](https://metered.ca/) and [Twilio](https://www.twilio.com/).

### Media quality

Audio noise suppression and echo cancellation are enabled by default. Video constraints can be tuned in `lib/services/webrtc_calling_service.dart` for resolution and frame rate.

## 🌐 Platform support

| Platform | Status | Notes |
|---|---:|---|
| Android | ✅ | API 34+, physical camera/microphone recommended |
| iOS | ✅ | iOS 14+, test camera and microphone flows on a physical device |
| Web | ⚠️ | Chrome and Firefox recommended; Safari WebRTC support may vary |
| macOS | ✅ | Intel and Apple Silicon |
| Windows | ✅ | Windows 10+ |
| Linux | ✅ | Ubuntu 20.04+ |

## 🔒 Security and privacy

- Supabase Row-Level Security helps isolate user and call-history data.
- Supabase Auth manages password hashing and authenticated access.
- WebRTC uses DTLS-SRTP for media encryption.
- Supabase Realtime carries signaling data—not audio or video media.
- Camera and microphone permissions are requested at runtime.

## 🧪 Development commands

```bash
# Format and analyze
dart format lib/
flutter analyze

# Run tests and coverage
flutter test
flutter test --coverage

# Apply automated Dart fixes
dart fix --apply

# Build an Android release
flutter build apk --release
```

## 🤝 Contributing

Contributions are welcome and appreciated!

1. Fork the repository.
2. Create a branch: `git checkout -b feature/your-feature`.
3. Make your changes and add tests where appropriate.
4. Commit clearly: `git commit -m "feat: describe your change"`.
5. Push your branch and open a pull request.

Please keep changes focused, follow Dart/Flutter conventions, and update the documentation when behavior changes.

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 💬 Support

- Read the [FAQ](docs/FAQ.md)
- [Open an issue](https://github.com/Bhishamt/ConnectCall/issues)
- [Start a discussion](https://github.com/Bhishamt/ConnectCall/discussions)

<div align="center">

### If ConnectCall is useful to you, consider giving it a ⭐

**Happy calling! 🚀**

</div>
