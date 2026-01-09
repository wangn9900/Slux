import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme State ---
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('themeMode');
    if (modeStr == 'light')
      state = ThemeMode.light;
    else if (modeStr == 'dark')
      state = ThemeMode.dark;
    else
      state = ThemeMode.system;
  }

  void setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('themeMode', modeStr);
  }
}

// --- Language State ---
final languageProvider = StateNotifierProvider<LanguageNotifier, Locale?>((
  ref,
) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<Locale?> {
  LanguageNotifier() : super(null) {
    // null = System
    _loadLang();
  }

  void _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('languageCode');
    if (langCode != null) {
      state = Locale(langCode);
    }
  }

  void setLanguage(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('languageCode');
    } else {
      await prefs.setString('languageCode', locale.languageCode);
    }
  }
}
