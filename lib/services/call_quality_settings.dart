enum VideoQualityPreset {
  auto,
  low, // 240p, 15fps, 250 kbps
  medium, // 480p, 24fps, 750 kbps
  hd, // 720p, 30fps, 2000 kbps
}

class VideoQualityConfig {
  final VideoQualityPreset preset;
  final int maxBitrateKbps;
  final int targetWidth;
  final int targetHeight;
  final int targetFps;

  const VideoQualityConfig({
    required this.preset,
    required this.maxBitrateKbps,
    required this.targetWidth,
    required this.targetHeight,
    required this.targetFps,
  });

  factory VideoQualityConfig.fromPreset(VideoQualityPreset preset) {
    switch (preset) {
      case VideoQualityPreset.low:
        return const VideoQualityConfig(
          preset: VideoQualityPreset.low,
          maxBitrateKbps: 250,
          targetWidth: 426,
          targetHeight: 240,
          targetFps: 15,
        );
      case VideoQualityPreset.medium:
        return const VideoQualityConfig(
          preset: VideoQualityPreset.medium,
          maxBitrateKbps: 750,
          targetWidth: 854,
          targetHeight: 480,
          targetFps: 24,
        );
      case VideoQualityPreset.hd:
        return const VideoQualityConfig(
          preset: VideoQualityPreset.hd,
          maxBitrateKbps: 2000,
          targetWidth: 1280,
          targetHeight: 720,
          targetFps: 30,
        );
      case VideoQualityPreset.auto:
      default:
        return const VideoQualityConfig(
          preset: VideoQualityPreset.auto,
          maxBitrateKbps: 1200,
          targetWidth: 640,
          targetHeight: 480,
          targetFps: 30,
        );
    }
  }

  Map<String, dynamic> toMediaConstraints() {
    return {
      'mandatory': {
        'minWidth': '${targetWidth ~/ 2}',
        'maxWidth': '$targetWidth',
        'minHeight': '${targetHeight ~/ 2}',
        'maxHeight': '$targetHeight',
        'minFrameRate': '10',
        'maxFrameRate': '$targetFps',
      },
      'optional': [],
    };
  }

  String get displayName {
    switch (preset) {
      case VideoQualityPreset.low:
        return 'Data Saver (240p)';
      case VideoQualityPreset.medium:
        return 'Standard (480p)';
      case VideoQualityPreset.hd:
        return 'High Definition (720p)';
      case VideoQualityPreset.auto:
      default:
        return 'Auto (Adaptive)';
    }
  }
}
