import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/course.dart';
import '../../models/course_student.dart';
import '../../services/course_repository.dart';
import '../../services/course_student_repository.dart';
import '../../theme/app_colors.dart';

/// Detalle y gestión de un curso: métricas, ciclo de vida (finalizar/eliminar) y accesos rápidos.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  bool _isUpdatingStatus = false;
  bool _isDeleting = false;

  String get _courseId => ModalRoute.of(context)!.settings.arguments as String;

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad próximamente disponible')),
    );
  }

  Future<void> _toggleStatus(Course course) async {
    final newStatus = course.status == CourseStatus.active ? CourseStatus.finished : CourseStatus.active;
    setState(() => _isUpdatingStatus = true);
    try {
      await CourseRepository.instance.setStatus(course.id!, newStatus);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado del curso')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _confirmDelete(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar curso?'),
        content: Text(
          'Esta acción borrará definitivamente "${course.name}" y no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await CourseRepository.instance.deleteCourse(course.id!);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el curso')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Course?>(
      stream: CourseRepository.instance.watchCourse(_courseId),
      builder: (context, snapshot) {
        final course = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalle del Curso'),
                if (course != null)
                  Text(
                    '${course.name} · ${course.room}',
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear QR',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usa "Iniciar Nueva Sesión" para generar el código')),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filtrar',
                onPressed: _showComingSoon,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.person, color: AppColors.onPrimary, size: 18),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : course == null
                    ? const Center(
                        child: Text('Este curso ya no existe.', style: TextStyle(color: AppColors.onSurfaceVariant)),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(course),
                            const SizedBox(height: 12),
                            _buildMetrics(course),
                            const SizedBox(height: 12),
                            _buildQuickActions(course),
                            const SizedBox(height: 12),
                            _buildLifecyclePanel(course),
                            const SizedBox(height: 12),
                            _buildPrimaryActions(course),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _buildHero(Course course) {
    final isActive = course.status == CourseStatus.active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${course.code} · Grupo ${course.group} · ${course.room}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.tertiaryFixed : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.tertiary : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Curso Activo' : 'Finalizado (Solo Lectura)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.onTertiaryFixed : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(course.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            'Periodo Académico ${course.period}${course.faculty != null ? ' · ${course.faculty}' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_daysLabel(course.days)} · ${course.scheduleRange}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(course.room, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _daysLabel(Set<int> days) {
    const names = {1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves', 5: 'Viernes', 6: 'Sábado', 7: 'Domingo'};
    final sorted = days.toList()..sort();
    return sorted.map((d) => names[d] ?? '').join(' y ');
  }

  Widget _buildMetrics(Course course) {
    return StreamBuilder<List<CourseStudent>>(
      stream: CourseStudentRepository.instance.watchActiveStudents(course.id!),
      builder: (context, snapshot) {
        final enrolled = snapshot.data?.length;
        return Row(
          children: [
            Expanded(
              child: _metricTile(
                Icons.group,
                enrolled == null ? '…' : '$enrolled',
                'Matriculados',
                AppColors.primaryFixed,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricTile(
                Icons.event_available,
                '${course.sessionsCount}',
                'Sesiones',
                AppColors.surfaceContainerHighest,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricTile(
                Icons.percent,
                // Aún no existen registros de asistencia (eso llega con "Registrar asistencia" del estudiante).
                '—',
                'Asistencia',
                AppColors.tertiaryFixed,
                AppColors.tertiary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricTile(IconData icon, String value, String label, Color badgeColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Course course) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            icon: Icons.badge_outlined,
            title: 'Ver Roster',
            subtitle: 'Lista de alumnos',
            onTap: () => Navigator.pushNamed(context, AppRoutes.courseRoster, arguments: course.id),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _quickAction(
            icon: Icons.history_edu,
            title: 'Historial',
            subtitle: 'Clases dictadas',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El historial de asistencia estará disponible próximamente')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifecyclePanel(Course course) {
    final isActive = course.status == CourseStatus.active;
    final progress = course.inactivityMonths / Course.monthsRequiredForDeletion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.autorenew, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Ciclo de Vida y Estado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fact_check, size: 18, color: AppColors.secondary),
                        SizedBox(width: 8),
                        Text('Finalizar Semestre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    _isUpdatingStatus
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: !isActive,
                            activeThumbColor: AppColors.surfaceContainerLowest,
                            activeTrackColor: AppColors.secondary,
                            onChanged: (_) => _toggleStatus(course),
                          ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Al finalizar el período académico, el curso entra en modo solo lectura para auditoría, consulta de actas y reclamos.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: AppColors.outline),
                  SizedBox(width: 6),
                  Text('Eliminación Definitiva', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '${Course.monthsRequiredForDeletion} Meses Req.',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActive ? '0 meses de inactividad' : '${course.inactivityMonths} meses de inactividad',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              Text(
                'Meta: ${Course.monthsRequiredForDeletion} meses',
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 18, color: AppColors.outline),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Por política de acreditación institucional, los cursos requieren 1 año inactivo antes de permitir su borrado manual para preservar registros de asistencia.',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildDeleteButton(course),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(Course course) {
    final canDelete = course.canBeDeleted;
    final isActive = course.status == CourseStatus.active;

    String label;
    IconData icon;
    if (canDelete) {
      label = 'Eliminar Curso';
      icon = Icons.delete_outline;
    } else if (isActive) {
      label = 'Eliminar Curso';
      icon = Icons.lock;
    } else {
      label = 'Eliminación manual en ${course.monthsUntilDeletable} meses';
      icon = Icons.lock_clock;
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canDelete ? AppColors.errorContainer : AppColors.surfaceContainer,
          foregroundColor: canDelete ? AppColors.onErrorContainer : AppColors.outline,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (canDelete && !_isDeleting) ? () => _confirmDelete(course) : null,
        child: _isDeleting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }

  Widget _buildPrimaryActions(Course course) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.startSession, arguments: course),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 22),
                SizedBox(width: 8),
                Text('Iniciar Nueva Sesión de Asistencia', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: const BorderSide(color: Colors.transparent),
              backgroundColor: AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _showComingSoon,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: 8),
                Text('Descargar Reporte / Acta Final', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
