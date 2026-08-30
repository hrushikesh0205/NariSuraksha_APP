import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Data-access layer for the `users` Firestore collection.
///
/// All Firestore reads and writes for user documents go through this class.
/// Business logic is kept in services; this class only handles raw data ops.
///
/// Every network call has a [_kTimeout] guard so the UI can never hang
/// indefinitely if Firestore is slow or the API has not been enabled yet.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Maximum time to wait for any single Firestore operation.
  static const Duration _kTimeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches the user document for [uid].
  ///
  /// Returns `null` if the document does not exist.
  /// Throws a descriptive [Exception] on network/permission errors.
  Future<UserModel?> fetchUser(String uid) async {
    try {
      final doc = await _users.doc(uid).get().timeout(
        _kTimeout,
        onTimeout: () => throw Exception(
          'Firestore fetchUser timed out after ${_kTimeout.inSeconds}s',
        ),
      );
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore fetchUser [${e.code}]: ${e.message}');
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
      await _users.doc(user.uid).set(user.toCreateMap(), SetOptions(merge: true)).timeout(
        _kTimeout,
        onTimeout: () => throw Exception(
          'Firestore createUser timed out after ${_kTimeout.inSeconds}s',
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore createUser [${e.code}]: ${e.message}');
      throw _mapFirestoreException(e);
    }
  }

  /// Partially updates the user document — only the provided fields change.
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    try {
      await _users.doc(uid).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(
        _kTimeout,
        onTimeout: () => throw Exception(
          'Firestore updateUser timed out after ${_kTimeout.inSeconds}s',
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firestore updateUser [${e.code}]: ${e.message}');
      throw _mapFirestoreException(e);
    }
  }

  // ── Error mapping ──────────────────────────────────────────────────────────

  Exception _mapFirestoreException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return Exception('firestore/permission-denied: ${e.message}');
      case 'not-found':
        return Exception('firestore/not-found: ${e.message}');
      case 'unavailable':
        return Exception('firestore/unavailable: Check your connection.');
      default:
        return Exception('firestore/${e.code}: ${e.message}');
    }
  }
}
