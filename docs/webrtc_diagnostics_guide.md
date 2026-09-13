# WebRTC Diagnostics & Signaling Flow Guide

This document outlines the real-time peer-to-peer WebRTC architecture, signaling state machine, audio/video stream routing, and network quality monitoring built into ConnectCall.

---

## 1. WebRTC Peer Connection Lifecycle

ConnectCall uses **Supabase Realtime Broadcast** channels for peer-to-peer signaling negotiation (Offer / Answer / ICE Candidates).

```
   Caller                               Supabase Realtime                             Callee
     │                                        │                                         │
     │ ──── 1. Send Offer (SDP) ────────────> │ ──────────── Broadcast Offer ─────────> │
     │                                        │                                         │
     │ <─── 3. Receive Answer (SDP) ───────── │ <─────────── 2. Send Answer (SDP) ───── │
     │                                        │                                         │
     │ ──── 4. Trickle ICE Candidates ──────> │ ──────────── Broadcast Candidate ─────> │
     │ <─── 5. Receive ICE Candidates ─────── │ <─────────── Send ICE Candidates ────── │
     │                                        │                                         │
     ▼                                        ▼                                         ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        Direct P2P Media Stream Connected (SRTP)                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Network Quality Metrics & Diagnostics

The `CallDiagnosticsService` regularly queries WebRTC statistics via `RTCPeerConnection.getStats()` every 2 seconds during active voice and video calls.

### Quality Levels Classification

| Quality Level | RTT (Latency) | Packet Loss | Target Resolution | Recommended Bitrate |
| :--- | :--- | :--- | :--- | :--- |
| **EXCELLENT** | $< 100\text{ ms}$ | $< 1.0\%$ | $1280 \times 720$ (720p @ 30fps) | $1500 - 2500\text{ kbps}$ |
| **GOOD** | $< 200\text{ ms}$ | $< 3.0\%$ | $1280 \times 720$ (720p @ 24fps) | $1000 - 1500\text{ kbps}$ |
| **FAIR** | $< 350\text{ ms}$ | $< 7.0\%$ | $640 \times 480$ (480p @ 15fps) | $400 - 800\text{ kbps}$ |
| **POOR** | $> 350\text{ ms}$ | $> 7.0\%$ | Audio Priority / Low Res | $< 300\text{ kbps}$ |

---

## 3. WebRTC Audio & Video Pipeline

### Symmetric Video Mirroring
- **Local Self-View**: Hardware acceleration with horizontal mirror mode (`mirror: true`) for intuitive front-camera preview.
- **Remote View**: Standard rendering (`mirror: false`) preserving incoming aspect ratio and orientation.

### Hardware Audio Session Routing
- Configured via `audio_session` package with category `playAndRecord` and mode `voiceChat`.
- Dynamic speakerphone toggling between earpiece/builtin speakers and Bluetooth Headsets.

---

## 4. UI Overlay Integration

The `CallQualityIndicator` widget is positioned in the upper region of `AudioCallScreen` and `VideoCallScreen`.
Tapping the live quality badge presents an interactive diagnostic sheet displaying:
1. **Round Trip Latency (RTT)** in milliseconds.
2. **Packet Loss percentage**.
3. **Jitter buffer depth**.
4. **Active streaming resolution & FPS**.
5. **Estimated bandwidth bitrate** in kbps.
