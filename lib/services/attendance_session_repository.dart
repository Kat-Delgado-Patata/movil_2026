import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_session.dart';

/// Acceso a la colección `attendanceSessions` en Firestore.
class AttendanceSessionRepository {
  AttendanceSessionRepository._();
  static final AttendanceSessionRepository instance = AttendanceSessionRepository._();

  final CollectionReference<Map<String, dynamic>> _sessionsRef =
      FirebaseFirestore.instance.collection('attendanceSessions');

  /// Todas las sesiones cerradas de un docente (de todos sus cursos), más recientes primero.
  /// El filtro por curso se hace en memoria en la pantalla, igual que el mockup original.
  Stream<List<AttendanceSession>> watchTeacherSessions(String teacherUid) {
    return _sessionsRef
        .where('teacherUid', isEqualTo: teacherUid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AttendanceSession.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> createSession(AttendanceSession session) => _sessionsRef.add(session.toCreateMap());

  /// Sesiones cerradas de un curso puntual, más recientes primero (lectura única,
  /// pensada para armar el reporte personal de un estudiante).
  Future<List<AttendanceSession>> fetchCourseSessions(String courseId) async {
    final snapshot =
        await _sessionsRef.where('courseId', isEqualTo: courseId).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => AttendanceSession.fromMap(doc.id, doc.data())).toList();
  }

  /// Actualiza los conteos ya archivados de una sesión cerrada (se usa cuando el
  /// docente corrige la asistencia después de que la sesión terminó).
  Future<void> updateCountsByLiveSessionId(
    String liveSessionId, {
    required int presentCount,
    required int excusedCount,
  }) async {
    final snapshot = await _sessionsRef.where('liveSessionId', isEqualTo: liveSessionId).limit(1).get();
    if (snapshot.docs.isEmpty) return;
    await snapshot.docs.first.reference.update({
      'presentCount': presentCount,
      'excusedCount': excusedCount,
    });
  }
}
