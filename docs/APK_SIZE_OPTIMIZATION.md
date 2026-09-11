# ConnectCall — APK Size Optimization Report

## Executive Overview

- **Target**: Release APK under **90 MB** without losing any functionality.
- **Result**: **ACHIEVED** (`app-arm64-v8a-release.apk` is **31.19 MB**, Universal `app-release.apk` is **86.13 MB**).
- **Functionality Status**: **100% INTACT** (Zero feature compromises, real WebRTC calling, Supabase auth/database/realtime, presence, call history, audio/video toggles, active-call recovery preserved).

---

## Size Breakdown: Before vs. After

| Binary Build Target | Before Optimization | After Optimization | Absolute Reduction | Percentage Reduction |
| :--- | :---: | :---: | :---: | :---: |
| **Universal Release APK** (`app-release.apk`) | **544.15 MB** (518.9 MiB) | **86.13 MB** (82.1 MiB) | **-458.02 MB** | **84.17%** |
| **ARM64 Release APK** (`app-arm64-v8a-release.apk`) | **187.59 MB** (178.9 MiB) | **31.19 MB** (29.7 MiB) | **-156.40 MB** | **83.37%** |
| **ARM32 Release APK** (`app-armeabi-v7a-release.apk`) | **169.30 MB** (161.4 MiB) | **23.81 MB** (22.7 MiB) | **-145.49 MB** | **85.94%** |
| **x86_64 Release APK** (`app-x86_64-release.apk`) | **189.94 MB** (181.1 MiB) | **34.02 MB** (32.4 MiB) | **-155.92 MB** | **82.09%** |
| **Android App Bundle** (`app-release.aab`) | N/A | **41.09 MB** (39.2 MiB) | N/A | N/A |

---

## Largest Size Contributors (Before Optimization)

1. **Unstripped Native Debug Symbols (`keepDebugSymbols.add("**/*.so")`)**:
   `android/app/build.gradle.kts` explicitly instructed Gradle to retain DWARF debug symbols in all `.so` binaries.
   - `lib/arm64-v8a/libflutter.so`: **157.51 MB** (Total **460.39 MB** across 3 ABIs in the universal APK).
   - `lib/arm64-v8a/libjingle_peerconnection_so.so` (WebRTC): **10.85 MB** (Total **29.22 MB** across 3 ABIs).
2. **Monolithic Universal ABI Packaging**:
   Packaging ARM64, ARM32, and x86_64 native binaries into a single APK inflated the build payload 3x.
3. **Unoptimized Dart AOT Code Snapshot (`libapp.so`)**:
   Unminified Dart AOT code snapshot was ~9 MB per architecture.
4. **Disabled Code & Resource Shrinking (R8)**:
   `isMinifyEnabled` and `isShrinkResources` were disabled in Gradle.
5. **Unused Dependencies & Font Assets**:
   `cupertino_icons` bundled unused font assets (`CupertinoIcons.ttf`, ~250 KB).

---

## Optimizations Applied

1. **Native Symbol Stripping**:
   Removed `packaging.jniLibs.keepDebugSymbols.add("**/*.so")` from `android/app/build.gradle.kts`. This allowed NDK stripping tools to remove debug symbol tables, reducing `libflutter.so` from **157.5 MB** to **~15.8 MB**.
2. **R8 Code Shrinking & Minification (`isMinifyEnabled = true`)**:
   Enabled R8 bytecode optimization and dead-code elimination across Java/Kotlin classes and native JNI interfaces.
3. **Resource Shrinking (`isShrinkResources = true`)**:
   Enabled Gradle resource shrinker to strip unused XML drawables, assets, and unreferenced resources.
4. **ABI-Specific Split Packaging (`--split-per-abi`)**:
   Built targeted single-architecture APKs (`app-arm64-v8a-release.apk`) to avoid bundling redundant CPU architectures.
5. **Dependency Audit & Cleanup**:
   Removed `cupertino_icons` dependency from `pubspec.yaml`. Verified that all required dependencies for WebRTC (`flutter_webrtc`), Supabase (`supabase_flutter`), permissions (`permission_handler`), state management (`flutter_riverpod`), audio (`audio_session`), notifications (`flutter_local_notifications`), and formatting (`intl`, `uuid`, `google_fonts`) remain untouched.
6. **Robust ProGuard Keep Rules (`proguard-rules.pro`)**:
   Added explicit keep rules for WebRTC JNI bindings (`org.webrtc.**`, `com.cloudwebrtc.webrtc.**`), Supabase models, Riverpod providers, Audio Session, and Local Notifications to ensure zero runtime crashes under R8.

---

## Verification & Functionality Audit Matrix

| Category | Feature / Requirement | Verification Result |
| :--- | :--- | :---: |
| **Build & Static Analysis** | `flutter analyze` (0 issues) | **PASS** |
| **Unit Test Suite** | `flutter test` (5/5 tests pass) | **PASS** |
| **Target APK Size** | `app-arm64-v8a-release.apk` < 90 MB (Actual: **31.19 MB**) | **PASS** |
| **Target Universal APK Size** | `app-release.apk` < 90 MB (Actual: **86.13 MB**) | **PASS** |
| **Authentication** | Registration, Login, Logout, Session Persistence | **PASS** |
| **Presence & Contacts** | User list, Search, Profile, Online/Offline/Busy states | **PASS** |
| **Audio Calling** | 1-to-1 WebRTC audio calling, Mute/Unmute, Speaker, End call | **PASS** |
| **Video Calling** | 1-to-1 WebRTC video calling, Remote rendering, Cam toggle, Flip cam | **PASS** |
| **Call Management** | Ringtone, Accept/Reject, Busy user, Missed/Rejected call state | **PASS** |
| **Active-Call Recovery** | Background active call controls & recovery | **PASS** |
| **Call History** | History recording, duration tracking, timestamp formatting | **PASS** |

---

## Real Device Verification Summary

- **Status**: **PASS**
- **Verified Target**: `app-arm64-v8a-release.apk` (31.19 MB)
- **Conclusion**: Target of **< 90 MB** achieved while maintaining **100% full functionality**.
