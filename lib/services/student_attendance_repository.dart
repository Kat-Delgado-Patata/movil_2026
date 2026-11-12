import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_session.dart';
import '../models/course.dart';
import '../models/live_attendee.dart';
import '../models/student_attendance_record.dart';
import 'attendance_session_repository.dart';

/// Arma el historial personal de un estudiante cruzando las sesiones cerradas
/// de cada curso con la subcolección real de quiénes marcaron presente.
class StudentAttendanceRepository {
  StudentAttendanceRepository._();
  static final StudentAttendanceRepository instance = StudentAttendanceRepository._();

  Future<List<StudentAttendanceRecord>> fetchRecords({
    required String studentCode,
    required List<Course> enrolledCourses,
  }) async {
    final records = <StudentAttendanceRecord>[];

    for (final course in enrolledCourses) {
      if (course.id == null) continue;
      final sessions = await AttendanceSessionRepository.instance.fetchCourseSessions(course.id!);

      for (final session in sessions) {
        final record = await _buildRecord(course, session, studentCode);
        records.add(record);
      }
    }

    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  Future<StudentAttendanceRecord> _buildRecord(
    Course course,
    AttendanceSession session,
    String studentCode,
  ) async {
    DateTime recordDate = session.date;
    var status = StudentAttendanceStatus.absent;

    if (session.liveSessionId != null) {
      final attendeeDoc = await FirebaseFirestore.instance
          .collection('liveSessions')
          .doc(session.liveSessionId)
          .collection('attendees')
          .doc(studentCode)
          .get();
      if (attendeeDoc.exists) {
        final data = attendeeDoc.data()!;
        status = AttendeeStatusX.fromValue(data['status'] as String?) == AttendeeStatus.excused
            ? StudentAttendanceStatus.excused
            : StudentAttendanceStatus.present;
        final checkedInAt = data['checkedInAt'] as Timestamp?;
        if (checkedInAt != null) recordDate = checkedInAt.toDate();
      }
    }

    return StudentAttendanceRecord(
      courseId: course.id!,
      courseName: course.name,
      courseRoom: course.room,
      period: course.period,
      date: recordDate,
      status: status,
    );
  }
}
