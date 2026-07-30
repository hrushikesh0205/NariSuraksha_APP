import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserProvider
// ─────────────────────────────────────────────────────────────────────────────

/// State container for the currently authenticated user.
///
/// Consumed by the Dashboard header to show the user's name and avatar.
///
/// Lifecycle:
/// 1. Created once by [MultiProvider] at app root.
/// 2. [loadUser] is called by [DashboardProvider.initialize].
/// 3. UI rebuilds only the consuming widgets via [Consumer<UserProvider>].
class UserProvider extends ChangeNotifier {
  UserProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  // ── State ──────────────────────────────────────────────────────────────────

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasUser => _user != null;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Fetches the current user from Firestore / Firebase Auth.
  ///
  /// Safe to call multiple times — won't re-fetch if already loaded.
  Future<void> loadUser({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_user != null && !forceRefresh) return;

    _setLoading(true);
    _clearError();

    try {
      final model = await _authService.fetchCurrentUserModel();
      _user = model;
    } catch (e) {
      _errorMessage = _friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Refreshes the user model from remote.
  Future<void> refresh() => loadUser(forceRefresh: true);

  /// Updates a field locally and optionally syncs to Firestore.
  void updateLocalUser(UserModel updated) {
    _user = updated;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'No internet connection. Showing cached data.';
    }
    if (msg.contains('permission')) {
      return 'Permission denied. Please check your account.';
    }
    return 'Could not load profile. Please try again.';
  }
}
