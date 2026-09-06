import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/utils/initials_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserModel
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a registered Nari Suraksha user stored in Firestore.
///
/// Firestore path: `users/{uid}`
///
/// Design:
/// - Immutable value object.
/// - [fromFirestore] for reading from Firestore [DocumentSnapshot].
/// - [toMap] for writing to Firestore.
/// - [copyWith] for deriving modified copies without mutation.
@immutable
class UserModel {
  /// Firebase UID — matches [FirebaseAuth.currentUser.uid].
  final String uid;

  /// Display name (e.g. "Priya Sharma"). Falls back to email prefix.
  final String name;

  /// Verified email address.
  final String email;

  /// Optional phone number (E.164 format, e.g. "+919876543210").
  final String? phone;

  /// Optional URL to the user's profile photo (Firebase Storage or external).
  final String? photoUrl;

  // ── Medical Information ─────────────────────────────────────────────────────

  /// Blood group, e.g. "B+" or "O-". Empty string if not set.
  final String bloodGroup;

  /// Comma-separated allergy list (as a single string for simplicity).
  final String allergies;

  /// Comma-separated medical conditions.
  final String conditions;

  /// Comma-separated current medications.
  final String medications;

  /// Optional user settings and preferences.
  final Map<String, dynamic> settings;

  /// Timestamp when the account was created.
  final DateTime? createdAt;

  /// Timestamp of the last profile update.
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.bloodGroup = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
    this.settings = const {},
    this.createdAt,
    this.updatedAt,
  });

  // ── Factory constructors ────────────────────────────────────────────────────

  /// Creates a [UserModel] from a Firestore [DocumentSnapshot].
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'User',
      email: (data['email'] as String?) ?? '',
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      bloodGroup: (data['bloodGroup'] as String?) ?? '',
      allergies: (data['allergies'] as String?) ?? '',
      conditions: (data['conditions'] as String?) ?? '',
      medications: (data['medications'] as String?) ?? '',
      settings: (data['settings'] as Map<String, dynamic>?) ?? const {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Creates a [UserModel] from a plain [Map] (e.g. from local cache).
  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    return UserModel(
      uid: uid,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'User',
      email: (map['email'] as String?) ?? '',
      phone: map['phone'] as String?,
      photoUrl: map['photoUrl'] as String?,
      bloodGroup: (map['bloodGroup'] as String?) ?? '',
      allergies: (map['allergies'] as String?) ?? '',
      conditions: (map['conditions'] as String?) ?? '',
      medications: (map['medications'] as String?) ?? '',
      settings: (map['settings'] as Map<String, dynamic>?) ?? const {},
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  /// Converts the model to a [Map] suitable for writing to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'conditions': conditions,
      'medications': medications,
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Produces the initial document map for a brand-new user.
  Map<String, dynamic> toCreateMap() {
    return {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'conditions': conditions,
      'medications': medications,
      'settings': settings,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Derived helpers ─────────────────────────────────────────────────────────

  /// Returns a [UserModel] with optionally overridden fields.
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? bloodGroup,
    String? allergies,
    String? conditions,
    String? medications,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns the user's first name for greeting display.
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : name;
  }

  /// Returns initials for the avatar using [InitialsHelper].
  String get initials => InitialsHelper.getInitials(name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, email: $email)';
}
