/// Resultado real de un estudiante en una sesión de asistencia ya cerrada.
/// "Justificada" solo la puede marcar el docente a mano (pasar lista); el
/// estudiante nunca puede auto-justificarse.
enum StudentAttendanceStatus { present, excused, absent }

class StudentAttendanceRecord {
  StudentAttendanceRecord({
    required this.courseId,
    required this.courseName,
    required this.courseRoom,
    required this.period,
    required this.date,
    required this.status,
  });

  final String courseId;
  final String courseName;
  final String courseRoom;
  final String period;

  /// Fecha/hora de la sesión (si estuvo presente, es la hora exacta de su check-in).
  final DateTime date;
  final StudentAttendanceStatus status;

  bool get isPresent => status == StudentAttendanceStatus.present;
  bool get isExcused => status == StudentAttendanceStatus.excused;
  bool get isAbsent => status == StudentAttendanceStatus.absent;
}
