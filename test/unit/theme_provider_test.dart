import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/core/theme/app_theme.dart';
import 'package:connectcall/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme & ThemeModeNotifier Tests', () {
    testWidgets('AppTheme lightTheme and darkTheme provide distinct brightness', (WidgetTester tester) async {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, equals(Brightness.light));
      expect(dark.brightness, equals(Brightness.dark));
      expect(light.scaffoldBackgroundColor, isNot(equals(dark.scaffoldBackgroundColor)));
    });

    test('ThemeModeNotifier initializes with default dark mode', () {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, equals(ThemeMode.dark));
    });

    test('ThemeModeNotifier toggleTheme switches between dark and light', () async {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, equals(ThemeMode.dark));

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.light));

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.dark));
    });

    test('ThemeModeNotifier setThemeMode sets explicit mode', () async {
      final notifier = ThemeModeNotifier();
      await notifier.setThemeMode(ThemeMode.system);
      expect(notifier.state, equals(ThemeMode.system));
    });
  });
}
