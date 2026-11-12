import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_checkin.dart';
import '../models/attendance_session.dart';
import '../models/course.dart';
import '../models/live_attendee.dart';
import 'attendance_session_repository.dart';
import 'location_service.dart';

const int codeLength = 6;
// Sin 0/O ni 1/I para que el código no se confunda al dictarlo en clase.
const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Radio máximo (en metros) entre el estudiante y el punto donde el docente abrió
/// la sesión para que el check-in se considere válido.
const double maxCheckInDistanceMeters = 50;

class LiveSessionException implements Exception {
  LiveSessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Orquesta el ciclo completo de una sesión de asistencia:
/// el docente la abre (genera código) -> los estudiantes marcan presente
/// -> el docente la cierra (se archiva un resumen en `attendanceSessions`).
class LiveSessionRepository {
  LiveSessionRepository._();
  static final LiveSessionRepository instance = LiveSessionRepository._();

  final CollectionReference<Map<String, dynamic>> _sessionsRef =
      FirebaseFirestore.instance.collection('liveSessions');
  final CollectionReference<Map<String, dynamic>> _coursesRef =
      FirebaseFirestore.instance.collection('courses');

  CollectionReference<Map<String, dynamic>> _attendeesRef(String sessionId) =>
      _sessionsRef.doc(sessionId).collection('attendees');

  String generateCode() => List.generate(codeLength, (_) => _codeAlphabet[Random().nextInt(_codeAlphabet.length)]).join();

  /// Abre una sesión nueva para el curso: toma la ubicación actual del docente
  /// (los estudiantes deberán estar cerca de ese punto para poder marcar presente)
  /// y genera el código.
  Future<Course> startSession(Course course, {int? durationMinutes}) async {
    if (course.id == null) throw LiveSessionException('El curso no existe');

    final position = await LocationService.instance.getCurrentPosition();

    final code = generateCode();
    final expiresAt = durationMinutes == null ? null : DateTime.now().add(Duration(minutes: durationMinutes));

    final sessionDoc = await _sessionsRef.add({
      'courseId': course.id,
      'code': code,
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'closedAt': null,
      'lat': position.latitude,
      'lng': position.longitude,
    });

    await _coursesRef.doc(course.id).update({
      'liveSessionId': sessionDoc.id,
      'liveSessionCode': code,
      'liveSessionExpiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'liveSessionLat': position.latitude,
      'liveSessionLng': position.longitude,
    });

    return course._withLiveSession(sessionDoc.id, code, expiresAt, position.latitude, position.longitude);
  }

  /// Genera un código nuevo para la sesión ya abierta (sin perder a los que ya marcaron presente).
  Future<Course> regenerateCode(Course course, {int? durationMinutes}) async {
    if (course.id == null || course.liveSessionId == null) {
      throw LiveSessionException('No hay una sesión abierta para regenerar');
    }
    final code = generateCode();
    final expiresAt = durationMinutes == null ? null : DateTime.now().add(Duration(minutes: durationMinutes));

    await _sessionsRef.doc(course.liveSessionId).update({
      'code': code,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
    });
    await _coursesRef.doc(course.id).update({
      'liveSessionCode': code,
      'liveSessionExpiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
    });

    return course._withLiveSession(course.liveSessionId!, code, expiresAt, course.liveSessionLat, course.liveSessionLng);
  }

