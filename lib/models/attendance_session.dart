import 'package:cloud_firestore/cloud_firestore.dart';

/// Una sesión de asistencia ya cerrada, para el historial del docente.
/// Vive en la colección plana `attendanceSessions` (permite filtrar/ordenar
/// entre todos los cursos de un docente sin índices compuestos).
class AttendanceSession {
  AttendanceSession({
    this.id,
    required this.teacherUid,
    required this.courseId,
    required this.date,
    required this.presentCount,
    required this.totalEnrolled,
    this.excusedCount = 0,
    this.liveSessionId,
  });

  final String? id;
  final String teacherUid;
  final String courseId;

  /// Día en que se dictó la sesión.
  final DateTime date;
  final int presentCount;
  final int totalEnrolled;

  /// Estudiantes que el docente marcó como justificados a mano (no cuentan como presentes).
  final int excusedCount;

  /// Id de la sesión en `liveSessions` de la que proviene (permite saber, por
  /// estudiante, si estuvo entre los que marcaron presente).
  final String? liveSessionId;

  int get absentCount => (totalEnrolled - presentCount - excusedCount).clamp(0, totalEnrolled);

  double get attendanceRate => totalEnrolled == 0 ? 0 : (presentCount / totalEnrolled) * 100;

  Map<String, dynamic> toCreateMap() => {
        'teacherUid': teacherUid,
        'courseId': courseId,
        'date': Timestamp.fromDate(date),
        'presentCount': presentCount,
        'totalEnrolled': totalEnrolled,
        'excusedCount': excusedCount,
        'createdAt': FieldValue.serverTimestamp(),
        if (liveSessionId != null) 'liveSessionId': liveSessionId,
      };

  factory AttendanceSession.fromMap(String id, Map<String, dynamic> data) {
    return AttendanceSession(
      id: id,
      teacherUid: data['teacherUid'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      presentCount: data['presentCount'] as int? ?? 0,
      totalEnrolled: data['totalEnrolled'] as int? ?? 0,
      excusedCount: data['excusedCount'] as int? ?? 0,
      liveSessionId: data['liveSessionId'] as String?,
    );
  }
}
