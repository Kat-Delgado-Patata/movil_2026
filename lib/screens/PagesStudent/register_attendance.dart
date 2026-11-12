import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../Routes/route.dart';
import '../../models/course.dart';
import '../../services/auth_service.dart';
import '../../services/course_repository.dart';
import '../../services/live_session_repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';

/// Pantalla donde el estudiante digita el código de 6 caracteres proyectado por el docente.
class RegisterAttendanceScreen extends StatefulWidget {
  const RegisterAttendanceScreen({super.key});

  @override
  State<RegisterAttendanceScreen> createState() => _RegisterAttendanceScreenState();
}

class _RegisterAttendanceScreenState extends State<RegisterAttendanceScreen> {
  final _controllers = List.generate(codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(codeLength, (_) => FocusNode());

  bool _hasError = false;
  bool _isSubmitting = false;
  Timer? _tickTimer;

  String get _courseId => (ModalRoute.of(context)!.settings.arguments as Course).id!;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final upper = value.toUpperCase();
    if (upper != value) {
      _controllers[index].value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    if (upper.isNotEmpty && index < codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _hasError = false);
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    final isBackspace = event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace;
    if (isBackspace && _controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _timerText(Course course) {
    final expiresAt = course.liveSessionExpiresAt;
    if (expiresAt == null) return 'Sin límite';
    final seconds = expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999999);
    if (seconds <= 0) return '00:00 min';
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs min';
  }

  Future<void> _handleConfirm(Course course) async {
    if (_enteredCode.length != codeLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _isSubmitting = true);

    final user = await AuthService.instance.getCurrentAppUser();
    if (user?.studentCode == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encontramos tu código universitario en tu perfil.')),
      );
      return;
    }

    try {
      await LiveSessionRepository.instance.checkIn(
        course: course,
        enteredCode: _enteredCode,
        studentCode: user!.studentCode!,
        studentName: user.fullName,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.attendanceStatus);
    } on LiveSessionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar tu asistencia. Intenta nuevamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Course?>(
      stream: CourseRepository.instance.watchCourse(_courseId),
      builder: (context, snapshot) {
        final course = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (course == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => Navigator.pop(context))),
            body: const Center(child: Text('Este curso ya no existe.')),
          );
        }

        final isActive = course.hasLiveSession;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Escanear QR Asistencia'),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  _buildStatusRow(isActive),
                  const SizedBox(height: 12),
                  _buildCourseCard(course),
                  const SizedBox(height: 12),
                  _buildTimerCard(course, isActive),
                  const SizedBox(height: 16),
                  _buildCodeEntry(course, isActive),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(bool isActive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isActive ? 'SESIÓN ACTIVA' : 'SESIÓN FINALIZADA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isActive ? AppColors.primary : AppColors.outline,
              ),
            ),
            const Text('Registrar Asistencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.tertiaryContainer : AppColors.outline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? 'En Vivo' : 'Cerrada',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(6)),
                      child: Text('Grupo ${course.group}', style: const TextStyle(color: AppColors.onPrimary, fontSize: 11)),
                    ),
                    const SizedBox(height: 6),
                    Text(course.name, style: const TextStyle(color: AppColors.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.meeting_room, size: 15, color: AppColors.primaryFixed),
                        const SizedBox(width: 4),
                        Text(course.room, style: const TextStyle(color: AppColors.primaryFixed, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.calculate, color: AppColors.onPrimary, size: 24),
              ),
            ],
          ),
          if (course.teacherName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1AFFFFFF)))),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: AppColors.onPrimary),
                  const SizedBox(width: 6),
                  Text(course.teacherName!, style: const TextStyle(color: AppColors.onPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimerCard(Course course, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 22, color: isActive ? AppColors.secondary : AppColors.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ventana de registro',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant)),
                Text(
                  isActive ? 'Tiempo restante: ${_timerText(course)}' : 'Esta sesión ya no está activa',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEntry(Course course, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.primaryFixed, shape: BoxShape.circle),
            child: const Icon(Icons.pin, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 10),
          const Text('Introduce el código del docente',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text(
            'Digita los 6 caracteres proyectados en la pizarra por el profesor.',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _digitField(i, isActive)),
              ],
            ],
          ),
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Revisa el código e intenta de nuevo', style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: (!isActive || _isSubmitting) ? null : () => _handleConfirm(course),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onSecondary),
                    )
                  : const Icon(Icons.how_to_reg, size: 20),
              label: Text(_isSubmitting ? 'Verificando...' : 'Confirmar Asistencia'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow, foregroundColor: AppColors.onSurface),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar y Volver', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitField(int index, bool enabled) {
    return Focus(
      onKeyEvent: (_, event) => _onKey(index, event),
      child: AspectRatio(
        aspectRatio: 0.8,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          enabled: enabled,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _hasError ? AppColors.error : AppColors.outlineVariant),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _hasError ? AppColors.error : Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
            ),
          ),
          onChanged: (value) => _onDigitChanged(index, value),
        ),
      ),
    );
  }
}
