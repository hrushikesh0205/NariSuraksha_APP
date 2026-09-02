import 'package:flutter/material.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Manages dynamic application preferences and user settings.
///
/// Handles:
/// - Theme mode (System default, Light, Dark)
/// - Push notification preferences
/// - Live location sharing preferences
/// - Biometric lock setting
/// - App language preference
///
/// Automatically syncs with the authenticated user's Firestore document
/// (`users/{uid}/settings`) so preferences persist across app sessions.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({UserRepository? userRepository})
      : _userRepo = userRepository ?? UserRepository();

  final UserRepository _userRepo;

  // ── State ───────────────────────────────────────────────────────────────────

  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _voiceSosEnabled = true;
  bool _biometricEnabled = false;
  String _language = 'English (India)';

  // ── Getters ─────────────────────────────────────────────────────────────────

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationSharingEnabled => _locationSharingEnabled;
  bool get voiceSosEnabled => _voiceSosEnabled;
  bool get biometricEnabled => _biometricEnabled;
  String get language => _language;

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'System default';
    }
  }

  // ── Initialize from UserModel ───────────────────────────────────────────────

  /// Populates settings from the given [UserModel] when loaded.
  void initFromUser(UserModel? user) {
    if (user == null || user.settings.isEmpty) return;

    final s = user.settings;

    if (s.containsKey('themeMode')) {
      final modeStr = s['themeMode'] as String?;
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    }

    if (s.containsKey('notifications')) {
      _notificationsEnabled = s['notifications'] as bool? ?? true;
    }

    if (s.containsKey('locationSharing')) {
      _locationSharingEnabled = s['locationSharing'] as bool? ?? true;
    }

    if (s.containsKey('voiceSos')) {
      _voiceSosEnabled = s['voiceSos'] as bool? ?? true;
    }

    if (s.containsKey('biometric')) {
      _biometricEnabled = s['biometric'] as bool? ?? false;
    }

    if (s.containsKey('language')) {
      _language = (s['language'] as String?) ?? 'English (India)';
    }

    notifyListeners();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  /// Updates the application theme mode.
  Future<void> setThemeMode(ThemeMode mode, {String? uid}) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _syncSettings(uid);
  }

  /// Toggles notifications on or off.
  Future<void> setNotificationsEnabled(bool enabled, {String? uid}) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    await _syncSettings(uid);
  }

  /// Toggles location sharing preference.
  Future<void> setLocationSharingEnabled(bool enabled, {String? uid}) async {
    _locationSharingEnabled = enabled;
    notifyListeners();
    await _syncSettings(uid);
  }

  /// Toggles Voice SOS keyword detection preference.
  Future<void> setVoiceSosEnabled(bool enabled, {String? uid}) async {
    _voiceSosEnabled = enabled;
    notifyListeners();
    await _syncSettings(uid);
  }

  /// Toggles biometric lock.
  Future<void> setBiometricEnabled(bool enabled, {String? uid}) async {
    _biometricEnabled = enabled;
    notifyListeners();
    await _syncSettings(uid);
  }

  /// Sets preferred language.
  Future<void> setLanguage(String lang, {String? uid}) async {
    _language = lang;
    notifyListeners();
    await _syncSettings(uid);
  }

  // ── Sync to Firestore ───────────────────────────────────────────────────────

  Future<void> _syncSettings(String? uid) async {
    if (uid == null || uid.isEmpty) return;

    try {
      final themeStr = _themeMode == ThemeMode.light
          ? 'light'
          : (_themeMode == ThemeMode.dark ? 'dark' : 'system');

      await _userRepo.updateUser(uid, {
        'settings': {
          'themeMode': themeStr,
          'notifications': _notificationsEnabled,
          'locationSharing': _locationSharingEnabled,
          'voiceSos': _voiceSosEnabled,
          'biometric': _biometricEnabled,
          'language': _language,
        },
      });
    } catch (e) {
      debugPrint('⚠️ SettingsProvider: Firestore settings sync failed: $e');
    }
  }
}
