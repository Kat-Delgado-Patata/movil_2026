import 'package:flutter/material.dart';

import '../models/course_student.dart';
import '../models/live_attendee.dart';
import '../theme/app_colors.dart';

/// Lista de todo el roster de un curso con 3 botones por fila (Presente /
/// Justificada / Ausente) para que el docente pueda pasar lista a mano.
/// La usan tanto la sesión en vivo como el detalle de una sesión ya cerrada.
class RollCallList extends StatelessWidget {
  const RollCallList({
    super.key,
    required this.roster,
    required this.attendeesByCode,
    required this.onSetStatus,
  });

  final List<CourseStudent> roster;
  final Map<String, LiveAttendee> attendeesByCode;

  /// `status == null` significa "marcar como ausente" (borra el registro).
  final void Function(CourseStudent student, AttendeeStatus? status) onSetStatus;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const Center(
        child: Text('No hay estudiantes matriculados en este curso', style: TextStyle(color: AppColors.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      itemCount: roster.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final student = roster[i];
        final attendee = attendeesByCode[student.code];
        return _row(student, attendee);
      },
    );
  }

  Widget _row(CourseStudent student, LiveAttendee? attendee) {
    final current = attendee?.status;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _avatar(student.initials),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Cód: ${student.code}', style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          _chip('P', AppColors.tertiaryContainer, current == AttendeeStatus.present,
              () => onSetStatus(student, AttendeeStatus.present)),
          const SizedBox(width: 6),
          _chip('J', AppColors.secondary, current == AttendeeStatus.excused,
              () => onSetStatus(student, AttendeeStatus.excused)),
          const SizedBox(width: 6),
          _chip('A', AppColors.error, current == null, () => onSetStatus(student, null)),
        ],
      ),
    );
  }

  Widget _avatar(String initials) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.surfaceContainerLowest,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.primaryFixed,
        child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ),
    );
  }

  Widget _chip(String label, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surfaceContainer,
          shape: BoxShape.circle,
          border: selected ? null : Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
