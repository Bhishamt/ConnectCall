# ConnectCall Known Limitations

1. **Hardware Camera / Microphone Dependency**: Real WebRTC audio and video stream transmission requires physical camera and microphone hardware or active emulator camera feed configuration.
2. **Symmetric NAT & Enterprise Firewalls**: Primary WebRTC ICE negotiation uses Google public STUN servers (`stun:stun.l.google.com:19302`). Strict symmetric NAT or enterprise firewalls require TURN relay server configuration.
3. **Terminated State Call Alerts**: Local notifications handle incoming calls when the app is in foreground or background. If the app process is force-stopped/terminated, APNs/FCM push infrastructure is required for incoming call wake-up.
