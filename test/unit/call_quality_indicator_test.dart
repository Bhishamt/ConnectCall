import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/features/calling/widgets/call_quality_indicator.dart';
import 'package:connectcall/services/call_diagnostics_service.dart';

void main() {
  testWidgets('CallQualityIndicator displays quality label and open modal on tap', (WidgetTester tester) async {
    final report = CallDiagnosticsReport(
      rttMs: 45,
      packetLossPercentage: 0.2,
      jitterMs: 10,
      bitrateKbps: 1800,
      frameWidth: 1280,
      frameHeight: 720,
      fps: 30,
      qualityLevel: ConnectionQualityLevel.excellent,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CallQualityIndicator(report: report),
          ),
        ),
      ),
    );

    expect(find.text('HD • 45ms'), findsOneWidget);

    await tester.tap(find.byType(CallQualityIndicator));
    await tester.pumpAndSettle();

    expect(find.text('Network & Call Diagnostics'), findsOneWidget);
    expect(find.text('EXCELLENT'), findsOneWidget);
    expect(find.text('45 ms'), findsOneWidget);
  });
}
