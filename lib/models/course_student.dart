import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de la matrícula dentro del curso (no borra historial, solo lo oculta).
enum RosterStatus { active, removed }

extension RosterStatusX on RosterStatus {
  String get value => this == RosterStatus.removed ? 'removed' : 'active';

  static RosterStatus fromValue(String? value) =>
      value == 'removed' ? RosterStatus.removed : RosterStatus.active;
}

/// Un estudiante matriculado en un curso. Vive en `courses/{courseId}/students/{id}`.
class CourseStudent {
  CourseStudent({
    this.id,
    required this.courseId,
    required this.fullName,
    required this.code,
    this.status = RosterStatus.active,
    this.attendancePercentage,
    this.createdAt,
  });

  final String? id;
  final String courseId;
  final String fullName;
  final String code;
  final RosterStatus status;

  /// Null mientras no exista ningún registro de asistencia real para este estudiante.
  final double? attendancePercentage;
  final DateTime? createdAt;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return '$first$second'.toUpperCase();
  }

  Map<String, dynamic> toCreateMap() => {
        'fullName': fullName,
        'code': code,
        'status': status.value,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory CourseStudent.fromMap(String id, String courseId, Map<String, dynamic> data) {
    return CourseStudent(
      id: id,
      courseId: courseId,
      fullName: data['fullName'] as String? ?? '',
      code: data['code'] as String? ?? '',
      status: RosterStatusX.fromValue(data['status'] as String?),
      attendancePercentage: (data['attendancePercentage'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
