import '../models/attendance_session.dart';
import '../models/course_attendance_report.dart';
import 'attendance_session_repository.dart';
import 'course_student_repository.dart';
import 'live_session_repository.dart';

/// Arma el reporte consolidado de un curso cruzando sus sesiones cerradas con
/// quién marcó presente/justificado en cada una, para el roster actual.
class CourseAttendanceReportRepository {
  CourseAttendanceReportRepository._();
  static final CourseAttendanceReportRepository instance = CourseAttendanceReportRepository._();

  Future<CourseAttendanceReport> fetchReport(String courseId) async {
    final sessions = await AttendanceSessionRepository.instance.fetchCourseSessions(courseId);
    final roster = await CourseStudentRepository.instance.fetchActiveStudents(courseId);

    // Por cada sesión, quién tiene registro (presente o justificado) y cómo.
    final sessionAttendeeNamesById = <String, Map<String, AttendeeSnapshot>>{};
    for (final session in sessions) {
      if (session.id == null || session.liveSessionId == null) continue;
      final attendees = await LiveSessionRepository.instance.fetchAttendees(session.liveSessionId!);
      sessionAttendeeNamesById[session.id!] = {
        for (final a in attendees) a.studentCode: AttendeeSnapshot(excused: a.isExcused, checkedInAt: a.checkedInAt),
      };
    }

    final studentStats = <StudentReportStat>[
      for (final student in roster) _statsFor(student.code, student.fullName, sessions, sessionAttendeeNamesById),
    ];

    return CourseAttendanceReport(
      sessions: sessions,
      studentStats: studentStats,
      sessionAttendeeNamesById: sessionAttendeeNamesById,
    );
  }

  StudentReportStat _statsFor(
    String studentCode,
    String studentName,
    List<AttendanceSession> sessions,
    Map<String, Map<String, AttendeeSnapshot>> bySession,
  ) {
    var present = 0;
    var excused = 0;
    var absent = 0;

    for (final session in sessions) {
      final snapshot = session.id == null ? null : bySession[session.id]?[studentCode];
      if (snapshot == null) {
        absent++;
      } else if (snapshot.excused) {
        excused++;
      } else {
        present++;
      }
    }

    return StudentReportStat(
      studentCode: studentCode,
      studentName: studentName,
      presentCount: present,
      absentCount: absent,
      excusedCount: excused,
    );
  }
}
