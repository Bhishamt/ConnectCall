import 'package:permission_handler/permission_handler.dart';

import '../core/errors/app_exception.dart';

class PermissionService {
  Future<bool> requestAudioPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      throw AppException(
        'Microphone permission is permanently denied. Please enable it in system settings.',
        'permission_permanently_denied',
      );
    } else {
      throw AppException(
        'Microphone permission is required to make audio calls.',
        'permission_denied',
      );
    }
  }

  Future<bool> requestVideoPermissions() async {
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (micStatus.isGranted && camStatus.isGranted) {
      return true;
    }

    if (micStatus.isPermanentlyDenied || camStatus.isPermanentlyDenied) {
      throw AppException(
        'Camera and Microphone permissions are permanently denied. Please enable them in system settings.',
        'permission_permanently_denied',
      );
    }

    throw AppException(
      'Camera and Microphone permissions are required to make video calls.',
      'permission_denied',
    );
  }

  Future<void> openAppSettingsMenu() async {
    await openAppSettings();
  }
}
