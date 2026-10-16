import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riverpod provider exposing the initialized [SharedPreferences] instance.
///
/// Overridden in `main.dart` and widget tests with the concrete instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

/// Service managing lightweight persistent user preferences.
class PreferencesService {
  const PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  /// Whether the user has completed the initial onboarding flow.
  bool get isOnboardingCompleted =>
      _prefs.getBool(AppConstants.prefOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(AppConstants.prefOnboardingCompleted, completed);
  }

  /// Reads the saved [ThemeMode] (`system`, `light`, or `dark`).
  ThemeMode get themeMode {
    final raw = _prefs.getString(AppConstants.prefThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(AppConstants.prefThemeMode, value);
  }

  /// Whether the document list defaults to a Grid layout (`true`) or List (`false`).
  bool get isGridView => _prefs.getBool(AppConstants.prefIsGridView) ?? true;

  Future<void> setIsGridView(bool isGrid) async {
    await _prefs.setBool(AppConstants.prefIsGridView, isGrid);
  }

  /// Saved document sort field (`date`, `name`, `size`).
  String get sortOption =>
      _prefs.getString(AppConstants.prefSortOption) ?? 'date';

  Future<void> setSortOption(String option) async {
    await _prefs.setString(AppConstants.prefSortOption, option);
  }

  /// Saved sort direction (`true` for ascending, `false` for descending).
  bool get sortAscending =>
      _prefs.getBool(AppConstants.prefSortAscending) ?? false;

  Future<void> setSortAscending(bool ascending) async {
    await _prefs.setBool(AppConstants.prefSortAscending, ascending);
  }
}

/// Riverpod provider for [PreferencesService].
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

