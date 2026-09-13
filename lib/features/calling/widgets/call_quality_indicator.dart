import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/call_diagnostics_service.dart';

class CallQualityIndicator extends StatelessWidget {
  final CallDiagnosticsReport report;

  const CallQualityIndicator({
    super.key,
    required this.report,
  });

  Color _getQualityColor() {
    switch (report.qualityLevel) {
      case ConnectionQualityLevel.excellent:
      case ConnectionQualityLevel.good:
        return AppColors.onlineGreen;
      case ConnectionQualityLevel.fair:
        return Colors.orangeAccent;
      case ConnectionQualityLevel.poor:
        return AppColors.callRed;
      case ConnectionQualityLevel.unknown:
        return AppColors.textMuted;
    }
  }

  String _getQualityLabel() {
    switch (report.qualityLevel) {
      case ConnectionQualityLevel.excellent:
        return 'HD • ${report.rttMs}ms';
      case ConnectionQualityLevel.good:
        return 'Good • ${report.rttMs}ms';
      case ConnectionQualityLevel.fair:
        return 'Fair • ${report.rttMs}ms';
      case ConnectionQualityLevel.poor:
        return 'Poor Connection';
      case ConnectionQualityLevel.unknown:
        return 'Connecting...';
    }
  }

  IconData _getQualityIcon() {
    switch (report.qualityLevel) {
      case ConnectionQualityLevel.excellent:
      case ConnectionQualityLevel.good:
        return Icons.signal_cellular_alt_rounded;
      case ConnectionQualityLevel.fair:
        return Icons.signal_cellular_alt_2_bar_rounded;
      case ConnectionQualityLevel.poor:
        return Icons.signal_cellular_connected_no_internet_0_bar_rounded;
      case ConnectionQualityLevel.unknown:
        return Icons.wifi_find_rounded;
    }
  }

  void _showDiagnosticsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final color = _getQualityColor();
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getQualityIcon(), color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Network & Call Diagnostics',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.qualityLevel.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.surfaceLight),
              const SizedBox(height: 12),
              _buildDiagRow('Round Trip Latency (RTT)', '${report.rttMs} ms'),
              _buildDiagRow(
                'Packet Loss',
                '${report.packetLossPercentage.toStringAsFixed(1)}%',
              ),
              _buildDiagRow('Jitter Buffer', '${report.jitterMs} ms'),
              _buildDiagRow('Estimated Bitrate', '${report.bitrateKbps} kbps'),
              _buildDiagRow(
                'Stream Resolution',
                '${report.frameWidth} x ${report.frameHeight} @ ${report.fps} fps',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor();

    return GestureDetector(
      onTap: () => _showDiagnosticsModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getQualityIcon(),
              color: color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _getQualityLabel(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
