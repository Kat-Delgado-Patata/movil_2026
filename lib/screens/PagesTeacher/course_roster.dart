import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../models/course_student.dart';
import '../../models/roster_import_row.dart';
import '../../services/course_repository.dart';
import '../../services/course_student_repository.dart';
import '../../services/roster_excel_service.dart';
import '../../theme/app_colors.dart';

/// Lista de estudiantes matriculados en un curso: buscar, agregar y dar de baja (sin perder historial).
class CourseRosterScreen extends StatefulWidget {
  const CourseRosterScreen({super.key});

  @override
  State<CourseRosterScreen> createState() => _CourseRosterScreenState();
}

class _CourseRosterScreenState extends State<CourseRosterScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isImporting = false;
  bool _isExporting = false;

  String get _courseId => ModalRoute.of(context)!.settings.arguments as String;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad próximamente disponible')),
    );
  }

  List<CourseStudent> _filter(List<CourseStudent> students) {
    if (_query.isEmpty) return students;
    return students
        .where((s) => s.fullName.toLowerCase().contains(_query) || s.code.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _openAddStudentDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StudentFormDialog(courseId: _courseId),
    );
  }

  Future<void> _openEditStudentDialog(CourseStudent student) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StudentFormDialog(courseId: _courseId, student: student),
    );
  }

  Future<void> _openStudentOptions(CourseStudent student) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Text(student.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Cód: ${student.code}', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.history, color: AppColors.primary),
                  title: const Text('Ver historial de asistencias'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showComingSoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.outline),
                  title: const Text('Editar información'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openEditStudentDialog(student);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                  title: const Text('Dar de baja del curso', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Conserva historial'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmRemove(student);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);

    RosterImportParseResult? parsed;
    try {
      parsed = await RosterExcelService.instance.pickAndParse();
    } on RosterExcelException catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo. Verifica que sea un .xlsx válido')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isImporting = false);
    if (parsed == null) return; // el usuario cerró el selector sin elegir archivo

    if (parsed.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo no tenía filas con nombre y código válidos')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Importar estudiantes?'),
        content: Text(
          'Se agregarán o actualizarán ${parsed!.rows.length} estudiantes en este curso.'
          '${parsed.skipped.isEmpty ? '' : '\n\nSe omitieron ${parsed.skipped.length} fila(s) con datos incompletos.'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Importar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      await CourseStudentRepository.instance.importRows(_courseId, parsed.rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${parsed.rows.length} estudiantes importados')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo completar la importación')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _handleExport(Course course, List<CourseStudent> students) async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay estudiantes matriculados para exportar')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      await RosterExcelService.instance.exportRoster(courseName: course.name, students: students);
    } on RosterExcelException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo exportar el archivo')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _confirmRemove(CourseStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Dar de baja?'),
        content: Text('${student.fullName} saldrá de la lista activa. Su historial de asistencia se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirmed != true || student.id == null) return;

    try {
      await CourseStudentRepository.instance.removeStudent(_courseId, student.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.fullName} fue dado de baja')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo completar la acción')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Course?>(
      stream: CourseRepository.instance.watchCourse(_courseId),
      builder: (context, courseSnapshot) {
        final course = courseSnapshot.data;
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
                const Text('Lista De Estudiantes'),
                if (course != null)
                  Text(
                    '${course.name} · ${course.room}',
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.filter_list), tooltip: 'Filtrar', onPressed: _showComingSoon),
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
            child: course == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<CourseStudent>>(
                    stream: CourseStudentRepository.instance.watchActiveStudents(_courseId),
                    builder: (context, snapshot) {
                      final allStudents = snapshot.data ?? const <CourseStudent>[];
                      final students = _filter(allStudents);
                      return Stack(
                        children: [
                          ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                            children: [
                              _buildHero(course, allStudents.length),
                              const SizedBox(height: 16),
                              _buildQuickActions(course, allStudents),
                              const SizedBox(height: 12),
                              _buildSearchField(),
                              const SizedBox(height: 16),
                              _buildCountRow(students.length, allStudents.length),
                              const SizedBox(height: 10),
                              if (snapshot.connectionState == ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (students.isEmpty)
                                _buildNoResults()
                              else
                                for (final student in students) ...[
                                  _buildStudentCard(student),
                                  const SizedBox(height: 10),
                                ],
                            ],
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.extended(
                              onPressed: _openAddStudentDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Estudiante'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHero(Course course, int totalActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school, size: 14, color: AppColors.onPrimary),
                          const SizedBox(width: 6),
                          Text('Período ${course.period}',
                              style: const TextStyle(fontSize: 11, color: AppColors.onPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(course.name,
                        style: const TextStyle(color: AppColors.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Grupo ${course.group} · ${course.room}',
                        style: const TextStyle(color: AppColors.primaryFixed, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text('—', style: TextStyle(color: AppColors.tertiaryFixed, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Promedio', style: TextStyle(color: AppColors.onPrimary, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, size: 20, color: AppColors.secondaryFixed),
                    const SizedBox(width: 8),
                    Text('$totalActive Estudiantes matriculados',
                        style: const TextStyle(color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Course course, List<CourseStudent> allStudents) {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.upload_file,
            label: 'Importar',
            caption: '.xlsx',
            color: AppColors.primary,
            isLoading: _isImporting,
            onTap: _isImporting ? null : _handleImport,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionTile(
            icon: Icons.download,
            label: 'Exportar',
            caption: '.xlsx',
            color: AppColors.secondary,
            isLoading: _isExporting,
            onTap: _isExporting ? null : () => _handleExport(course, allStudents),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String caption,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(10)),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(9),
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                    Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o código...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.cancel, size: 18),
                onPressed: () => _searchController.clear(),
              ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCountRow(int visibleCount, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _query.isEmpty
              ? 'ESTUDIANTES MATRICULADOS ($totalCount)'
              : '$visibleCount REGISTROS ENCONTRADOS',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.5),
        ),
        const Row(
          children: [
            Icon(Icons.swap_vert, size: 14, color: AppColors.outline),
            SizedBox(width: 4),
            Text('Orden: Apellidos', style: TextStyle(fontSize: 11, color: AppColors.outline)),
          ],
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
            child: const Icon(Icons.person_search, size: 28, color: AppColors.outline),
          ),
          const SizedBox(height: 12),
          const Text('No se encontraron estudiantes', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Prueba buscando con otro término o código.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(CourseStudent student) {
    final percentage = student.attendancePercentage;
    final isAtRisk = percentage != null && percentage < 80;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openStudentOptions(student),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondaryFixed,
                child: Text(
                  student.initials,
                  style: const TextStyle(color: AppColors.onSecondaryFixed, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Cód: ${student.code}', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: percentage == null
                      ? AppColors.surfaceContainerHigh
                      : (isAtRisk ? AppColors.errorContainer : AppColors.tertiaryContainer),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  percentage == null ? 'Sin datos' : (isAtRisk ? '${percentage.round()}% En riesgo' : '${percentage.round()}%'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: percentage == null
                        ? AppColors.onSurfaceVariant
                        : (isAtRisk ? AppColors.error : AppColors.onTertiaryContainer),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppColors.outline),
                onPressed: () => _openStudentOptions(student),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulario para agregar o editar un estudiante del roster.
class _StudentFormDialog extends StatefulWidget {
  const _StudentFormDialog({required this.courseId, this.student});

  final String courseId;
  final CourseStudent? student;

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.student?.fullName ?? '');
  late final _codeController = TextEditingController(text: widget.student?.code ?? '');
  bool _isSubmitting = false;

  bool get _isEditing => widget.student != null;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        await CourseStudentRepository.instance.updateStudent(
          widget.courseId,
          widget.student!.id!,
          fullName: _nameController.text.trim(),
          code: _codeController.text.trim(),
        );
      } else {
        await CourseStudentRepository.instance.addStudent(
          widget.courseId,
          fullName: _nameController.text.trim(),
          code: _codeController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar al estudiante')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_add, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Editar Alumno' : 'Nuevo Alumno',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Nombre Completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Ej. Mariana Paredes'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
              ),
              const SizedBox(height: 14),
              const Text('Código Universitario', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(hintText: 'Ej. 202410881'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el código' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
