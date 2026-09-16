import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/services/call_quality_settings.dart';

void main() {
  group('VideoQualityConfig & VideoQualityPreset Tests', () {
    test('Low preset calculates data saver parameters', () {
      final config = VideoQualityConfig.fromPreset(VideoQualityPreset.low);
      expect(config.maxBitrateKbps, equals(250));
      expect(config.targetHeight, equals(240));
      expect(config.targetFps, equals(15));
      expect(config.displayName, contains('Data Saver'));
    });

    test('Medium preset calculates standard parameters', () {
      final config = VideoQualityConfig.fromPreset(VideoQualityPreset.medium);
      expect(config.maxBitrateKbps, equals(750));
      expect(config.targetHeight, equals(480));
      expect(config.targetFps, equals(24));
      expect(config.displayName, contains('Standard'));
    });

    test('HD preset calculates 720p 30fps parameters', () {
      final config = VideoQualityConfig.fromPreset(VideoQualityPreset.hd);
      expect(config.maxBitrateKbps, equals(2000));
      expect(config.targetHeight, equals(720));
      expect(config.targetFps, equals(30));
      expect(config.displayName, contains('High Definition'));
    });

    test('Constraints dictionary outputs valid min/max width and height strings', () {
      final config = VideoQualityConfig.fromPreset(VideoQualityPreset.hd);
      final constraints = config.toMediaConstraints();
      final mandatory = constraints['mandatory'] as Map<String, dynamic>;

      expect(mandatory['maxWidth'], equals('1280'));
      expect(mandatory['maxHeight'], equals('720'));
      expect(mandatory['maxFrameRate'], equals('30'));
    });
  });
}
