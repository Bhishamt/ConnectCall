import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ConnectionQualityLevel {
  excellent,
  good,
  fair,
  poor,
  unknown,
}

class CallDiagnosticsReport {
  final int rttMs;
  final double packetLossPercentage;
  final int jitterMs;
  final int bitrateKbps;
  final int frameWidth;
  final int frameHeight;
  final int fps;
  final ConnectionQualityLevel qualityLevel;
  final DateTime timestamp;

  CallDiagnosticsReport({
    required this.rttMs,
    required this.packetLossPercentage,
    required this.jitterMs,
    required this.bitrateKbps,
    required this.frameWidth,
    required this.frameHeight,
    required this.fps,
    required this.qualityLevel,
    required this.timestamp,
  });

  factory CallDiagnosticsReport.initial() {
    return CallDiagnosticsReport(
      rttMs: 0,
      packetLossPercentage: 0.0,
      jitterMs: 0,
      bitrateKbps: 0,
      frameWidth: 1280,
      frameHeight: 720,
      fps: 30,
      qualityLevel: ConnectionQualityLevel.unknown,
      timestamp: DateTime.now(),
    );
  }

  static ConnectionQualityLevel calculateQuality({
    required int rttMs,
    required double packetLoss,
  }) {
    if (rttMs == 0 && packetLoss == 0.0) return ConnectionQualityLevel.unknown;
    if (rttMs < 100 && packetLoss < 1.0) return ConnectionQualityLevel.excellent;
    if (rttMs < 200 && packetLoss < 3.0) return ConnectionQualityLevel.good;
    if (rttMs < 350 && packetLoss < 7.0) return ConnectionQualityLevel.fair;
    return ConnectionQualityLevel.poor;
  }
}

/// WebRTC PeerConnection statistics collector and network health diagnostic service.
class CallDiagnosticsService {
  Timer? _pollingTimer;
  final StreamController<CallDiagnosticsReport> _diagnosticsController =
      StreamController<CallDiagnosticsReport>.broadcast();

  int _lastBytesReceived = 0;
  DateTime? _lastPollTime;

  Stream<CallDiagnosticsReport> get diagnosticsStream =>
      _diagnosticsController.stream;

  /// Start monitoring peer connection stats at a specified interval.
  void startMonitoring(RTCPeerConnection? peerConnection, {Duration interval = const Duration(seconds: 2)}) {
    stopMonitoring();
    if (peerConnection == null) return;

    _pollingTimer = Timer.periodic(interval, (_) async {
      final report = await pollPeerConnectionStats(peerConnection);
      if (!_diagnosticsController.isClosed) {
        _diagnosticsController.add(report);
      }
    });
  }

  /// Poll current WebRTC statistics report from the peer connection.
  Future<CallDiagnosticsReport> pollPeerConnectionStats(RTCPeerConnection peerConnection) async {
    try {
      final stats = await peerConnection.getStats();
      int rtt = 45;
      double packetLoss = 0.2;
      int jitter = 12;
      int bytesReceived = 0;
      int width = 1280;
      int height = 720;
      int fps = 30;

      for (var stat in stats) {
        final type = stat.type;
        final values = stat.values;

        if (type == 'candidate-pair' && values['state'] == 'succeeded') {
          if (values['currentRoundTripTime'] != null) {
            rtt = ((double.tryParse(values['currentRoundTripTime'].toString()) ?? 0.045) * 1000).round();
          }
        }

        if (type == 'inbound-rtp') {
          if (values['packetsLost'] != null && values['packetsReceived'] != null) {
            final lost = double.tryParse(values['packetsLost'].toString()) ?? 0;
            final rec = double.tryParse(values['packetsReceived'].toString()) ?? 1;
            packetLoss = (lost / (lost + rec)) * 100;
          }
          if (values['jitter'] != null) {
            jitter = ((double.tryParse(values['jitter'].toString()) ?? 0.012) * 1000).round();
          }
          if (values['bytesReceived'] != null) {
            bytesReceived = int.tryParse(values['bytesReceived'].toString()) ?? 0;
          }
          if (values['frameWidth'] != null) {
            width = int.tryParse(values['frameWidth'].toString()) ?? 1280;
          }
          if (values['frameHeight'] != null) {
            height = int.tryParse(values['frameHeight'].toString()) ?? 720;
          }
          if (values['framesPerSecond'] != null) {
            fps = int.tryParse(values['framesPerSecond'].toString()) ?? 30;
          }
        }
      }

      final now = DateTime.now();
      int bitrateKbps = 0;
      if (_lastPollTime != null && _lastBytesReceived > 0 && bytesReceived > _lastBytesReceived) {
        final durationSeconds = now.difference(_lastPollTime!).inMilliseconds / 1000.0;
        if (durationSeconds > 0) {
          bitrateKbps = (((bytesReceived - _lastBytesReceived) * 8) / (durationSeconds * 1024)).round();
        }
      } else {
        bitrateKbps = 1500;
      }

      _lastBytesReceived = bytesReceived;
      _lastPollTime = now;

      final quality = CallDiagnosticsReport.calculateQuality(
        rttMs: rtt,
        packetLoss: packetLoss,
      );

      return CallDiagnosticsReport(
        rttMs: rtt,
        packetLossPercentage: double.parse(packetLoss.toStringAsFixed(1)),
        jitterMs: jitter,
        bitrateKbps: bitrateKbps,
        frameWidth: width,
        frameHeight: height,
        fps: fps,
        qualityLevel: quality,
        timestamp: now,
      );
    } catch (_) {
      return CallDiagnosticsReport.initial();
    }
  }

  /// Stop polling active connection statistics.
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastBytesReceived = 0;
    _lastPollTime = null;
  }

  void dispose() {
    stopMonitoring();
    _diagnosticsController.close();
  }
}
