import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../models/student_attendance_record.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../services/student_attendance_repository.dart';
import '../../theme/app_colors.dart';

const double _minAttendanceRate = 0.8;

/// "Mi Reporte": cumplimiento general, distribución y el detalle sesión por sesión.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<Course> _courses = const [];
  List<StudentAttendanceRecord> _records = const [];
  bool _isLoading = true;
  String _selectedCourseId = 'all';
  String? _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final user = await AuthService.instance.getCurrentAppUser();
    final studentCode = user?.studentCode;
    if (studentCode == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final courses = await CourseRepository.instance.fetchCoursesForStudentCode(studentCode);
    final records = await StudentAttendanceRepository.instance.fetchRecords(
      studentCode: studentCode,
      enrolledCourses: courses,
    );

    if (!mounted) return;
    setState(() {
      _courses = courses;
      _records = records;
      _selectedPeriod ??= courses.isEmpty ? null : courses.first.period;
      _isLoading = false;
    });
  }

  List<String> get _periods => _courses.map((c) => c.period).toSet().toList()..sort();

  List<StudentAttendanceRecord> get _periodRecords {
    if (_selectedPeriod == null) return _records;
    return _records.where((r) => r.period == _selectedPeriod).toList();
  }

  List<StudentAttendanceRecord> get _filteredRecords {
    final base = _periodRecords;
    if (_selectedCourseId == 'all') return base;
    return base.where((r) => r.courseId == _selectedCourseId).toList();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad próximamente disponible')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodRecords = _periodRecords;
    final present = periodRecords.where((r) => r.isPresent).length;
    final excused = periodRecords.where((r) => r.isExcused).length;
    final total = periodRecords.length;
    final absent = total - present - excused;
    final rate = total == 0 ? 0.0 : present / total;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mi Reporte'),
        actions: [
          if (_periods.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  icon: const Icon(Icons.expand_more, size: 18),
                  items: [
                    for (final p in _periods) DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: (v) => setState(() => _selectedPeriod = v),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildSummaryCard(rate, present, absent, excused),
                    const SizedBox(height: 16),
                    _buildDistributionCard(present, absent, excused, total),
                    const SizedBox(height: 20),
                    _buildFilterRow(total),
                    const SizedBox(height: 12),
                    if (_filteredRecords.isEmpty)
                      _buildEmptyState()
                    else
                      for (final record in _filteredRecords) ...[
                        _buildRecordCard(record),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 8),
                    _buildDownloadButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(double rate, int present, int absent, int excused) {
    final percent = (rate * 100).round();
    final inRegla = rate >= _minAttendanceRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x33003EA8), blurRadius: 14, offset: Offset(0, 6))],
      ),
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
                    const Text('CUMPLIMIENTO GENERAL',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryFixed, letterSpacing: 0.4)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$percent%',
                            style: const TextStyle(color: AppColors.onPrimary, fontSize: 30, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const Text('asistencia', style: TextStyle(color: AppColors.primaryFixed, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: inRegla ? AppColors.tertiaryContainer.withValues(alpha: 0.85) : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(inRegla ? Icons.verified : Icons.warning_amber,
                              size: 14, color: inRegla ? AppColors.onTertiaryContainer : AppColors.onErrorContainer),
                          const SizedBox(width: 6),
                          Text(
                            inRegla ? 'En regla (Mín. 80%)' : 'Por debajo del mínimo (80%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: inRegla ? AppColors.onTertiaryContainer : AppColors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: rate,
                        strokeWidth: 6,
                        backgroundColor: const Color(0x33FFFFFF),
                        valueColor: const AlwaysStoppedAnimation(AppColors.tertiaryFixed),
                      ),
                    ),
                    const Icon(Icons.school, color: AppColors.tertiaryFixed, size: 24),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('$present', 'Presentes', AppColors.tertiaryFixed)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('$absent', 'Ausencias', AppColors.errorContainer)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('$excused', 'Justificadas', AppColors.primaryFixed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(value, style: const TextStyle(color: AppColors.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.primaryFixed, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(int present, int absent, int excused, int total) {
    final marginRemaining = total == 0 ? 0 : (present / _minAttendanceRate - total).floor().clamp(0, 999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribución de Asistencias', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          const Text('Estadística acumulada del período seleccionado',
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 14),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  if (present > 0) Expanded(flex: present, child: Container(height: 10, color: AppColors.tertiaryContainer)),
                  if (absent > 0) Expanded(flex: absent, child: Container(height: 10, color: AppColors.error)),
                  if (excused > 0) Expanded(flex: excused, child: Container(height: 10, color: AppColors.secondary)),
                ],
              ),
            )
          else
            Container(height: 10, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          _legendRow('Presentes', present, total, AppColors.tertiaryContainer),
          const SizedBox(height: 8),
          _legendRow('Ausencias', absent, total, AppColors.error),
          const SizedBox(height: 8),
          _legendRow('Justificadas', excused, total, AppColors.secondary),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Margen de inasistencias restantes',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(
                        total == 0
                            ? 'Aún no tienes sesiones registradas este período.'
                            : '$marginRemaining clases permitidas antes de caer debajo del mínimo (80%).',
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0 : (value / total * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text('($pct%)', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Registros por Materia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${_periodRecords.length} sesiones en total',
                style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('all', 'Todos'),
              for (final course in _courses)
                if (course.id != null) _filterChip(course.id!, course.name),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String id, String label) {
    final selected = _selectedCourseId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCourseId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onSecondary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.fact_check_outlined, size: 36, color: AppColors.outline),
          const SizedBox(height: 10),
          const Text('Sin registros todavía', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Aquí aparecerá tu historial cuando tus docentes cierren sesiones de asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(StudentAttendanceRecord record) {
    final dateLabel = _formatDate(record.date);
    final (badgeBg, badgeDot, badgeFg, badgeLabel) = switch (record.status) {
      StudentAttendanceStatus.present => (
          AppColors.tertiaryContainer.withValues(alpha: 0.18),
          AppColors.tertiaryContainer,
          AppColors.tertiaryContainer,
          'Presente',
        ),
      StudentAttendanceStatus.excused => (
          AppColors.surfaceContainerHigh,
          AppColors.secondary,
          AppColors.secondary,
          'Justificada',
        ),
      StudentAttendanceStatus.absent => (
          AppColors.errorContainer,
          AppColors.error,
          AppColors.onErrorContainer,
          'Ausente',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
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
                    Text(record.courseName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: badgeDot, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(badgeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.meeting_room, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(record.courseRoom, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              switch (record.status) {
                StudentAttendanceStatus.present => const Text(
                    'Validado por código',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                  ),
                StudentAttendanceStatus.excused => const Text(
                    'Justificada por tu docente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                  ),
                StudentAttendanceStatus.absent => const Text(
                    'Sin justificación · pídele a tu docente que la marque',
                    style: TextStyle(fontSize: 11, color: AppColors.error),
                  ),
              },
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHighest,
              foregroundColor: AppColors.primary,
              elevation: 0,
            ),
            onPressed: _showComingSoon,
            icon: const Icon(Icons.file_download, size: 20),
            label: const Text('Descargar Reporte Personal (PDF)', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'La exportación a PDF estará disponible próximamente.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}
