import 'package:firebase_auth/firebase_auth.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────────────────────

/// Application-level wrapper around [FirebaseAuth].
///
/// Provides:
/// - Current authenticated user (Firebase + Firestore model).
/// - Sign-out.
/// - Ensures a Firestore user document exists after sign-in.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  // ── Accessors ──────────────────────────────────────────────────────────────

  /// The raw Firebase user, or `null` when unauthenticated.
  User? get firebaseUser => _auth.currentUser;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Stream that emits `User?` whenever auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

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
        await _userRepository.createUser(model);
      }

      return model;
    } catch (_) {
      // Firestore unavailable — fall back to Auth profile.
      return _buildFromFirebaseUser(fbUser);
    }
  }

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
}
