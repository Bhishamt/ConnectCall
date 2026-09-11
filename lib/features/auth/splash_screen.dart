import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Safety timeout: if auth state never resolves, go to Login after 10s
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      _navigateToLogin();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _navigateToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _navigateToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes — navigate once loading completes
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isLoading) {
        // Auth initialization has completed
        if (next.isAuthenticated) {
          _navigateToHome();
        } else {
          _navigateToLogin();
        }
      }
    });

    // Also check current state immediately (in case it's already resolved)
    final authState = ref.watch(authProvider);
    if (!authState.isLoading && !_navigated) {
      // Use post-frame callback to avoid navigation during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authState.isAuthenticated) {
          _navigateToHome();
        } else {
          _navigateToLogin();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_rounded,
                size: 72,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ConnectCall',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '1-to-1 Audio & Video Communication',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
