import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/course.dart';
import '../../services/live_session_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import 'live_session.dart';

/// Opciones de duración del código; `null` significa sin límite.
const List<int?> _durationOptions = [10, 15, 20, null];

class StartSessionScreen extends StatefulWidget {
  const StartSessionScreen({super.key});

  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  int? _durationMinutes = 15;
  bool _isStarting = false;

  Course get _course => ModalRoute.of(context)!.settings.arguments as Course;

  Future<void> _openSession() async {
    setState(() => _isStarting = true);
    try {
      final startedCourse = await LiveSessionRepository.instance.startSession(
        _course,
        durationMinutes: _durationMinutes,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.liveSession,
        arguments: LiveSessionArgs(course: startedCourse, durationMinutes: _durationMinutes),
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: () => LocationService.instance.openLocationSettings(),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la sesión. Intenta nuevamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = _course;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.co_present_outlined, size: 14, color: AppColors.secondary),
                  SizedBox(width: 6),
                  Text(
                    'CONFIGURACIÓN DE AULA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Iniciar Sesión de Asistencia',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Establece los parámetros para habilitar el registro en tiempo real.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _buildCourseCard(course),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Duración del Código', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        _durationMinutes == null ? 'Sin expiración' : 'Expiración auto',
                        style: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < _durationOptions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _durationChip(_durationOptions[i])),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Debes estar dentro del aula: se usará tu ubicación actual para verificar '
                        'que los estudiantes estén cerca al registrar asistencia.',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isStarting ? null : _openSession,
                  icon: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                        )
                      : const Icon(Icons.play_circle_outline, size: 20),
                  label: Text(
                    _isStarting ? 'Abriendo sesión...' : 'Generar Código y Abrir Sesión',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainer,
                    foregroundColor: AppColors.onSurfaceVariant,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isStarting ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.functions, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Activa hoy',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(course.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.verified_outlined, color: AppColors.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _infoTile(Icons.groups_outlined, 'Grupo', course.group)),
              const SizedBox(width: 10),
              Expanded(child: _infoTile(Icons.meeting_room_outlined, 'Ubicación', course.room)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationChip(int? minutes) {
    final selected = _durationMinutes == minutes;
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _durationMinutes = minutes),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              minutes == null ? 'Sin límite' : '$minutes min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
