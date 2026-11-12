import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/attendance_session.dart';
import '../../models/course.dart';
import '../../services/attendance_session_repository.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';

const _weekdayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _monthShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Contenido del tab "Historial" del home del docente: lista cronológica de
/// sesiones de asistencia ya cerradas, filtrable por curso.
class AttendanceHistoryTab extends StatefulWidget {
  const AttendanceHistoryTab({super.key});

  @override
  State<AttendanceHistoryTab> createState() => _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends State<AttendanceHistoryTab> {
  String _selectedCourseId = 'all';

  @override
  Widget build(BuildContext context) {
    final teacherUid = AuthService.instance.currentUser?.uid;
    if (teacherUid == null) {
      return const Center(child: Text('Inicia sesión para ver tu historial.'));
    }

    return StreamBuilder<List<Course>>(
      stream: CourseRepository.instance.watchTeacherCourses(teacherUid),
      builder: (context, coursesSnapshot) {
        final courses = coursesSnapshot.data ?? const <Course>[];
        final coursesById = {for (final c in courses) if (c.id != null) c.id!: c};

        return StreamBuilder<List<AttendanceSession>>(
          stream: AttendanceSessionRepository.instance.watchTeacherSessions(teacherUid),
          builder: (context, sessionsSnapshot) {
            final allSessions = sessionsSnapshot.data ?? const <AttendanceSession>[];
            final sessions = _selectedCourseId == 'all'
                ? allSessions
                : allSessions.where((s) => s.courseId == _selectedCourseId).toList();
            final isLoading = coursesSnapshot.connectionState == ConnectionState.waiting ||
                sessionsSnapshot.connectionState == ConnectionState.waiting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildFilterPills(courses),
                const SizedBox(height: 16),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (sessions.isEmpty)
                  _buildEmptyState()
                else
                  for (final session in sessions) ...[
                    _buildSessionCard(session, coursesById[session.courseId]),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Historial de Asistencias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
          child: const Text('Docente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryContainer)),
        ),
      ],
    );
  }

  Widget _buildFilterPills(List<Course> courses) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterPill('all', 'Todos'),
          for (final course in courses)
            if (course.id != null) _filterPill(course.id!, course.name),
        ],
      ),
    );
  }

  Widget _filterPill(String courseId, String label) {
    final selected = _selectedCourseId == courseId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCourseId = courseId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: const Icon(Icons.event_busy, color: AppColors.outline, size: 24),
          ),
          const SizedBox(height: 10),
          const Text('Sin registros para este curso', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text(
            'El historial se actualizará tras la próxima sesión.',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(AttendanceSession session, Course? course) {
    final rate = session.attendanceRate;
    final Color badgeBg;
    final Color badgeFg;
    final Color dotColor;
    if (rate >= 85) {
      badgeBg = AppColors.tertiaryFixed;
      badgeFg = AppColors.onTertiaryContainer;
      dotColor = AppColors.onTertiaryContainer;
    } else if (rate >= 70) {
      badgeBg = AppColors.surfaceContainerHigh;
      badgeFg = AppColors.onSurfaceVariant;
      dotColor = AppColors.secondary;
    } else {
      badgeBg = AppColors.errorContainer;
      badgeFg = AppColors.onErrorContainer;
      dotColor = AppColors.error;
    }

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, AppRoutes.sessionDetail, arguments: session),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatSessionDate(session.date),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course?.name ?? 'Curso eliminado',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        if (course != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${course.scheduleRange} · ${course.room}',
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          '${rate.round()}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeFg),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${session.presentCount} / ${session.totalEnrolled} alumnos presentes',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Text(
                    '${session.absentCount} ausencias',
                    style: const TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final label = '${date.day} ${_monthShort[date.month - 1]}';
    if (diff == 0) return 'Hoy, $label';
    if (diff == 1) return 'Ayer, $label';
    final weekday = _weekdayNames[date.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)}, $label';
  }
}
