import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/validators.dart';

const List<String> _periods = ['2025-1', '2025-2', '2026-1'];

class RegisterCourseScreen extends StatefulWidget {
  const RegisterCourseScreen({super.key});

  @override
  State<RegisterCourseScreen> createState() => _RegisterCourseScreenState();
}

class _RegisterCourseScreenState extends State<RegisterCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _groupController = TextEditingController();
  final _roomController = TextEditingController();
  final _studentsController = TextEditingController();

  String _period = _periods.first;
  final Set<int> _days = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _showDaysError = false;
  bool _showTimeError = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _groupController.dispose();
    _roomController.dispose();
    _studentsController.dispose();
    super.dispose();
  }

  String _periodLabel(String period) {
    final parts = period.split('-');
    final semester = parts[1] == '1' ? 'Primer' : 'Segundo';
    return '${parts[0]} - $semester Semestre ($period)';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _showTimeError = false;
    });
  }

  Future<void> _handleSubmit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() {
      _showDaysError = _days.isEmpty;
      _showTimeError = _toMinutes(_endTime) <= _toMinutes(_startTime);
    });
    if (!formValid || _showDaysError || _showTimeError) return;

    final teacherUid = AuthService.instance.currentUser?.uid;
    if (teacherUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una sesión activa')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final teacher = await AuthService.instance.getCurrentAppUser();

    final course = Course(
      teacherUid: teacherUid,
      teacherName: teacher?.fullName,
      name: _nameController.text.trim(),
      code: _codeController.text.trim().toUpperCase(),
      group: _groupController.text.trim(),
      room: _roomController.text.trim(),
      period: _period,
      days: Set.of(_days),
      startTime: _startTime,
      endTime: _endTime,
      students: int.tryParse(_studentsController.text) ?? 0,
    );

    try {
      await CourseRepository.instance.createCourse(course);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar el curso. Intenta nuevamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: 13, color: AppColors.secondary),
                      SizedBox(width: 6),
                      Text('Gestión Docente',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Registrar Nuevo Curso',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completa la información básica para dar de alta la asignatura.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _buildGeneralSection(),
                const SizedBox(height: 16),
                _buildScheduleSection(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                          )
                        : const Icon(Icons.add_circle_outline, size: 20),
                    label: Text(
                      _isSubmitting ? 'Creando curso...' : 'Crear Curso',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSection() {
    return _section(
      icon: Icons.menu_book_outlined,
      title: 'Información General',
      children: [
        _label('Nombre de la Asignatura'),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'ej. Cálculo Diferencial',
            prefixIcon: Icon(Icons.book_outlined),
          ),
          validator: (v) => Validators.required(v, 'Ingresa el nombre de la asignatura'),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Código / NRC'),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'MAT-204',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (v) => Validators.required(v, 'Ingresa el código'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Grupo / Sección'),
                  TextFormField(
                    controller: _groupController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Grupo 01',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    validator: (v) => Validators.required(v, 'Ingresa el grupo'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Periodo Académico'),
        DropdownButtonFormField<String>(
          initialValue: _period,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today_outlined)),
          items: [
            for (final p in _periods) DropdownMenuItem(value: p, child: Text(_periodLabel(p))),
          ],
          onChanged: (v) => setState(() => _period = v ?? _period),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return _section(
      icon: Icons.access_time,
      title: 'Ubicación y Frecuencia',
      children: [
        _label('Aula / Espacio Físico'),
        TextFormField(
          controller: _roomController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'ej. Edificio A - Aula 302',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          validator: (v) => Validators.required(v, 'Ingresa el aula'),
        ),
        const SizedBox(height: 14),
        _label('Días de Clase'),
        Row(
          children: [
            for (var i = 0; i < weekdayInitials.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _dayChip(i + 1, weekdayInitials[i])),
            ],
          ],
        ),
        if (_showDaysError) _errorText('Selecciona al menos un día'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _timeField('Hora Inicio', _startTime, () => _pickTime(isStart: true))),
            const SizedBox(width: 12),
            Expanded(child: _timeField('Hora Término', _endTime, () => _pickTime(isStart: false))),
          ],
        ),
        if (_showTimeError) _errorText('La hora de término debe ser posterior a la de inicio'),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('Cupos / Estudiantes Estimados'),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Opcional',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary)),
            ),
          ],
        ),
        TextFormField(
          controller: _studentsController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'ej. 35 estudiantes',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
      ],
    );
  }

  Widget _section({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _dayChip(int day, String label) {
    final selected = _days.contains(day);
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          selected ? _days.remove(day) : _days.add(day);
          _showDaysError = false;
        }),
        child: SizedBox(
          height: 42,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 20, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(Course.formatTime(time), style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.error)),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
    );
  }
}
