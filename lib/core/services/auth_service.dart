import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────────────────────

/// Application-level wrapper around [FirebaseAuth].
///
/// Provides:
/// - Sign in with email + password.
/// - Register with email + password + name.
/// - Password reset email.
/// - Current authenticated user (Firebase + Firestore model).
/// - Sign-out.
/// - Ensures a Firestore user document exists after sign-in (best-effort).
///
/// Every Firebase Auth call is guarded by [_kAuthTimeout].
/// Every Firestore call is already guarded inside [UserRepository].
/// Firestore document creation after registration is **best-effort** —
/// if it fails, the Firebase Auth user was still created successfully and
/// the UI proceeds normally (the document will be created on next sign-in).
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  /// Maximum time to wait for a Firebase Auth network call.
  static const Duration _kAuthTimeout = Duration(seconds: 30);

  // ── Accessors ──────────────────────────────────────────────────────────────

  /// The raw Firebase user, or `null` when unauthenticated.
  User? get firebaseUser => _auth.currentUser;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Stream that emits `User?` whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign In ────────────────────────────────────────────────────────────────

  /// Signs in with [email] and [password].
  ///
  /// Returns the [UserModel] on success.
  /// Re-throws [FirebaseAuthException] for the UI to handle.
  /// Firestore profile fetch is best-effort — falls back to auth profile
  /// if Firestore is unavailable so sign-in never hangs on Firestore.
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(
          _kAuthTimeout,
          onTimeout: () => throw FirebaseAuthException(
            code: 'network-request-failed',
            message: 'Sign-in timed out. Please check your connection.',
          ),
        );
    final fbUser = credential.user!;

    // Firestore profile fetch is best-effort: if Firestore is down or
    // the API is not yet enabled, we fall back to the Firebase Auth profile
    // so the user is never stuck on a loading screen.
    try {
      UserModel? model = await _userRepository.fetchUser(fbUser.uid);
      if (model == null) {
        model = _buildFromFirebaseUser(fbUser);
        // Best-effort write — ignore failures.
        try {
          await _userRepository.createUser(model);
        } catch (firestoreErr) {
          debugPrint(
            '⚠️ AuthService: Firestore createUser failed during sign-in '
            '(non-fatal): $firestoreErr',
          );
        }
      }
      return model;
    } catch (firestoreErr) {
      debugPrint(
        '⚠️ AuthService: Firestore fetchUser failed during sign-in '
        '(non-fatal, using Auth profile): $firestoreErr',
      );
      return _buildFromFirebaseUser(fbUser);
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  /// Creates a new Firebase Auth account, then attempts to write a Firestore
  /// user document.
  ///
  /// The Firestore write is **best-effort**: if it fails (e.g. Firestore API
  /// not enabled, permission denied, or timeout), the error is logged and the
  /// method still returns the [UserModel] so the UI can proceed.
  ///
  /// The Firestore document will be created automatically on the next
  /// [signInWithEmailPassword] call once the issue is resolved.
  ///
  /// Re-throws [FirebaseAuthException] for the UI to handle when the Firebase
  /// Auth registration itself fails.
  Future<UserModel> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    // Step 1: Firebase Auth — this can throw FirebaseAuthException.
    final credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(
          _kAuthTimeout,
          onTimeout: () => throw FirebaseAuthException(
            code: 'network-request-failed',
            message: 'Registration timed out. Please check your connection.',
          ),
        );
    final fbUser = credential.user!;

    // Step 2: Update Firebase Auth display name (best-effort).
    try {
      await fbUser.updateDisplayName(name.trim());
    } catch (e) {
      debugPrint('⚠️ AuthService: updateDisplayName failed (non-fatal): $e');
    }

    // Step 3: Build the UserModel.
    final model = UserModel(
      uid: fbUser.uid,
      name: name.trim().isNotEmpty
          ? name.trim()
          : _capitalise(email.split('@').first),
      email: email.trim(),
      phone: phone?.trim(),
    );

    // Step 4: Write Firestore document — best-effort.
    // Firebase Auth registration already succeeded at this point.
    // If Firestore is unavailable (API not enabled, permission denied, timeout),
    // we log the error and return the model anyway so the UI is never stuck.
    try {
      await _userRepository.createUser(model);
      debugPrint('✅ AuthService: Firestore user document created for ${fbUser.uid}');
    } catch (firestoreErr) {
      debugPrint(
        '⚠️ AuthService: Firestore createUser failed after successful Auth '
        'registration (non-fatal). Doc will be created on next sign-in.\n'
        '   Error: $firestoreErr',
      );
      // Do NOT rethrow — auth succeeded, user is registered.
    }

    return model;
  }

  // ── Password Reset ─────────────────────────────────────────────────────────

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── User Model ─────────────────────────────────────────────────────────────

  /// Fetches the [UserModel] from Firestore for the current user.
  ///
  /// If the Firestore document does not exist yet (e.g. Google sign-in),
  /// creates it from the Firebase Auth profile and returns the new model.
  Future<UserModel?> fetchCurrentUserModel() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;

    try {
      // Try fetching from Firestore first.
      UserModel? model = await _userRepository.fetchUser(fbUser.uid);

      if (model == null) {
        // Bootstrap: create document from Firebase Auth profile.
        model = _buildFromFirebaseUser(fbUser);
        try {
          await _userRepository.createUser(model);
        } catch (e) {
          debugPrint('⚠️ AuthService: fetchCurrentUserModel createUser failed (non-fatal): $e');
        }
      }

      return model;
    } catch (_) {
      // Firestore unavailable — fall back to Auth profile.
      return _buildFromFirebaseUser(fbUser);
    }
  }

  // ── Password Management ───────────────────────────────────────────────────

  /// Changes the current user's password after re-authenticating with [currentPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'User does not have an associated email address.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential).timeout(
      _kAuthTimeout,
      onTimeout: () => throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Re-authentication timed out. Please check your connection.',
      ),
    );

    await user.updatePassword(newPassword).timeout(
      _kAuthTimeout,
      onTimeout: () => throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Password update timed out. Please check your connection.',
      ),
    );
  }

  // ── Account Deletion ───────────────────────────────────────────────────────

  /// Re-authenticates and permanently deletes the current user's account.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential).timeout(
        _kAuthTimeout,
        onTimeout: () => throw FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Re-authentication timed out. Please check your connection.',
        ),
      );
    }

    try {
      await _userRepository.updateUser(user.uid, {
        'deleted': true,
      });
    } catch (_) {}

    await user.delete().timeout(
      _kAuthTimeout,
      onTimeout: () => throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Account deletion timed out. Please check your connection.',
      ),
    );
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  /// Signs the current user out of Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  UserModel _buildFromFirebaseUser(User user) {
    // Derive name: displayName → email prefix → 'User'
    final rawName = user.displayName?.trim();
    final emailPrefix = user.email?.split('@').first.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (emailPrefix != null && emailPrefix.isNotEmpty)
            ? _capitalise(emailPrefix)
            : 'User';

    return UserModel(
      uid: user.uid,
      name: name,
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Converts an error to a human-readable error string.
  ///
  /// Handles both [FirebaseAuthException] and plain [Exception] objects
  /// (e.g. those re-thrown from [UserRepository]).
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      debugPrint(
        '🔥 FirebaseAuthException [${error.code}]: ${error.message}',
      );
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid email or password. Please try again.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'api-key-not-valid':
        case 'api-not-enabled':
        case 'app-not-authorized':
          return 'The app is not fully configured yet. Please contact support.';
        default:
          // Mask any raw internal Firebase messages (e.g. "API key not valid")
          // that should never be shown to end users.
          final msg = error.message ?? '';
          if (msg.contains('API key') ||
              msg.contains('INVALID_LOGIN_CREDENTIALS') ||
              msg.contains('INTERNAL') ||
              msg.contains('internal error')) {
            return 'Authentication failed. Please try again later.';
          }
          return 'Authentication failed. Please try again.';
      }
    }

    // Handle plain Exception objects (e.g. re-thrown from UserRepository).
    final errStr = error.toString();
    debugPrint('🔥 AuthService error: $errStr');

    if (errStr.contains('firestore/permission-denied') ||
        errStr.contains('PERMISSION_DENIED')) {
      return 'Account created! Please enable Firestore in Firebase Console.';
    }
    if (errStr.contains('timed out') || errStr.contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    }
    if (errStr.contains('firestore/unavailable') ||
        errStr.contains('network') ||
        errStr.contains('unavailable')) {
      return 'Network error. Please check your connection.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
