import 'package:drift/drift.dart';

// -----------------------------------------------------------------------------
// LocalContactsTable
// -----------------------------------------------------------------------------

/// Local cache of emergency contacts for offline SOS SMS dispatch.
///
/// Mirrors the Firestore `users/{uid}/contacts/{contactId}` structure.
/// Populated by synchronizing from Firestore when online.
class LocalContactsTable extends Table {
  /// Firestore document ID (primary key for deduplication).
  TextColumn get id => text()();

  /// UID of the owning user.
  TextColumn get userId => text()();

  /// Guardian display name.
  TextColumn get name => text()();

  /// Full phone number string.
  TextColumn get phone => text()();

  /// Relationship label.
  TextColumn get relation => text().withDefault(const Constant(''))();

  /// Priority: 'high' | 'medium' | 'low'
  TextColumn get priority => text().withDefault(const Constant('high'))();

  /// ISO 8601 timestamp of creation (nullable).
  TextColumn get createdAt => text().nullable()();

  /// ISO 8601 timestamp of last local update.
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
