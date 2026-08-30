import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmergencyContact
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single trusted emergency contact (Guardian).
///
/// Firestore path: `users/{uid}/contacts/{contactId}`
///
/// Immutable by design — use [copyWith] to derive modified copies.
@immutable
class EmergencyContact {
  /// Firestore document ID (null before first write).
  final String? id;

  /// UID of the user who owns this contact.
  final String userId;

  /// The guardian's display name (e.g. "Mom", "Priya").
  final String name;

  /// The guardian's full phone number string (e.g. "+91 98765 43210").
  final String phone;

  /// Relationship label (e.g. "Mother", "Father", "Best Friend").
  final String relation;

  /// When this contact was first added.
  final DateTime? createdAt;

  const EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relation = '',
    this.createdAt,
  });

  // ── Factories ───────────────────────────────────────────────────────────────

  factory EmergencyContact.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EmergencyContact(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      relation: (data['relation'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  /// Map for updating an existing Firestore document.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name.trim(),
      'phone': phone.trim(),
      'relation': relation.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Map for creating a brand-new Firestore document.
  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'name': name.trim(),
      'phone': phone.trim(),
      'relation': relation.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? relation,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns initials for the avatar fallback (up to 2 chars).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Basic phone validation — accepts 10-13 digits with optional +/spaces.
  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+?[0-9]{10,13}$').hasMatch(cleaned);
  }

  @override
  String toString() =>
      'EmergencyContact(id: $id, name: $name, phone: $phone, relation: $relation)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phone == other.phone;

  @override
  int get hashCode => Object.hash(id, phone);
}
