import 'package:cloud_firestore/cloud_firestore.dart';

/// Un registro de "presente" ya confirmado, para mostrarle al estudiante su
/// comprobante. Se lee de los mismos documentos `liveSessions/*/attendees/*`
/// que ya usa el docente, con algunos campos denormalizados al momento del check-in.
class AttendanceCheckIn {
  AttendanceCheckIn({
    required this.courseId,
    required this.courseName,
    required this.courseGroup,
    required this.checkedInAt,
    required this.validationId,
    this.distanceMeters,
  });

  final String courseId;
  final String courseName;
  final String courseGroup;
  final DateTime checkedInAt;
  final String validationId;

  /// Distancia en metros al punto donde el docente abrió la sesión; null si esa
  /// sesión no tenía ubicación registrada.
  final double? distanceMeters;

  factory AttendanceCheckIn.fromMap(Map<String, dynamic> data) {
    return AttendanceCheckIn(
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      courseGroup: data['courseGroup'] as String? ?? '',
      checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validationId: data['validationId'] as String? ?? '',
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
    );
  }
}
