import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course_student.dart';
import '../models/roster_import_row.dart';

/// Acceso a la subcolección `courses/{courseId}/students` en Firestore.
///
/// El id de cada documento es el código universitario del estudiante (no uno
/// autogenerado): así Firestore evita duplicados por sí solo, tanto si se
/// agrega a mano como si se importa desde Excel.
class CourseStudentRepository {
  CourseStudentRepository._();
  static final CourseStudentRepository instance = CourseStudentRepository._();

  CollectionReference<Map<String, dynamic>> _studentsRef(String courseId) =>
      FirebaseFirestore.instance.collection('courses').doc(courseId).collection('students');

  /// Estudiantes con matrícula activa (los dados de baja se ocultan pero no se borran).
  Stream<List<CourseStudent>> watchActiveStudents(String courseId) {
    return _studentsRef(courseId)
        .where('status', isEqualTo: RosterStatus.active.value)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CourseStudent.fromMap(doc.id, courseId, doc.data())).toList());
  }

  /// Igual que [watchActiveStudents] pero en una sola lectura (para armar reportes).
  Future<List<CourseStudent>> fetchActiveStudents(String courseId) async {
    final snapshot = await _studentsRef(courseId).where('status', isEqualTo: RosterStatus.active.value).get();
    return snapshot.docs.map((doc) => CourseStudent.fromMap(doc.id, courseId, doc.data())).toList();
  }

  /// Agrega (o reactiva, si ya existía con ese código) a un estudiante.
  Future<void> addStudent(String courseId, {required String fullName, required String code}) {
    final student = CourseStudent(courseId: courseId, fullName: fullName, code: code);
    return _studentsRef(courseId).doc(code).set(student.toCreateMap());
  }

  /// [studentId] es el id del documento, que hoy equivale al código con el que
  /// se creó. Si [code] cambia, hay que "mover" el documento para que su id
  /// siga siendo el código vigente.
  Future<void> updateStudent(String courseId, String studentId, {required String fullName, required String code}) async {
    if (code == studentId) {
      return _studentsRef(courseId).doc(studentId).update({'fullName': fullName, 'code': code});
    }

    final oldRef = _studentsRef(courseId).doc(studentId);
    final newRef = _studentsRef(courseId).doc(code);
    final existing = await oldRef.get();
    final data = Map<String, dynamic>.from(existing.data() ?? {})
      ..['fullName'] = fullName
      ..['code'] = code;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(newRef, data);
    batch.delete(oldRef);
    await batch.commit();
  }

  /// Baja suave: oculta al estudiante de la lista activa pero conserva su historial.
  Future<void> removeStudent(String courseId, String studentId) {
    return _studentsRef(courseId).doc(studentId).update({'status': RosterStatus.removed.value});
  }

  /// Agrega (o actualiza) muchos estudiantes de una sola vez, usada al importar
  /// desde Excel. Los códigos repetidos dentro de [rows] se quedan con el
  /// último valor; los que ya existían en el curso se actualizan, no se duplican.
  Future<void> importRows(String courseId, List<RosterImportRow> rows) async {
    const chunkSize = 400; // margen bajo el límite de 500 operaciones por batch de Firestore.
    for (var start = 0; start < rows.length; start += chunkSize) {
      final chunk = rows.skip(start).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();
      for (final row in chunk) {
        final student = CourseStudent(courseId: courseId, fullName: row.fullName, code: row.code);
        batch.set(_studentsRef(courseId).doc(row.code), student.toCreateMap());
      }
      await batch.commit();
    }
  }
}
