# ConnectCall Architecture Decisions

## Decision 1: Database-Authoritative Call Locking (`start_call_atomic`)
- **Context**: Local Flutter state checks cannot prevent simultaneous call race conditions when two users call each other at the exact same millisecond.
- **Decision**: Implemented PostgreSQL `start_call_atomic` RPC function in `supabase/migrations/04_atomic_call_rpc.sql`.
- **Mechanism**: Acquires sorted row locks (`FOR UPDATE`) on profile UUIDs, checks if either user is in active call states (`calling`, `ringing`, `connecting`, `connected`, `inCall`), inserts session atomically, and returns `'SUCCESS'`, `'BUSY'`, or `'ALREADY_IN_CALL'`.

## Decision 2: Symmetrical WebRTC Track Binding
- **Context**: In WebRTC Unified-Plan, audio and video tracks arrive via separate `onTrack` events. Assigning renderer `srcObject` before the video track arrives left remote video blank on one side.
- **Decision**: Explicitly re-bind `_remoteRenderer.srcObject = _remoteStream` whenever a video track arrives or is added to `_remoteStream`.

## Decision 3: Recoverable Active Call Navigation (`PopScope` + Active Call Banner)
- **Context**: Pressing Android Back button on call screen popped route and orphaned active calls without controls.
- **Decision**: Intercept back button with `PopScope(canPop: false)` to minimize call to `HomeScreen`. Display an **Active Call Banner** on `HomeScreen` and show an ongoing notification to return to full-screen call controls.

## Decision 4: Ringtone Audio Feedback (`RingtoneService`)
- **Context**: Callers and receivers lacked audible feedback while calling or ringing.
- **Decision**: Created `RingtoneService` to play periodic outgoing ringing chimes and incoming ringtone alerts, stopping immediately on call connect, reject, end, or timeout.
