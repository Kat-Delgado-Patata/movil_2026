import 'attendance_session.dart';

/// Resumen de un estudiante dentro de un curso, acumulado entre todas sus
/// sesiones cerradas.
class StudentReportStat {
  StudentReportStat({
    required this.studentCode,
    required this.studentName,
    required this.presentCount,
    required this.absentCount,
    required this.excusedCount,
  });

  final String studentCode;
  final String studentName;
  final int presentCount;
  final int absentCount;
  final int excusedCount;

  int get totalSessions => presentCount + absentCount + excusedCount;

  /// Igual que en el resto de la app: lo justificado no suma a favor del
  /// porcentaje, solo evita que cuente como falta "sin justificar".
  double get attendanceRate => totalSessions == 0 ? 0 : presentCount / totalSessions;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return '$first$second'.toUpperCase();
  }
}

/// Reporte consolidado de un curso: totales, por-sesión y por-estudiante.
class CourseAttendanceReport {
  CourseAttendanceReport({
    required this.sessions,
    required this.studentStats,
    required this.sessionAttendeeNamesById,
  });

  /// Sesiones cerradas del curso, más recientes primero.
  final List<AttendanceSession> sessions;

  /// Un registro por estudiante matriculado actualmente, con su acumulado.
  final List<StudentReportStat> studentStats;

  /// Por cada sesión (su id en `attendanceSessions`), el estado de cada
  /// estudiante que tuvo algún registro (presente o justificado) en ella.
  final Map<String, Map<String, AttendeeSnapshot>> sessionAttendeeNamesById;

  int get presentTotal => sessions.fold(0, (sum, s) => sum + s.presentCount);
  int get excusedTotal => sessions.fold(0, (sum, s) => sum + s.excusedCount);
  int get enrolledTotal => sessions.fold(0, (sum, s) => sum + s.totalEnrolled);
  int get absentTotal => (enrolledTotal - presentTotal - excusedTotal).clamp(0, enrolledTotal);

  double get presentRate => enrolledTotal == 0 ? 0 : presentTotal / enrolledTotal;
  double get absentRate => enrolledTotal == 0 ? 0 : absentTotal / enrolledTotal;
  double get excusedRate => enrolledTotal == 0 ? 0 : excusedTotal / enrolledTotal;

  List<AttendanceSession> get recentSessions => sessions.take(4).toList().reversed.toList();

  /// Estudiantes con asistencia por debajo del umbral crítico, de peor a mejor.
  List<StudentReportStat> studentsAtRisk({double threshold = 0.75}) {
    final atRisk = studentStats.where((s) => s.totalSessions > 0 && s.attendanceRate < threshold).toList();
    atRisk.sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
    return atRisk;
  }
}

class AttendeeSnapshot {
  AttendeeSnapshot({required this.excused, required this.checkedInAt});
  final bool excused;
  final DateTime checkedInAt;
}
