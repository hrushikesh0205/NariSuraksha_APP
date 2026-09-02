import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContactPriority
// ─────────────────────────────────────────────────────────────────────────────

/// Priority level for an emergency contact determining alert timing during SOS escalation.
enum ContactPriority {
  /// Immediate alert upon SOS trigger (T = 0).
  high,

  /// Escalated alert if emergency is unresolved after 2 minutes (T = 2 min).
  medium,

  /// Escalated alert if emergency is unresolved after 5 minutes (T = 5 min).
  low;

  static ContactPriority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'medium':
        return ContactPriority.medium;
      case 'low':
        return ContactPriority.low;
      case 'high':
      default:
        return ContactPriority.high;
    }
  }

  String get value => name; // 'high' | 'medium' | 'low'

  String get displayLabel {
    switch (this) {
      case ContactPriority.high:
        return 'High Priority';
      case ContactPriority.medium:
        return 'Medium Priority';
      case ContactPriority.low:
        return 'Low Priority';
    }
  }

  String get timingLabel {
    switch (this) {
      case ContactPriority.high:
        return 'Immediate Alert';
      case ContactPriority.medium:
        return 'Alert after 2 min';
      case ContactPriority.low:
        return 'Alert after 5 min';
    }
  }

  String get shortLabel {
    switch (this) {
      case ContactPriority.high:
        return 'High';
      case ContactPriority.medium:
        return 'Medium';
      case ContactPriority.low:
        return 'Low';
    }
  }

  int get escalationMinutes {
    switch (this) {
      case ContactPriority.high:
        return 0;
      case ContactPriority.medium:
        return 2;
      case ContactPriority.low:
        return 5;
    }
  }
}

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

  /// Alert priority determining when this contact is notified during escalation.
  final ContactPriority priority;

  /// When this contact was first added.
  final DateTime? createdAt;

  const EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.relation = '',
    this.priority = ContactPriority.high,
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
      priority: ContactPriority.fromString(data['priority'] as String?),
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
      'priority': priority.value,
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
      'priority': priority.value,
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
    ContactPriority? priority,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      priority: priority ?? this.priority,
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
      'EmergencyContact(id: $id, name: $name, phone: $phone, relation: $relation, priority: ${priority.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phone == other.phone &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(id, phone, priority);
}
