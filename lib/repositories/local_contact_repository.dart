import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/local_db/local_database.dart';
import 'package:nari_suraksha/models/contact_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalContactRepository
// ─────────────────────────────────────────────────────────────────────────────

/// CRUD operations for the local emergency contacts cache (Drift/SQLite).
///
/// Used as an offline fallback when Firestore is unavailable.
/// Contacts are synced FROM Firestore → local DB when online.
class LocalContactRepository {
  LocalContactRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all locally cached contacts for the given [userId].
  Future<List<EmergencyContact>> getContactsForUser(String userId) async {
    try {
      final rows = await (_db.select(_db.localContactsTable)
            ..where((c) => c.userId.equals(userId)))
          .get();
      return rows.map(_rowToModel).toList();
    } catch (e) {
      debugPrint('⚠️ LocalContactRepository.getContactsForUser error: $e');
      return [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Replaces the full local contact set for [userId] from [contacts].
  ///
  /// Performs a DELETE+INSERT to keep local state in sync with Firestore.
  Future<void> replaceAll(String userId, List<EmergencyContact> contacts) async {
    try {
      await _db.transaction(() async {
        // Delete all existing contacts for this user.
        await (_db.delete(_db.localContactsTable)
              ..where((c) => c.userId.equals(userId)))
            .go();

        // Insert fresh set.
        for (final contact in contacts) {
          await _db
              .into(_db.localContactsTable)
              .insertOnConflictUpdate(_modelToCompanion(contact, userId));
        }
      });
      debugPrint('📦 LocalContactRepository: cached ${contacts.length} contacts for $userId');
    } catch (e) {
      debugPrint('⚠️ LocalContactRepository.replaceAll error: $e');
    }
  }

  /// Inserts or updates a single contact in the local cache.
  Future<void> upsert(EmergencyContact contact, String userId) async {
    try {
      await _db
          .into(_db.localContactsTable)
          .insertOnConflictUpdate(_modelToCompanion(contact, userId));
    } catch (e) {
      debugPrint('⚠️ LocalContactRepository.upsert error: $e');
    }
  }

  /// Removes a contact from the local cache by [contactId].
  Future<void> delete(String contactId) async {
    try {
      await (_db.delete(_db.localContactsTable)
            ..where((c) => c.id.equals(contactId)))
          .go();
    } catch (e) {
      debugPrint('⚠️ LocalContactRepository.delete error: $e');
    }
  }

  // ── Converters ────────────────────────────────────────────────────────────

  EmergencyContact _rowToModel(LocalContactsTableData row) {
    return EmergencyContact(
      id: row.id,
      userId: row.userId,
      name: row.name,
      phone: row.phone,
      relation: row.relation,
      priority: _parsePriority(row.priority),
      createdAt: row.createdAt != null ? DateTime.tryParse(row.createdAt!) : null,
    );
  }

  LocalContactsTableCompanion _modelToCompanion(
      EmergencyContact contact, String userId) {
    return LocalContactsTableCompanion(
      id: Value(contact.id ?? '${userId}_${contact.phone.replaceAll(RegExp(r'[^\d]'), '')}'),
      userId: Value(userId),
      name: Value(contact.name),
      phone: Value(contact.phone),
      relation: Value(contact.relation),
      priority: Value(_priorityToString(contact.priority)),
      createdAt: Value(contact.createdAt?.toIso8601String()),
      updatedAt: Value(DateTime.now().toIso8601String()),
    );
  }

  ContactPriority _parsePriority(String raw) {
    switch (raw.toLowerCase()) {
      case 'medium':
        return ContactPriority.medium;
      case 'low':
        return ContactPriority.low;
      default:
        return ContactPriority.high;
    }
  }

  String _priorityToString(ContactPriority p) {
    switch (p) {
      case ContactPriority.medium:
        return 'medium';
      case ContactPriority.low:
        return 'low';
      case ContactPriority.high:
        return 'high';
    }
  }
}
