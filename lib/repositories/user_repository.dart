import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nari_suraksha/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Data-access layer for the `users` Firestore collection.
///
/// All Firestore reads and writes for user documents go through this class.
/// Business logic is kept in services; this class only handles raw data ops.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches the user document for [uid].
  ///
  /// Returns `null` if the document does not exist.
  Future<UserModel?> fetchUser(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw _mapFirestoreException(e);
    }
  }

  /// Streams live updates for the user document of [uid].
  Stream<UserModel?> watchUser(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? UserModel.fromFirestore(snap) : null);
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Creates a new user document in Firestore.
  ///
  /// Uses [SetOptions(merge: true)] so it won't overwrite an existing doc.
  Future<void> createUser(UserModel user) async {
    try {
      await _users.doc(user.uid).set(user.toCreateMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw _mapFirestoreException(e);
    }
  }

  /// Partially updates the user document — only the provided fields change.
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    try {
      await _users.doc(uid).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw _mapFirestoreException(e);
    }
  }

  // ── Error mapping ──────────────────────────────────────────────────────────

  Exception _mapFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return Exception('Permission denied: ${e.message}');
      case 'not-found':
        return Exception('Document not found: ${e.message}');
      case 'unavailable':
        return Exception('Firestore unavailable. Check your connection.');
      default:
        return Exception('Firestore error [${e.code}]: ${e.message}');
    }
  }
}
