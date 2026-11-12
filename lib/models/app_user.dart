import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// Documento de usuario en Firestore: colección `users`, id = uid de Firebase Auth.
class AppUser {
  const AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.faculty,
    this.photoUrl,
    this.studentCode,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? faculty;
  final String? photoUrl;

  /// Código universitario del estudiante; se usa para vincularlo al roster de sus cursos.
  final String? studentCode;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final initials = '$f$l'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRoleX.fromValue(data['role'] as String?),
      faculty: data['faculty'] as String?,
      photoUrl: data['photoUrl'] as String?,
      studentCode: data['studentCode'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': role.value,
        if (faculty != null) 'faculty': faculty,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (studentCode != null) 'studentCode': studentCode,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