  Stream<List<LiveAttendee>> watchAttendees(String sessionId) {
    return _attendeesRef(sessionId)
        .orderBy('checkedInAt')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => LiveAttendee.fromMap(doc.id, doc.data())).toList());
  }

  /// Igual que [watchAttendees] pero en una sola lectura (para armar el reporte docente).
  Future<List<LiveAttendee>> fetchAttendees(String sessionId) async {
    final snapshot = await _attendeesRef(sessionId).get();
    return snapshot.docs.map((doc) => LiveAttendee.fromMap(doc.id, doc.data())).toList();
  }

  /// El estudiante intenta marcar presente con el código que digitó. Antes de escribir
  /// nada se valida que esté a menos de [maxCheckInDistanceMeters] de donde el docente
  /// abrió la sesión.
  Future<void> checkIn({
    required Course course,
    required String enteredCode,
    required String studentCode,
    required String studentName,
  }) async {
    if (course.id == null || course.liveSessionId == null || course.liveSessionCode == null) {
      throw LiveSessionException('Esta clase no tiene una sesión de asistencia activa.');
    }
    if (course.liveSessionExpiresAt != null && course.liveSessionExpiresAt!.isBefore(DateTime.now())) {
      throw LiveSessionException('El código ya expiró. Pide uno nuevo a tu docente.');
    }
    if (course.liveSessionCode!.toUpperCase() != enteredCode.trim().toUpperCase()) {
      throw LiveSessionException('El código ingresado no es correcto.');
    }

    final attendeeRef = _attendeesRef(course.liveSessionId!).doc(studentCode);
    final existing = await attendeeRef.get();
    if (existing.exists) {
      throw LiveSessionException('Ya registraste tu asistencia en esta clase.');
    }

    double? distance;
    if (course.liveSessionLat != null && course.liveSessionLng != null) {
      final position = await LocationService.instance.getCurrentPosition();
      distance = LocationService.instance.distanceInMeters(
        startLat: course.liveSessionLat!,
        startLng: course.liveSessionLng!,
        endLat: position.latitude,
        endLng: position.longitude,
      );
      if (distance > maxCheckInDistanceMeters) {
        throw LiveSessionException(
          'Estás a ${distance.round()}m del aula. Debes estar a menos de ${maxCheckInDistanceMeters.round()}m para registrar asistencia.',
        );
      }
    }

    await attendeeRef.set({
      'studentCode': studentCode,
      'studentName': studentName,
      'status': AttendeeStatus.present.value,
      'markedManually': false,
      'checkedInAt': FieldValue.serverTimestamp(),
      // Denormalizado para que el estudiante pueda ver su comprobante sin un join.
      'courseId': course.id,
      'courseName': course.name,
      'courseGroup': course.group,
      'validationId': _generateValidationId(course),
      'distanceMeters': ?distance,
    });
  }

  /// El docente marca (o corrige) a mano el estado de un estudiante: "pasar
  /// lista" para quienes no tienen código, olvidaron el celular, o para
  /// justificar una ausencia. Funciona tanto con la sesión abierta (se omite
  /// [sessionId] y se usa la activa del curso) como con una ya cerrada hace
  /// tiempo (pasando su [sessionId] explícito), por ejemplo cuando alguien
  /// justifica una ausencia después de la clase.
  Future<void> setManualStatus(
    Course course, {
    required String studentCode,
    required String studentName,
    required AttendeeStatus status,
    String? sessionId,
  }) async {
    final targetSessionId = sessionId ?? course.liveSessionId;
    if (course.id == null || targetSessionId == null) {
      throw LiveSessionException('No hay una sesión de asistencia para este curso.');
    }
    await _attendeesRef(targetSessionId).doc(studentCode).set({
      'studentCode': studentCode,
      'studentName': studentName,
      'status': status.value,
      'markedManually': true,
      'checkedInAt': FieldValue.serverTimestamp(),
      'courseId': course.id,
      'courseName': course.name,
      'courseGroup': course.group,
      'validationId': _generateValidationId(course),
    });
    await _resyncArchivedCounts(targetSessionId);
  }

  /// Quita el marcado de un estudiante (vuelve a quedar como "ausente", que es
  /// simplemente la falta de un registro). Igual que [setManualStatus], funciona
  /// con la sesión activa o con una ya cerrada si se pasa [sessionId].
  Future<void> clearStatus(Course course, String studentCode, {String? sessionId}) async {
    final targetSessionId = sessionId ?? course.liveSessionId;
    if (targetSessionId == null) return;
    await _attendeesRef(targetSessionId).doc(studentCode).delete();
    await _resyncArchivedCounts(targetSessionId);
  }

  /// Si [sessionId] ya está archivada en `attendanceSessions` (la sesión está
  /// cerrada), vuelve a calcular sus conteos para que el Historial y el reporte
  /// del docente no queden desactualizados tras una corrección manual. Si la
  /// sesión sigue abierta todavía no existe ese resumen, así que no hace nada.
  Future<void> _resyncArchivedCounts(String sessionId) async {
    final attendeesSnap = await _attendeesRef(sessionId).get();
    final attendees = attendeesSnap.docs.map((doc) => LiveAttendee.fromMap(doc.id, doc.data()));
    final presentCount = attendees.where((a) => !a.isExcused).length;
    final excusedCount = attendees.where((a) => a.isExcused).length;
    await AttendanceSessionRepository.instance.updateCountsByLiveSessionId(
      sessionId,
      presentCount: presentCount,
      excusedCount: excusedCount,
    );
  }

  String _generateValidationId(Course course) {
    final base = course.code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = (Random().nextInt(90000) + 10000).toString();
    return '$base-$suffix';
  }

  /// El comprobante más reciente de asistencia del estudiante (para "Estado de Asistencia").
  Stream<AttendanceCheckIn?> watchLatestCheckIn(String studentCode) {
    return FirebaseFirestore.instance
        .collectionGroup('attendees')
        .where('studentCode', isEqualTo: studentCode)
        .orderBy('checkedInAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : AttendanceCheckIn.fromMap(snap.docs.first.data()));
  }

  /// El docente cierra la sesión: archiva el resumen en el historial y limpia el curso.
  Future<void> closeSession(Course course, {required String teacherUid, required int totalEnrolled}) async {
    if (course.id == null || course.liveSessionId == null) return;

    final attendeesSnap = await _attendeesRef(course.liveSessionId!).get();
    final attendees = attendeesSnap.docs.map((doc) => LiveAttendee.fromMap(doc.id, doc.data()));
    final presentCount = attendees.where((a) => !a.isExcused).length;
    final excusedCount = attendees.where((a) => a.isExcused).length;

    await AttendanceSessionRepository.instance.createSession(AttendanceSession(
      teacherUid: teacherUid,
      courseId: course.id!,
      date: DateTime.now(),
      presentCount: presentCount,
      excusedCount: excusedCount,
      totalEnrolled: totalEnrolled,
      liveSessionId: course.liveSessionId,
    ));

    await _sessionsRef.doc(course.liveSessionId).update({'closedAt': FieldValue.serverTimestamp()});

    await _coursesRef.doc(course.id).update({
      'liveSessionId': null,
      'liveSessionCode': null,
      'liveSessionExpiresAt': null,
      'liveSessionLat': null,
      'liveSessionLng': null,
      'sessionsCount': FieldValue.increment(1),
    });
  }
}

extension on Course {
  Course _withLiveSession(String sessionId, String code, DateTime? expiresAt, double? lat, double? lng) {
    return Course(
      id: id,
      teacherUid: teacherUid,
      teacherName: teacherName,
      name: name,
      code: this.code,
      group: group,
      room: room,
      period: period,
      days: days,
      startTime: startTime,
      endTime: endTime,
      students: students,
      faculty: faculty,
      status: status,
      sessionsCount: sessionsCount,
      createdAt: createdAt,
      finishedAt: finishedAt,
      liveSessionId: sessionId,
      liveSessionCode: code,
      liveSessionExpiresAt: expiresAt,
      liveSessionLat: lat,
      liveSessionLng: lng,
    );
  }
}
