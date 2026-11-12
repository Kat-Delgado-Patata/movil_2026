import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/course.dart';
import '../../models/course_student.dart';
import '../../models/live_attendee.dart';
import '../../services/auth_service.dart';
import '../../services/course_student_repository.dart';
import '../../services/live_session_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/roll_call_list.dart';

class LiveSessionArgs {
  const LiveSessionArgs({required this.course, this.durationMinutes});

  /// Curso ya con la sesión abierta (liveSessionId/liveSessionCode/liveSessionExpiresAt listos).
  final Course course;

  /// `null` = el código no expira. Se reutiliza al regenerar el código.
  final int? durationMinutes;
}

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late LiveSessionArgs _args;
  late Course _course;
  Timer? _tickTimer;
  bool _isRegenerating = false;
  bool _isFinishing = false;
  bool _initialized = false;

  // Se actualizan en cada build a partir de los streams; _confirmFinish los usa
  // porque se dispara desde un botón, fuera del árbol de los StreamBuilder.
  List<LiveAttendee> _latestAttendees = const [];
  int _latestTotalEnrolled = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _args = ModalRoute.of(context)!.settings.arguments as LiveSessionArgs;
    _course = _args.course;
    if (_hasExpiry) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  bool get _hasExpiry => _course.liveSessionExpiresAt != null;

  int get _secondsLeft {
    if (!_hasExpiry) return 0;
    return _course.liveSessionExpiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 999999);
  }

  bool get _isExpired => _hasExpiry && _secondsLeft <= 0;

  String get _timerText {
    if (!_hasExpiry) return 'Sin límite';
    if (_isExpired) return 'Expirado';
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds min';
  }

  String _ago(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 60) return 'hace ${seconds}s';
    return 'hace ${seconds ~/ 60} min';
  }

  Future<void> _copyCode() async {
    final code = _course.liveSessionCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado al portapapeles')),
    );
  }

  Future<void> _regenerateCode() async {
    setState(() => _isRegenerating = true);
    try {
      final updated = await LiveSessionRepository.instance.regenerateCode(
        _course,
        durationMinutes: _args.durationMinutes,
      );
      if (!mounted) return;
      setState(() {
        _course = updated;
        _isRegenerating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo regenerar el código')),
      );
    }
  }

  Future<void> _confirmFinish() async {
    final present = _latestAttendees.where((a) => !a.isExcused).length;
    final excused = _latestAttendees.where((a) => a.isExcused).length;
    final total = _latestTotalEnrolled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Finalizar asistencia?'),
        content: Text(
          'Se cerrará el registro con $present de $total alumnos presentes'
          '${excused > 0 ? ' y $excused justificados' : ''}. '
          'Los estudiantes ya no podrán ingresar el código.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir abierta')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final teacherUid = AuthService.instance.currentUser?.uid;
    if (teacherUid == null) return;

    setState(() => _isFinishing = true);
    try {
      await LiveSessionRepository.instance.closeSession(
        _course,
        teacherUid: teacherUid,
        totalEnrolled: total,
      );
      _tickTimer?.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Asistencia cerrada: $present/$total presentes')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión. Intenta nuevamente')),
      );
    }
  }

  Future<void> _setManualStatus(CourseStudent student, AttendeeStatus? status) async {
    try {
      if (status == null) {
        await LiveSessionRepository.instance.clearStatus(_course, student.code);
      } else {
        await LiveSessionRepository.instance.setManualStatus(
          _course,
          studentCode: student.code,
          studentName: student.fullName,
          status: status,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado de este estudiante')),
      );
    }
  }

  void _showManualRollCall() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: StreamBuilder<List<CourseStudent>>(
              stream: CourseStudentRepository.instance.watchActiveStudents(_course.id!),
              builder: (context, rosterSnapshot) {
                final roster = rosterSnapshot.data ?? const <CourseStudent>[];
                return StreamBuilder<List<LiveAttendee>>(
                  stream: LiveSessionRepository.instance.watchAttendees(_course.liveSessionId!),
                  builder: (context, attendeesSnapshot) {
                    final attendeesByCode = {
                      for (final a in attendeesSnapshot.data ?? const <LiveAttendee>[]) a.studentCode: a,
                    };
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pasar Lista Manualmente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text(
                            'Útil para estudiantes sin celular, sin GPS o para justificar una ausencia.',
                            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: RollCallList(
                              roster: roster,
                              attendeesByCode: attendeesByCode,
                              onSetStatus: _setManualStatus,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAttendanceList(int totalEnrolled) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (context) {
        return StreamBuilder<List<LiveAttendee>>(
          stream: LiveSessionRepository.instance.watchAttendees(_course.liveSessionId!),
          builder: (context, snapshot) {
            final list = (snapshot.data ?? const <LiveAttendee>[]).reversed.toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Asistencia en tiempo real (${list.length}/$totalEnrolled)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Aún no hay alumnos registrados',
                            style: TextStyle(color: AppColors.onSurfaceVariant)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _avatar(list[i].initials),
                          title: Text(list[i].studentName),
                          subtitle: list[i].isExcused
                              ? const Text('Justificada', style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600))
                              : null,
                          trailing: Text(_ago(list[i].checkedInAt),
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseStudent>>(
      stream: CourseStudentRepository.instance.watchActiveStudents(_course.id!),
      builder: (context, rosterSnapshot) {
        final totalEnrolled = rosterSnapshot.data?.length ?? 0;
        return StreamBuilder<List<LiveAttendee>>(
          stream: LiveSessionRepository.instance.watchAttendees(_course.liveSessionId!),
          builder: (context, attendeesSnapshot) {
            final attendees = attendeesSnapshot.data ?? const <LiveAttendee>[];
            _latestAttendees = attendees;
            _latestTotalEnrolled = totalEnrolled;

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _confirmFinish();
              },
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Volver',
                            onPressed: _isFinishing ? null : _confirmFinish,
                          ),
                        ),
                        _buildLiveChip(),
                        const SizedBox(height: 10),
                        Text(
                          _course.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Grupo ${_course.group} • ${_course.room}',
                          style: const TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        _buildCodeCard(),
                        const SizedBox(height: 16),
                        _buildAttendanceCard(attendees, totalEnrolled),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showAttendanceList(totalEnrolled),
                            icon: const Icon(Icons.checklist_rtl, size: 22),
                            label: const Text('Ver Lista de Asistencia en Tiempo Real',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: _secondaryButton(Icons.fact_check_outlined, 'Pasar Lista Manualmente', _showManualRollCall),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.errorContainer,
                              foregroundColor: AppColors.error,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isFinishing ? null : _confirmFinish,
                            icon: _isFinishing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.error),
                                  )
                                : const Icon(Icons.stop_circle_outlined, size: 20),
                            label: Text(
                              _isFinishing ? 'Cerrando...' : 'Finalizar y Cerrar Asistencia',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveChip() {
    final expired = _isExpired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: expired ? AppColors.errorContainer : AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: expired ? AppColors.error : AppColors.onTertiaryContainer),
          const SizedBox(width: 6),
          Text(
            expired ? 'CÓDIGO EXPIRADO' : 'SESIÓN EN VIVO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: expired ? AppColors.error : AppColors.onTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    final expired = _isExpired;
    final code = _course.liveSessionCode ?? ''.padRight(codeLength, '•');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.password, size: 16, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 6),
                  Text('Código de Acceso', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: expired ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: expired ? AppColors.error : AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _timerText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: expired ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (var i = 0; i < codeLength; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 0.8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          code[i],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: expired ? AppColors.outline : AppColors.primary,
                            decoration: expired ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(Icons.copy, 'Copiar Código', expired ? null : _copyCode),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryButton(
                  Icons.refresh,
                  'Regenerar',
                  _isRegenerating ? null : _regenerateCode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(List<LiveAttendee> attendees, int totalEnrolled) {
    final presentList = attendees.where((a) => !a.isExcused).toList();
    final excusedCount = attendees.length - presentList.length;
    final present = presentList.length;
    final presentRatio = totalEnrolled == 0 ? 0.0 : present / totalEnrolled;
    final last = presentList.isEmpty ? null : presentList.last;
    final recent = presentList.reversed.take(3).toList();
    final others = present - recent.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alumnos Registrados',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$present',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' / $totalEnrolled presentes',
                            style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (excusedCount > 0)
                      Text('$excusedCount justificados por el docente',
                          style: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${(presentRatio * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.tertiaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: presentRatio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 30,
                width: recent.isEmpty ? 0 : 22.0 * recent.length + 8 + (others > 0 ? 30 : 0),
                child: Stack(
                  children: [
                    for (var i = 0; i < recent.length; i++)
                      Positioned(left: i * 22.0, child: _avatar(recent[i].initials, radius: 15)),
                    if (others > 0)
                      Positioned(
                        left: recent.length * 22.0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: Text('+$others',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (last != null)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 7, color: AppColors.onTertiaryContainer),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Último: ${last.studentName} (${_ago(last.checkedInAt)})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text('Esperando alumnos...',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(String initials, {double radius = 18}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceContainerLowest,
      child: CircleAvatar(
        radius: radius - 2,
        backgroundColor: AppColors.primaryFixed,
        child: Text(
          initials,
          style: TextStyle(fontSize: radius * 0.6, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _secondaryButton(IconData icon, String label, VoidCallback? onPressed) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surfaceContainer,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
      ],
    );
  }
}
