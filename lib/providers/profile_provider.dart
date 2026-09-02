import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Handles all profile edit operations (basic info, photo upload, medical info, and account security).
///
/// Works in concert with [UserProvider] — call [UserProvider.refresh()] after
/// a successful save to refresh the displayed user data.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    UserRepository? userRepository,
    ActivityRepository? activityRepository,
    AuthService? authService,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _userRepo = userRepository ?? UserRepository(),
        _activityRepo = activityRepository ?? ActivityRepository(),
        _authService = authService,
        _storage = storage,
        _imagePicker = imagePicker ?? ImagePicker();

  final UserRepository _userRepo;
  final ActivityRepository _activityRepo;
  AuthService? _authService;
  FirebaseStorage? _storage;
  final ImagePicker _imagePicker;

  AuthService get authService => _authService ??= AuthService();
  FirebaseStorage get storage => _storage ??= FirebaseStorage.instance;

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isSaving => _isSaving;
  bool get isUploadingPhoto => _isUploadingPhoto;
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

  // ── Upload Profile Photo via Native Gallery ────────────────────────────────

  /// Opens the native image picker, compresses the selected image,
  /// uploads it to Firebase Storage under `users/{uid}/profile/profile.jpg`,
  /// and updates the user's `photoUrl` in Firestore.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> pickAndUploadProfilePhoto({
    required String uid,
    XFile? preselectedFile,
    bool simulatedCancel = false,
  }) async {
    if (uid.isEmpty) return 'User ID is required.';

    _isUploadingPhoto = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final file = simulatedCancel
          ? null
          : (preselectedFile ??
              await _imagePicker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 80,
              ));

      if (file == null) {
        // User cancelled image selection
        _isUploadingPhoto = false;
        notifyListeners();
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Selected image is empty.');
      }

      final storageRef = storage
          .ref()
          .child('users')
          .child(uid)
          .child('profile')
          .child('profile.jpg');

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update Firestore user document
      await _userRepo.updateUser(uid, {'photoUrl': downloadUrl});

      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.profileUpdated,
        description: 'Profile photo was updated.',
      );

      _successMessage = 'Profile photo updated successfully!';
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      debugPrint('🔥 [ProfileProvider] FirebaseStorage error [${e.code}]: ${e.message}');
      _errorMessage = _friendlyStorageError(e);
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      debugPrint('🔥 [ProfileProvider] upload photo error: $e');
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return _errorMessage;
    } finally {
      _isUploadingPhoto = false;
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

  String _friendlyStorageError(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'Storage permission denied. Please verify Firebase Storage rules.';
      case 'canceled':
        return 'Upload was cancelled.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please try a smaller image.';
      case 'retry-limit-exceeded':
        return 'Network timeout during upload. Please check your connection.';
      default:
        return 'Failed to upload photo: ${e.message ?? e.code}';
    }
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
