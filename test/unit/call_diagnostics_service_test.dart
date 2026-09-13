import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/services/call_diagnostics_service.dart';

void main() {
  group('CallDiagnosticsService & Quality Level Tests', () {
    test('calculateQuality returns correct levels based on latency and packet loss', () {
      expect(
        CallDiagnosticsReport.calculateQuality(rttMs: 40, packetLoss: 0.1),
        equals(ConnectionQualityLevel.excellent),
      );

      expect(
        CallDiagnosticsReport.calculateQuality(rttMs: 140, packetLoss: 2.0),
        equals(ConnectionQualityLevel.good),
      );

      expect(
        CallDiagnosticsReport.calculateQuality(rttMs: 250, packetLoss: 5.0),
        equals(ConnectionQualityLevel.fair),
      );

      expect(
        CallDiagnosticsReport.calculateQuality(rttMs: 400, packetLoss: 12.0),
        equals(ConnectionQualityLevel.poor),
      );

      expect(
        CallDiagnosticsReport.calculateQuality(rttMs: 0, packetLoss: 0.0),
        equals(ConnectionQualityLevel.unknown),
      );
    });

    test('CallDiagnosticsReport initial factory creates valid defaults', () {
      final report = CallDiagnosticsReport.initial();

      expect(report.rttMs, equals(0));
      expect(report.packetLossPercentage, equals(0.0));
      expect(report.qualityLevel, equals(ConnectionQualityLevel.unknown));
      expect(report.fps, equals(30));
    });
  });
}
