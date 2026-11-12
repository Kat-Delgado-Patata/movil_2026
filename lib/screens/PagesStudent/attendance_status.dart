import 'package:flutter/material.dart';

import '../../Routes/route.dart';
import '../../models/app_user.dart';
import '../../models/attendance_checkin.dart';
import '../../services/auth_service.dart';
import '../../services/live_session_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

/// Comprobante del último "presente" del estudiante + guía de errores comunes.
class AttendanceStatusScreen extends StatefulWidget {
  const AttendanceStatusScreen({super.key});

  @override
  State<AttendanceStatusScreen> createState() => _AttendanceStatusScreenState();
}

class _AttendanceStatusScreenState extends State<AttendanceStatusScreen> {
  int _tabIndex = 0;

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.homeStudent, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              _goHome();
            }
          },
        ),
        title: const Text('Estado de Asistencia'),
        actions: [
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSwitcher(),
              const SizedBox(height: 16),
              if (_tabIndex == 0) _buildSuccessTab() else _buildGuideTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: _tabButton(0, Icons.check_circle, 'Mi Estado')),
          Expanded(child: _tabButton(1, Icons.help_center, 'Guía de Errores')),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessTab() {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.watchCurrentAppUser(),
      builder: (context, userSnapshot) {
        final studentCode = userSnapshot.data?.studentCode;
        if (studentCode == null) {
          return _emptyState('No encontramos tu código universitario en tu perfil.');
        }
        return StreamBuilder<AttendanceCheckIn?>(
          stream: LiveSessionRepository.instance.watchLatestCheckIn(studentCode),
          builder: (context, checkInSnapshot) {
            if (checkInSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final checkIn = checkInSnapshot.data;
            if (checkIn == null) {
              return _emptyState('Aún no has registrado asistencia a ninguna clase.');
            }
            return _buildCheckInCard(checkIn);
          },
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.event_busy, size: 36, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCheckInCard(AttendanceCheckIn checkIn) {
    final date = checkIn.checkedInAt;
    final dateLabel = '${date.day} de ${_monthName(date.month)} - ${_formatTime(date)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.verified, color: AppColors.onTertiary, size: 32),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppColors.tertiaryFixed, borderRadius: BorderRadius.circular(999)),
            child: const Text('PRESENTE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.onTertiaryFixed)),
          ),
          const SizedBox(height: 10),
          const Text('¡Asistencia registrada con éxito!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text('Tu presencia ha sido confirmada en el sistema institucional.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _infoRow(Icons.school, 'Asignatura', '${checkIn.courseName} - Grupo ${checkIn.courseGroup}'),
                const SizedBox(height: 12),
                _infoRow(Icons.schedule, 'Fecha y Hora', dateLabel),
                const SizedBox(height: 12),
                _infoRow(
                  Icons.location_on,
                  'Ubicación verificada',
                  checkIn.distanceMeters == null
                      ? 'Confirmado con el código de la sesión'
                      : 'Validado por GPS (${checkIn.distanceMeters!.round()}m de distancia)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge, size: 18, color: AppColors.secondary),
                    SizedBox(width: 8),
                    Text('ID Validación', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Text(
                  '#${checkIn.validationId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _goHome,
              icon: const Icon(Icons.home, size: 20),
              label: const Text('Ir al Home', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(backgroundColor: AppColors.surfaceContainer, foregroundColor: AppColors.onSurface),
              onPressed: () => setState(() => _tabIndex = 1),
              child: const Text('Ver Guía de Errores', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resolución de Incidentes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Guía rápida de soluciones si tienes dificultades al registrar tu asistencia.',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _guideCard(
          icon: Icons.wrong_location,
          iconBg: AppColors.errorContainer,
          iconColor: AppColors.onErrorContainer,
          title: 'Fuera de rango (más de ${maxCheckInDistanceMeters.round()}m)',
          tag: 'Ubicación',
          tagBg: AppColors.errorContainer,
          tagColor: AppColors.onErrorContainer,
          description:
              'Te encuentras a más de ${maxCheckInDistanceMeters.round()} metros de donde el docente abrió la sesión. '
              'Acércate físicamente al aula e intenta de nuevo.',
        ),
        const SizedBox(height: 10),
        _guideCard(
          icon: Icons.location_disabled,
          iconBg: AppColors.errorContainer,
          iconColor: AppColors.onErrorContainer,
          title: 'Ubicación desactivada',
          tag: 'Permiso',
          tagBg: AppColors.errorContainer,
          tagColor: AppColors.onErrorContainer,
          description:
              'Tu dispositivo tiene el GPS apagado o no le diste permiso a AsistApp. Actívalo en los ajustes del sistema.',
          trailing: TextButton.icon(
            onPressed: () => LocationService.instance.openLocationSettings(),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Abrir ajustes de ubicación'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 10),
        _guideCard(
          icon: Icons.timer_off,
          iconBg: AppColors.errorContainer,
          iconColor: AppColors.onErrorContainer,
          title: 'Código expirado o clase cerrada',
          tag: 'Tiempo',
          tagBg: AppColors.surfaceContainerHigh,
          tagColor: AppColors.onSurfaceVariant,
          description:
              'La ventana de registro fue cerrada por el docente. Acércate al profesor al finalizar la sesión para solicitar un registro manual justificado.',
        ),
        const SizedBox(height: 10),
        _guideCard(
          icon: Icons.pin,
          iconBg: AppColors.surfaceContainerHighest,
          iconColor: AppColors.primary,
          title: 'Código incorrecto',
          tag: 'Validación',
          tagBg: AppColors.surfaceContainerHigh,
          tagColor: AppColors.onSurface,
          description:
              'El código no coincide. Verifica en la pizarra o el proyector los 6 caracteres e introdúcelos sin espacios (mayúsculas o minúsculas, es lo mismo).',
        ),
        const SizedBox(height: 10),
        _guideCard(
          icon: Icons.how_to_reg,
          iconBg: AppColors.surfaceContainerHigh,
          iconColor: AppColors.secondary,
          title: 'Asistencia ya registrada',
          tag: 'Duplicado',
          tagBg: AppColors.tertiaryFixed,
          tagColor: AppColors.onTertiaryFixed,
          description: 'Tu asistencia ya figura registrada para esta clase. No necesitas registrarte de nuevo.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Aún con problemas?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      'Comunícate con la mesa de ayuda universitaria o tu docente.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guideCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String tag,
    required Color tagBg,
    required Color tagColor,
    required String description,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(999)),
                      child: Text(tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tagColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4)),
                if (trailing != null) ...[
                  const SizedBox(height: 6),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _monthName(int month) {
    const names = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return names[month - 1];
  }
}
