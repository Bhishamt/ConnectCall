class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;

  factory AppException.fromException(dynamic error) {
    if (error is AppException) return error;
    final str = error.toString().toLowerCase();

    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('offline')) {
      return AppException(
        'No internet connection. Please check your network.',
        'network_error',
      );
    }
    if (str.contains('invalid login credentials') ||
        str.contains('invalid_credentials')) {
      return AppException(
        'Invalid email or password. Please try again.',
        'invalid_credentials',
      );
    }
    if (str.contains('user already registered') ||
        str.contains('already exists')) {
      return AppException(
        'An account with this email already exists.',
        'user_exists',
      );
    }
    if (str.contains('permission denied') ||
        str.contains('permanently denied')) {
      return AppException(
        'Camera/Microphone permission denied. Enable it in settings.',
        'permission_denied',
      );
    }
    return AppException(
      error.toString().replaceAll('Exception: ', ''),
      'unknown_error',
    );
  }
}
