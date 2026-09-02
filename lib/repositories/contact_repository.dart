import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/models/contact_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContactRepository
// ─────────────────────────────────────────────────────────────────────────────

/// CRUD and real-time subscription for emergency contacts.
///
/// Firestore path: `users/{uid}/contacts/{contactId}`
///
/// Rules enforced by this class:
///  - Maximum of 5 contacts per user.
///  - No duplicate phone numbers per user.
class ContactRepository {
  ContactRepository({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int _maxContacts = 5;

  // ── Collection reference ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _contactsRef(String uid) =>
      _db.collection('users').doc(uid).collection('contacts');

  // ── READ ────────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of the user's emergency contacts,
  /// ordered by creation time (oldest first).
  Stream<List<EmergencyContact>> watchContacts(String uid) {
    final path = 'users/$uid/contacts';
    final authUid = _auth.currentUser?.uid;
    debugPrint('[ContactRepository] watchContacts subscribing to path: $path | request.auth.uid: $authUid');
    return _contactsRef(uid)
        .snapshots()
        .map((snap) {
          debugPrint('[ContactRepository] watchContacts snapshot received ${snap.docs.length} docs for path: $path');
          final list = snap.docs
              .map((doc) => EmergencyContact.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            final aTime = a.createdAt ?? DateTime(2000);
            final bTime = b.createdAt ?? DateTime(2000);
            return aTime.compareTo(bTime);
          });
          return list;
        });
  }

  Future<List<EmergencyContact>> getContacts(String uid) async {
    final path = 'users/$uid/contacts';
    final authUid = _auth.currentUser?.uid;
    debugPrint('[ContactRepository] getContacts fetching path: $path | request.auth.uid: $authUid');
    try {
      final snap = await _contactsRef(uid).get();
      debugPrint('[ContactRepository] getContacts successfully fetched ${snap.docs.length} docs for path: $path');
      final list = snap.docs
          .map((doc) => EmergencyContact.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });
      return list;
    } on FirebaseException catch (e, st) {
      debugPrint('🔥 [ContactRepository] getContacts FirebaseException [${e.code}]: ${e.message}\nPath: $path\n$st');
      rethrow;
    } catch (e, st) {
      debugPrint('🔥 [ContactRepository] getContacts unexpected error: $e\nPath: $path\n$st');
      rethrow;
    }
  }

  // ── CREATE ──────────────────────────────────────────────────────────────────

