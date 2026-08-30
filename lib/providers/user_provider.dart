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
      : _authService = authService ?? AuthService() {
    _initFromAuth();
  }

  final AuthService _authService;

  // ── State ──────────────────────────────────────────────────────────────────

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get currentUid => _user?.uid ?? _authService.firebaseUser?.uid;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasUser => _user != null || _authService.firebaseUser != null;

  void _initFromAuth() {
    final fbUser = _authService.firebaseUser;
    if (fbUser != null && _user == null) {
      _user = UserModel(
        uid: fbUser.uid,
        name: fbUser.displayName?.isNotEmpty == true
            ? fbUser.displayName!
            : (fbUser.email?.split('@').first ?? 'User'),
        email: fbUser.email ?? '',
        photoUrl: fbUser.photoURL,
      );
    }
  }

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

  /// Clears the user state, typically called during logout.
  void clearUser() {
    _user = null;
    _errorMessage = null;
    _isLoading = false;
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
