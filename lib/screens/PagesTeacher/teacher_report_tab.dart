import 'package:flutter/material.dart';

import '../../models/attendance_session.dart';
import '../../models/course.dart';
import '../../models/course_attendance_report.dart';
import '../../services/auth_service.dart';
import '../../services/course_attendance_report_repository.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';

const _monthShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// Contenido del tab "Reportes" del home del docente: cumplimiento general y
/// detalle por clase, por curso.
class TeacherReportTab extends StatefulWidget {
  const TeacherReportTab({super.key});

  @override
  State<TeacherReportTab> createState() => _TeacherReportTabState();
}

class _TeacherReportTabState extends State<TeacherReportTab> {
  int _viewIndex = 0; // 0 = General, 1 = Por Clase
  String? _selectedCourseId;
  String? _selectedSessionId;
  Future<CourseAttendanceReport>? _reportFuture;

  void _selectCourse(String courseId) {
    if (courseId == _selectedCourseId) return;
    setState(() {
      _selectedCourseId = courseId;
      _selectedSessionId = null;
      _reportFuture = CourseAttendanceReportRepository.instance.fetchReport(courseId);
    });
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad próximamente disponible')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherUid = AuthService.instance.currentUser?.uid;
    if (teacherUid == null) {
      return const Center(child: Text('Inicia sesión para continuar', style: TextStyle(color: AppColors.onSurfaceVariant)));
    }

    return StreamBuilder<List<Course>>(
      stream: CourseRepository.instance.watchTeacherCourses(teacherUid),
      builder: (context, coursesSnapshot) {
        final courses = coursesSnapshot.data ?? const <Course>[];
        if (courses.isEmpty) {
          return coursesSnapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : _buildNoCourses();
        }

        _selectedCourseId ??= courses.first.id;
        if (_reportFuture == null && _selectedCourseId != null) {
          _reportFuture = CourseAttendanceReportRepository.instance.fetchReport(_selectedCourseId!);
        }
        final selectedCourse = courses.firstWhere((c) => c.id == _selectedCourseId, orElse: () => courses.first);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildCourseSelector(courses, selectedCourse),
            const SizedBox(height: 14),
            _buildViewTabs(),
            const SizedBox(height: 16),
            FutureBuilder<CourseAttendanceReport>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final report = snapshot.data;
                if (report == null) return const SizedBox.shrink();
                return _viewIndex == 0 ? _buildGeneralView(report) : _buildByClassView(report);
              },
            ),
            const SizedBox(height: 20),
            _buildExportButton(),
          ],
        );
      },
    );
  }

  Widget _buildNoCourses() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.bar_chart, size: 36, color: AppColors.outline),
          const SizedBox(height: 10),
          const Text('Registra un curso para ver reportes', style: TextStyle(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCourseSelector(List<Course> courses, Course selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Curso seleccionado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
          ]),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selected.id,
              items: [
                for (final c in courses)
                  if (c.id != null) DropdownMenuItem(value: c.id, child: Text('${c.name} · Gpo ${c.group}')),
              ],
              onChanged: (v) {
                if (v != null) _selectCourse(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: _viewTab(0, Icons.insights, 'General')),
          Expanded(child: _viewTab(1, Icons.event_note, 'Por Clase')),
        ],
      ),
    );
  }

  Widget _viewTab(int index, IconData icon, String label) {
    final selected = _viewIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _viewIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ----------------------------- Vista General -----------------------------

  Widget _buildGeneralView(CourseAttendanceReport report) {
    if (report.sessions.isEmpty) return _buildEmptyReport();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _metricCard(Icons.check_circle, AppColors.tertiaryContainer, report.presentTotal, report.presentRate, 'Presentes')),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(Icons.cancel, AppColors.error, report.absentTotal, report.absentRate, 'Ausentes')),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(Icons.assignment_late, AppColors.secondary, report.excusedTotal, report.excusedRate, 'Con excusa')),
          ],
        ),
        const SizedBox(height: 16),
        _buildDistributionCard(report),
        const SizedBox(height: 20),
        _buildRiskSection(report),
      ],
    );
  }

  Widget _metricCard(IconData icon, Color color, int value, double rate, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color),
              Text('${(rate * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(CourseAttendanceReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Distribución global', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Total: ${report.studentStats.length} alumnos inscritos',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(999)),
                child: Text('Promedio ${(report.presentRate * 100).round()}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                if (report.presentTotal > 0) Expanded(flex: report.presentTotal, child: Container(height: 10, color: AppColors.tertiaryContainer)),
                if (report.absentTotal > 0) Expanded(flex: report.absentTotal, child: Container(height: 10, color: AppColors.error)),
                if (report.excusedTotal > 0) Expanded(flex: report.excusedTotal, child: Container(height: 10, color: AppColors.secondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legendDot('Presentes', report.presentRate, AppColors.tertiaryContainer),
              _legendDot('Ausentes', report.absentRate, AppColors.error),
              _legendDot('Excusas', report.excusedRate, AppColors.secondary),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Asistencia por últimas sesiones', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final session in report.recentSessions) ...[
                Expanded(child: _sessionBar(session)),
                if (session != report.recentSessions.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(String label, double rate, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label (${(rate * 100).round()}%)', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _sessionBar(AttendanceSession session) {
    final total = session.totalEnrolled == 0 ? 1 : session.totalEnrolled;
    final rate = session.presentCount / total;
    return Column(
      children: [
        SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: rate.clamp(0.04, 1.0),
                    child: Container(
                      width: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('${session.date.day} ${_monthShort[session.date.month - 1]}',
            style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildRiskSection(CourseAttendanceReport report) {
    final atRisk = report.studentsAtRisk();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Atención requerida', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Text('Umbral crítico (<75%)', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (atRisk.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(14)),
            child: const Text('Nadie está por debajo del umbral crítico. 🎉', style: TextStyle(color: AppColors.onSurfaceVariant)),
          )
        else
          for (final student in atRisk) ...[
            _riskRow(student),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _riskRow(StudentReportStat student) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.errorContainer,
            child: Text(student.initials, style: const TextStyle(color: AppColors.onErrorContainer, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${student.absentCount} faltas sin justificar · ${student.excusedCount} justificadas',
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(999)),
            child: Text('${(student.attendanceRate * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Vista Por Clase -----------------------------

  Widget _buildByClassView(CourseAttendanceReport report) {
    if (report.sessions.isEmpty) return _buildEmptyReport();

    _selectedSessionId ??= report.sessions.first.id;
    final session = report.sessions.firstWhere((s) => s.id == _selectedSessionId, orElse: () => report.sessions.first);
    final attendeesByCode = report.sessionAttendeeNamesById[session.id] ?? const {};
    final present = session.presentCount;
    final excused = session.excusedCount;
    final absent = session.absentCount;
    final total = session.totalEnrolled == 0 ? 1 : session.totalEnrolled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seleccionar clase', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2)),
          ]),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: session.id,
              items: [
                for (final s in report.sessions)
                  if (s.id != null)
                    DropdownMenuItem(value: s.id, child: Text('${s.date.day} ${_monthShort[s.date.month - 1]} de ${s.date.year}')),
              ],
              onChanged: (v) => setState(() => _selectedSessionId = v),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _metricCard(Icons.check_circle, AppColors.tertiaryContainer, present, present / total, 'Presentes')),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(Icons.cancel, AppColors.error, absent, absent / total, 'Ausentes')),
            const SizedBox(width: 8),
            Expanded(child: _metricCard(Icons.assignment_late, AppColors.secondary, excused, excused / total, 'Con excusa')),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              if (present > 0) Expanded(flex: present, child: Container(height: 10, color: AppColors.tertiaryContainer)),
              if (absent > 0) Expanded(flex: absent, child: Container(height: 10, color: AppColors.error)),
              if (excused > 0) Expanded(flex: excused, child: Container(height: 10, color: AppColors.secondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Lista de asistencia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        for (final student in report.studentStats) ...[
          _classStudentRow(student, attendeesByCode[student.studentCode]),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _classStudentRow(StudentReportStat student, AttendeeSnapshot? snapshot) {
    final (badgeBg, badgeFg, statusLabel, detail) = switch (snapshot) {
      null => (AppColors.errorContainer, AppColors.onErrorContainer, 'Ausente', 'Sin registro'),
      AttendeeSnapshot(excused: true) => (AppColors.secondaryFixed, AppColors.onSecondaryFixed, 'Con excusa', 'Justificada por el docente'),
      AttendeeSnapshot(excused: false, :final checkedInAt) => (
          AppColors.surfaceContainer,
          AppColors.tertiaryContainer,
          'Presente',
          'Reg: ${_formatTime(checkedInAt)}',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceContainer,
            child: Text(student.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
            child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReport() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 32, color: AppColors.outline),
          SizedBox(height: 10),
          Text('Aún no hay sesiones cerradas para este curso', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text(
            'El reporte se completará cuando cierres tu primera sesión de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _showComingSoon,
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Exportar Reporte (PDF / Excel)', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La exportación estará disponible próximamente.',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