  /// Adds a new contact for [uid].
  ///
  /// Throws a [ContactLimitException] if the user already has 5 contacts.
  /// Throws a [DuplicatePhoneException] if the phone number already exists.
  Future<EmergencyContact> addContact(
    String uid,
    EmergencyContact contact,
  ) async {
    // ── Diagnostic: log auth state before any Firestore operation ──
    final authUid = _auth.currentUser?.uid;
    final docPath = 'users/$uid/contacts/<new-doc>';
    debugPrint('🟡 [ContactRepository] addContact called');
    debugPrint('   → requested uid : $uid');
    debugPrint('   → auth.currentUser.uid: $authUid');
    debugPrint('   → match: ${authUid == uid}');
    debugPrint('   → Firestore path: $docPath');

    if (authUid == null) {
      debugPrint('🔥 [ContactRepository] addContact aborted — user is not authenticated!');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'User is not authenticated.',
      );
    }
    if (authUid != uid) {
      debugPrint('🔥 [ContactRepository] addContact aborted — UID mismatch!');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'UID mismatch: auth=$authUid, requested=$uid',
      );
    }

    // Guard: max contacts
    final existing = await getContacts(uid);
    if (existing.length >= _maxContacts) {
      throw const ContactLimitException(
        'You have reached the maximum of $_maxContacts emergency contacts.',
      );
    }

    // Guard: duplicate phone
    final normalized = _normalizePhone(contact.phone);
    final hasDuplicate = existing.any(
      (c) => _normalizePhone(c.phone) == normalized,
    );
    if (hasDuplicate) {
      throw const DuplicatePhoneException(
        'A contact with this phone number already exists.',
      );
    }

    final docRef = _contactsRef(uid).doc();
    debugPrint('🟡 [ContactRepository] Calling docRef.set() on path: users/$uid/contacts/${docRef.id}');
    try {
      await docRef.set(contact.copyWith(userId: uid).toCreateMap());
      debugPrint('✅ [ContactRepository] addContact succeeded for path: users/$uid/contacts/${docRef.id}');
    } on FirebaseException catch (e) {
      debugPrint('🔥 [ContactRepository] addContact FirebaseException [${e.code}]: ${e.message}');
      debugPrint('   → auth.uid at time of failure: ${_auth.currentUser?.uid}');
      rethrow;
    }
    return contact.copyWith(id: docRef.id, userId: uid);
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────────

  /// Updates an existing contact document.
  ///
  /// Throws [ArgumentError] if [contact.id] is null.
  /// Throws a [DuplicatePhoneException] if another contact already has the same phone.
  Future<void> updateContact(String uid, EmergencyContact contact) async {
    final id = contact.id;
    if (id == null) throw ArgumentError('contact.id must not be null for update');

    // Guard: duplicate phone (exclude self)
    final existing = await getContacts(uid);
    final normalized = _normalizePhone(contact.phone);
    final hasDuplicate = existing.any(
      (c) => c.id != id && _normalizePhone(c.phone) == normalized,
    );
    if (hasDuplicate) {
      throw const DuplicatePhoneException(
        'Another contact with this phone number already exists.',
      );
    }

    await _contactsRef(uid).doc(id).update(contact.toMap());
  }

  // ── DELETE ──────────────────────────────────────────────────────────────────

  /// Permanently removes the contact document.
  Future<void> deleteContact(String uid, String contactId) async {
    final authUser = _auth.currentUser;
    final authUid = authUser?.uid;
    final path = 'users/$uid/contacts/$contactId';

    debugPrint('==================================================');
    debugPrint('[DELETE CONTACT]');
    debugPrint('authenticated UID = $authUid');
    debugPrint('requested UID = $uid');
    debugPrint('contactId = $contactId');
    debugPrint('Firestore path = $path');
    debugPrint('FirebaseAuth.currentUser is null? ${authUser == null}');
    debugPrint('==================================================');

    if (authUser == null) {
      debugPrint('[DELETE CONTACT FAILED]');
      debugPrint('FirebaseException code = unauthenticated');
      debugPrint('message = User is not authenticated.');
      debugPrint('path = $path');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'User is not authenticated.',
      );
    }
    if (authUid != uid) {
      debugPrint('[DELETE CONTACT FAILED]');
      debugPrint('FirebaseException code = permission-denied');
      debugPrint('message = UID mismatch: auth=$authUid, requested=$uid');
      debugPrint('path = $path');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'UID mismatch: auth=$authUid, requested=$uid',
      );
    }

    try {
      await _contactsRef(uid).doc(contactId).delete();
      debugPrint('[DELETE CONTACT SUCCESS]');
      debugPrint('contactId = $contactId');
      debugPrint('path = $path');

      // Post-delete verification check in Firestore
      try {
        final checkDoc = await _contactsRef(uid).doc(contactId).get();
        debugPrint('[DELETE CONTACT VERIFY] Document exists after delete? ${checkDoc.exists}');
      } catch (verifyErr) {
        debugPrint('[DELETE CONTACT VERIFY ERROR] Could not verify post-delete doc existence: $verifyErr');
      }
    } on FirebaseException catch (e) {
      debugPrint('==================================================');
      debugPrint('[DELETE CONTACT FAILED]');
      debugPrint('FirebaseException code = ${e.code}');
      debugPrint('message = ${e.message}');
      debugPrint('path = $path');
      debugPrint('==================================================');
      rethrow;
    } catch (e) {
      debugPrint('==================================================');
      debugPrint('[DELETE CONTACT FAILED] Unexpected error: $e');
      debugPrint('path = $path');
      debugPrint('==================================================');
      rethrow;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain exceptions
// ─────────────────────────────────────────────────────────────────────────────

class ContactLimitException implements Exception {
  final String message;
  const ContactLimitException(this.message);
  @override
  String toString() => message;
}

class DuplicatePhoneException implements Exception {
  final String message;
  const DuplicatePhoneException(this.message);
  @override
  String toString() => message;
}
