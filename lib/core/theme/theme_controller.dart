import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static final _key = 'theme_mode';
  static final ValueNotifier<String> mode = ValueNotifier('system');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    mode.value = (saved == 'light' || saved == 'dark') ? saved! : 'system';
  }

  static ThemeMode get themeMode => switch (mode.value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static bool effectiveIsLight(Brightness platformBrightness) =>
      switch (mode.value) {
        'light' => true,
        'dark' => false,
        _ => platformBrightness == Brightness.light,
      };

  static Future<void> setMode(String value) async {
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }
}
