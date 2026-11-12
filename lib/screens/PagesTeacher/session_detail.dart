import 'package:flutter/material.dart';

import '../../models/attendance_session.dart';
import '../../models/course.dart';
import '../../models/course_student.dart';
import '../../models/live_attendee.dart';
import '../../services/course_repository.dart';
import '../../services/course_student_repository.dart';
import '../../services/live_session_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/roll_call_list.dart';

/// Detalle de una sesión de asistencia ya cerrada: permite corregirla a mano
/// (por ejemplo, justificar una ausencia reportada después de la clase).
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key});

  Future<void> _setStatus(
    BuildContext context,
    Course course,
    AttendanceSession session,
    CourseStudent student,
    AttendeeStatus? status,
  ) async {
    try {
      if (status == null) {
        await LiveSessionRepository.instance.clearStatus(course, student.code, sessionId: session.liveSessionId);
      } else {
        await LiveSessionRepository.instance.setManualStatus(
          course,
          studentCode: student.code,
          studentName: student.fullName,
          status: status,
          sessionId: session.liveSessionId,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado de este estudiante')),
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final session = ModalRoute.of(context)!.settings.arguments as AttendanceSession;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detalle de Sesión'),
      ),
      body: SafeArea(
        child: StreamBuilder<Course?>(
          stream: CourseRepository.instance.watchCourse(session.courseId),
          builder: (context, courseSnapshot) {
            final course = courseSnapshot.data;
            if (course == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (session.liveSessionId == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Esta sesión es muy antigua y no guarda el detalle por estudiante, así que no se puede editar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(session.date)} · ${course.room}',
                          style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_calendar, size: 18, color: AppColors.secondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Puedes corregir esta sesión aunque ya haya terminado, por ejemplo para '
                            'justificar una ausencia reportada después de la clase.',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<CourseStudent>>(
                      stream: CourseStudentRepository.instance.watchActiveStudents(session.courseId),
                      builder: (context, rosterSnapshot) {
                        final roster = rosterSnapshot.data ?? const <CourseStudent>[];
                        return StreamBuilder<List<LiveAttendee>>(
                          stream: LiveSessionRepository.instance.watchAttendees(session.liveSessionId!),
                          builder: (context, attendeesSnapshot) {
                            final attendeesByCode = {
                              for (final a in attendeesSnapshot.data ?? const <LiveAttendee>[]) a.studentCode: a,
                            };
                            return RollCallList(
                              roster: roster,
                              attendeesByCode: attendeesByCode,
                              onSetStatus: (student, status) => _setStatus(context, course, session, student, status),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
