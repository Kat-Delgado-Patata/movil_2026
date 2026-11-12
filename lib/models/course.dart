import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Días de clase en el orden de los chips (1 = lunes ... 6 = sábado).
const List<String> weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S'];

/// Estado del ciclo de vida del curso (colección `courses` en Firestore).
enum CourseStatus { active, finished }

extension CourseStatusX on CourseStatus {
  String get value => this == CourseStatus.finished ? 'finished' : 'active';

  static CourseStatus fromValue(String? value) =>
      value == 'finished' ? CourseStatus.finished : CourseStatus.active;
}

class Course {
  Course({
    this.id,
    this.teacherUid,
    required this.name,
    required this.code,
    required this.group,
    required this.room,
    required this.period,
    required this.days,
    required this.startTime,
    required this.endTime,
    this.students = 0,
    this.faculty,
    this.status = CourseStatus.active,
    this.sessionsCount = 0,
    this.createdAt,
    this.finishedAt,
    this.teacherName,
    this.liveSessionId,
    this.liveSessionCode,
    this.liveSessionExpiresAt,
    this.liveSessionLat,
    this.liveSessionLng,
  });

  /// Id del documento en Firestore; null mientras el curso no se ha creado.
  final String? id;
  final String? teacherUid;

  /// Nombre del docente al momento de crear el curso (evita un join para mostrarlo en tarjetas).
  final String? teacherName;

  final String name;
  final String code;
  final String group;
  final String room;
  final String period;
  final String? faculty;

  /// Días de clase usando `DateTime.weekday` (1 = lunes).
  final Set<int> days;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int students;

  final CourseStatus status;
  final int sessionsCount;
  final DateTime? createdAt;

  /// Fecha en la que se marcó "Finalizar Semestre"; null si sigue activo.
  final DateTime? finishedAt;

  /// Id del documento en `liveSessions` mientras hay una sesión abierta (null si no hay ninguna).
  final String? liveSessionId;

  /// Código vigente de una sesión de asistencia en curso (null si no hay ninguna abierta).
  final String? liveSessionCode;

  /// Momento en que vence el código actual; se usa para saber si la clase está "activa" ahora.
  final DateTime? liveSessionExpiresAt;

  /// Ubicación del docente al abrir la sesión; el estudiante debe estar cerca para marcar presente.
  final double? liveSessionLat;
  final double? liveSessionLng;

  bool get hasLiveSession => liveSessionCode != null && (liveSessionExpiresAt?.isAfter(DateTime.now()) ?? false);

  /// Minutos restantes de la sesión en curso (0 si ya no hay una activa).
  int get liveSessionMinutesLeft {
    if (!hasLiveSession) return 0;
    return liveSessionExpiresAt!.difference(DateTime.now()).inMinutes.clamp(0, 999);
  }

  /// Meses de antigüedad institucional requeridos antes de poder eliminar un curso finalizado.
  static const int monthsRequiredForDeletion = 12;

  String get scheduleRange => '${formatTime(startTime)} - ${formatTime(endTime)}';

  bool get isToday => days.contains(DateTime.now().weekday);

  /// Minutos que faltan para que empiece hoy (negativo si ya empezó).
  int get minutesUntilStart {
    final now = TimeOfDay.now();
    return (startTime.hour * 60 + startTime.minute) - (now.hour * 60 + now.minute);
  }

  /// Etiqueta corta del próximo día de clase: "Hoy 08:00 AM", "Mañana 07:00 AM", "Lun 10:00 AM".
  String get nextClassLabel {
    final today = DateTime.now().weekday;
    final time = formatTime(startTime);
    if (days.contains(today)) return 'Hoy $time';
    final tomorrow = today % 7 + 1;
    if (days.contains(tomorrow)) return 'Mañana $time';
    for (var offset = 2; offset <= 7; offset++) {
      final day = (today + offset - 1) % 7 + 1;
      if (days.contains(day)) return '${_weekdayShort[day - 1]} $time';
    }
    return time;
  }

  /// Meses completos transcurridos desde que se finalizó el curso (0 si sigue activo).
  int get inactivityMonths {
    if (status != CourseStatus.finished || finishedAt == null) return 0;
    final now = DateTime.now();
    var months = (now.year - finishedAt!.year) * 12 + (now.month - finishedAt!.month);
    if (now.day < finishedAt!.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  int get monthsUntilDeletable =>
      (monthsRequiredForDeletion - inactivityMonths).clamp(0, monthsRequiredForDeletion);

  /// Solo se puede eliminar manualmente tras 12 meses finalizado (política institucional).
  bool get canBeDeleted => status == CourseStatus.finished && inactivityMonths >= monthsRequiredForDeletion;

  /// Etiqueta compacta de los días de clase, ej. "Lun - Mié" o "Lun, Mié, Vie".
  String get daysRangeLabel {
    final sorted = days.toList()..sort();
    final labels = sorted.map((d) => _weekdayShort[d - 1]).toList();
    if (labels.length == 2) return '${labels[0]} - ${labels[1]}';
    return labels.join(', ');
  }

  static String formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Course copyWith({
    String? teacherUid,
    CourseStatus? status,
    int? sessionsCount,
    DateTime? finishedAt,
  }) {
    return Course(
      id: id,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName,
      name: name,
      code: code,
      group: group,
      room: room,
      period: period,
      days: days,
      startTime: startTime,
      endTime: endTime,
      students: students,
      faculty: faculty,
      status: status ?? this.status,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      createdAt: createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
      liveSessionId: liveSessionId,
      liveSessionCode: liveSessionCode,
      liveSessionExpiresAt: liveSessionExpiresAt,
      liveSessionLat: liveSessionLat,
      liveSessionLng: liveSessionLng,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'teacherUid': teacherUid,
        if (teacherName != null) 'teacherName': teacherName,
        'name': name,
        'code': code,
        'group': group,
        'room': room,
        'period': period,
        if (faculty != null) 'faculty': faculty,
        'days': days.toList(),
        'startMinutes': startTime.hour * 60 + startTime.minute,
        'endMinutes': endTime.hour * 60 + endTime.minute,
        'students': students,
        'status': status.value,
        'sessionsCount': sessionsCount,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Course.fromMap(String id, Map<String, dynamic> data) {
    TimeOfDay minutesToTime(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    return Course(
      id: id,
      teacherUid: data['teacherUid'] as String?,
      teacherName: data['teacherName'] as String?,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      group: data['group'] as String? ?? '',
      room: data['room'] as String? ?? '',
      period: data['period'] as String? ?? '',
      faculty: data['faculty'] as String?,
      days: ((data['days'] as List<dynamic>?) ?? const []).map((e) => e as int).toSet(),
      startTime: minutesToTime(data['startMinutes'] as int? ?? 0),
      endTime: minutesToTime(data['endMinutes'] as int? ?? 0),
      students: data['students'] as int? ?? 0,
      status: CourseStatusX.fromValue(data['status'] as String?),
      sessionsCount: data['sessionsCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
      liveSessionId: data['liveSessionId'] as String?,
      liveSessionCode: data['liveSessionCode'] as String?,
      liveSessionExpiresAt: (data['liveSessionExpiresAt'] as Timestamp?)?.toDate(),
      liveSessionLat: (data['liveSessionLat'] as num?)?.toDouble(),
      liveSessionLng: (data['liveSessionLng'] as num?)?.toDouble(),
    );
  }

  static const _weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
}
