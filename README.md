# ConnectCall - 1-to-1 Real-Time Audio & Video Calling Application

ConnectCall is a high-performance Flutter mobile application for 1-to-1 real-time audio and video calling built using **Flutter**, **Supabase** (Auth, Postgres RLS, Realtime signaling), **WebRTC** (`flutter_webrtc`), and **Riverpod 2.x**.

---

## Project Description

ConnectCall provides a seamless cross-platform real-time audio and video communication experience for mobile and desktop platforms. Built with modern mobile architecture and reactive state management, ConnectCall offers instantaneous user discovery, live presence status updates, WebRTC peer-to-peer audio/video streaming with STUN/TURN fallback, persistent call history logging, audio session management, and permission handling.

---

## Features

- **Authentication System**: Email & password registration, login, logout, automatic session restoration, and persistent authentication state.
- **User Discovery & Contacts**: Live user directory, real-time online/offline presence tracking, user search by display name, and user profile view.
- **1-to-1 Audio Calling**: Instant outgoing call dispatch, overlay alerts for incoming calls, accept/reject workflows, live duration counter, mic mute/unmute, speakerphone toggle, and clean call termination.
- **1-to-1 Video Calling**: High-definition remote video rendering, local Picture-in-Picture (PiP) camera preview, camera enable/disable toggle, front/rear camera switching, mic mute, speaker toggle, and end call.
- **Call History Logging**: Database-persisted call history recording caller, callee, call type (audio/video), call direction (incoming/outgoing), duration, timestamps, and missed call status.
- **Permissions & Error Handling**: Graceful runtime camera and microphone permission management, permanent denial detection, network connectivity status monitoring, and human-readable error messages.

---

## Flutter Version

- **Flutter SDK**: `3.47.2` (Channel stable)
- **Dart SDK**: `3.13.2`
- **Minimum Target SDKs**: Android API 34, iOS 14+

---

## Packages Used

| Package | Version | Purpose |
| :--- | :--- | :--- |
| `supabase_flutter` | `^2.8.0` | Backend Auth, Postgres database access, RLS policies, & Realtime channels |
| `flutter_webrtc` | `^0.12.5` | P2P WebRTC peer connections, audio/video media streams, & video renderers |
| `flutter_riverpod` | `^2.6.1` | Reactive state management, dependency injection, and state machines |
| `permission_handler` | `^11.3.1` | Cross-platform camera & microphone permission request handling |
| `audio_session` | `^0.1.25` | Hardware audio routing, speakerphone toggles, and call audio focus management |
| `connectivity_plus` | `^6.1.0` | Real-time network connectivity monitoring |
| `intl` | `^0.19.0` | Date, time, and duration formatting |
| `uuid` | `^4.5.1` | Unique ID generation for calls and sessions |
| `google_fonts` | `^6.2.1` | Typography design system (Inter font family) |
| `shared_preferences` | `^2.3.2` | Local settings persistence |
| `flutter_local_notifications` | `^18.0.1` | System notification overlays for incoming call alerts |
| `cupertino_icons` | `^1.0.8` | iOS style icon assets |

---

## Architecture

ConnectCall follows a clean, **Layered Feature-First Architecture**:

```text
lib/
├── core/
│   ├── constants/       # SupabaseConfig and application constants
│   ├── errors/          # AppException human-readable error handling
│   ├── theme/           # Material 3 AppTheme and AppColors design tokens
│   └── utils/           # DateFormatter and formatting helpers
├── models/
│   ├── user_model.dart  # UserModel schema & JSON serialization
│   └── call_model.dart  # CallModel schema, CallStatus, CallType, CallDirection enums
├── repositories/
│   ├── auth_repository.dart  # Supabase Auth sign in, sign up, sign out
│   ├── user_repository.dart  # User profiles query, search, online status
│   └── call_repository.dart  # Call session persistence & history queries
├── services/
│   ├── calling_service.dart         # Abstract CallingService interface
│   ├── webrtc_calling_service.dart  # WebRTC peer connections & Supabase signaling
│   └── permission_service.dart      # Runtime camera and microphone permission handling
├── features/
│   ├── auth/            # AuthProvider, SplashScreen, LoginScreen, RegisterScreen
│   ├── contacts/        # UserListProvider, ContactsScreen
│   ├── profile/         # ProfileScreen
│   ├── calling/         # CallProvider, AudioCallScreen, VideoCallScreen, IncomingCallScreen
│   └── history/         # CallHistoryScreen
└── main.dart            # Application entrypoint & Riverpod ProviderScope setup
```

---

## Backend Used

- **Supabase Cloud**: Serves as the complete backend infrastructure.
  - **Supabase Auth**: Managed user authentication, session tokens, and password hashing.
  - **Supabase Database**: PostgreSQL relational database storing user profiles (`public.profiles`) and call logs (`public.call_sessions`).
  - **Row-Level Security (RLS)**: Enforces security policies so users can only view their own profile and access call history relevant to them.
  - **Supabase Realtime**: Broadcast channels and Postgres change subscriptions used for WebRTC SDP offer/answer/ICE candidate signaling and live user presence.

---

## Calling SDK Used

- **`flutter_webrtc` (WebRTC)**: Provides real-time peer-to-peer audio and video stream transmission using standard `RTCPeerConnection`, `MediaStream`, and `RTCVideoRenderer` objects.
- **Signaling**: WebRTC SDP (Session Description Protocol) offer/answer exchanges and ICE candidate trickling are transmitted over low-latency **Supabase Realtime Broadcast Channels**.
- **STUN Servers**: Uses Google public STUN servers (`stun:stun.l.google.com:19302`) for NAT traversal.

---

## Setup Instructions

### Prerequisites
- Flutter SDK (>= `3.13.2`) installed and configured
- Android SDK (API 34) & JDK 17 (for Android builds)
- Xcode (for iOS / macOS builds)
- Active Supabase Project with URL and Anon Key

### Installation Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Bhishamt/ConnectCall.git
   cd ConnectCall
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Database Configuration**:
   Execute the migration script [`supabase/migrations/01_schema.sql`](file:///d:/ConnectCall/supabase/migrations/01_schema.sql) in your Supabase SQL Editor to set up tables, RLS policies, and Realtime publications.

4. **Run Code Analysis & Tests**:
   ```bash
   flutter analyze
   flutter test
   ```

5. **Launch Application**:
   ```bash
   flutter run
   ```

6. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

---

## Environment Variables & Configuration

Build-time environment variables are configured using `--dart-define`:

- `SUPABASE_URL`: Your Supabase Project URL.
- `SUPABASE_ANON_KEY`: Your Supabase Anonymous Public Key.

**Example Command**:
```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

If not supplied at command line, default fallback values defined in `lib/core/constants/supabase_config.dart` are used.

---

## Known Limitations

1. **Camera/Microphone Hardware Requirement**: WebRTC media capture requires physical camera and microphone hardware or active emulator camera feed configuration.
2. **Symmetric NAT / Strict Firewalls**: Primary ICE candidate negotiation relies on Google STUN servers. Enterprise networks with strict symmetric NAT may require configured TURN relay servers (`turn:your-turn-server.com`).
3. **Background Notifications on iOS**: Background push notifications for calls when the app is completely terminated require APNs setup with Apple Developer certificates.

---

## AI Tools Used

In accordance with project development transparency:
- **Google Antigravity AI Coding Assistant**: Powered by **Gemini 3.6 Flash (Medium)**, used for architectural planning, Riverpod state machine verification, WebRTC signaling implementation, database migration validation, and project documentation.
