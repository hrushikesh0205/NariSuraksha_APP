import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Handles all profile edit operations (basic info, medical info, and account security).
///
/// Works in concert with [UserProvider] — call [UserProvider.refresh()] after
/// a successful save to refresh the displayed user data.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    UserRepository? userRepository,
    ActivityRepository? activityRepository,
    AuthService? authService,
  })  : _userRepo = userRepository ?? UserRepository(),
        _activityRepo = activityRepository ?? ActivityRepository(),
        _authService = authService;

  final UserRepository _userRepo;
  final ActivityRepository _activityRepo;
  AuthService? _authService;

  AuthService get authService => _authService ??= AuthService();

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // ── Update Basic Info (Name & Phone only) ───────────────────────────────────

  /// Updates name and phone in Firestore.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> updateBasicInfo({
    required UserModel current,
    required String name,
    required String phone,
  }) async {
    if (name.trim().isEmpty) return 'Name cannot be empty.';

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = current.copyWith(
        name: name.trim(),
        phone: phone.trim().isEmpty ? null : phone.trim(),
      );
      await _userRepo.updateUser(updated.uid, updated.toMap());
      await _activityRepo.logActivity(
        uid: current.uid,
        type: ActivityLogType.profileUpdated,
        description: 'Profile information was updated.',
      );
      _successMessage = 'Profile updated successfully!';
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }



  // ── Update Medical Info ─────────────────────────────────────────────────────

  /// Updates the medical information fields in Firestore.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> updateMedicalInfo({
    required UserModel current,
    required String bloodGroup,
    required String allergies,
    required String conditions,
    required String medications,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = current.copyWith(
        bloodGroup: bloodGroup.trim(),
        allergies: allergies.trim(),
        conditions: conditions.trim(),
        medications: medications.trim(),
      );
      await _userRepo.updateUser(updated.uid, updated.toMap());
      await _activityRepo.logActivity(
        uid: current.uid,
        type: ActivityLogType.profileUpdated,
        description: 'Medical information was updated.',
      );
      _successMessage = 'Medical information saved!';
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Change Password ─────────────────────────────────────────────────────────

  /// Changes the authenticated user's password.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) return 'Current password is required.';
    if (newPassword.length < 6) {
      return 'New password must be at least 6 characters.';
    }

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _successMessage = 'Password updated successfully!';
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = AuthService.friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Sends a password reset email to [email].
  Future<String?> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) return 'Email cannot be empty.';

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await authService.sendPasswordResetEmail(email.trim());
      _successMessage = 'Password reset email sent to $email!';
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = AuthService.friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Delete Account ──────────────────────────────────────────────────────────

  /// Deletes the user account permanently.
  Future<String?> deleteAccount({required String password}) async {
    if (password.isEmpty) return 'Password is required to confirm deletion.';

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await authService.deleteAccount(password: password);
      _successMessage = 'Account deleted successfully.';
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = AuthService.friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }



  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission') || msg.contains('permission-denied')) {
      return 'Permission denied. Please sign in again.';
    }
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'Network error. Please check your connection.';
    }
    return 'Could not save changes. Please try again.';
  }
}
