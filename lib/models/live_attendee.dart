import 'package:cloud_firestore/cloud_firestore.dart';

/// Cómo quedó marcado un estudiante en la sesión abierta.
/// No existe "ausente" como registro: un estudiante sin documento se considera ausente.
enum AttendeeStatus { present, excused }

extension AttendeeStatusX on AttendeeStatus {
  String get value => this == AttendeeStatus.excused ? 'excused' : 'present';

  static AttendeeStatus fromValue(String? value) =>
      value == 'excused' ? AttendeeStatus.excused : AttendeeStatus.present;
}

/// Un estudiante ya marcado (presente o justificado) en la sesión de asistencia abierta.
/// Vive en `liveSessions/{sessionId}/attendees/{studentCode}` (el id es el código
/// universitario, así Firestore evita duplicados sin necesitar una consulta aparte).
class LiveAttendee {
  LiveAttendee({
    required this.studentCode,
    required this.studentName,
    required this.checkedInAt,
    this.status = AttendeeStatus.present,
    this.markedManually = false,
  });

  final String studentCode;
  final String studentName;
  final DateTime checkedInAt;
  final AttendeeStatus status;

  /// true si lo marcó el docente a mano (pasar lista), no el propio estudiante con el código.
  final bool markedManually;

  bool get isExcused => status == AttendeeStatus.excused;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return '$first$second'.toUpperCase();
  }

  factory LiveAttendee.fromMap(String studentCode, Map<String, dynamic> data) {
    return LiveAttendee(
      studentCode: studentCode,
      studentName: data['studentName'] as String? ?? '',
      checkedInAt: (data['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendeeStatusX.fromValue(data['status'] as String?),
      markedManually: data['markedManually'] as bool? ?? false,
    );
  }
}
