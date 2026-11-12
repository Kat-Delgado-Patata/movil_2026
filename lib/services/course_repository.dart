import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';

/// Acceso a la colección `courses` en Firestore.
class CourseRepository {
  CourseRepository._();
  static final CourseRepository instance = CourseRepository._();

  final CollectionReference<Map<String, dynamic>> _coursesRef =
      FirebaseFirestore.instance.collection('courses');

  /// Cursos a cargo de un docente, más recientes primero.
  Stream<List<Course>> watchTeacherCourses(String teacherUid) {
    return _coursesRef
        .where('teacherUid', isEqualTo: teacherUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Course.fromMap(doc.id, doc.data())).toList());
  }

  Stream<Course?> watchCourse(String courseId) {
    return _coursesRef.doc(courseId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return Course.fromMap(doc.id, data);
    });
  }

  Future<Course> createCourse(Course course) async {
    final docRef = await _coursesRef.add(course.toCreateMap());
    final snapshot = await docRef.get();
    return Course.fromMap(docRef.id, snapshot.data()!);
  }

  /// Activa o finaliza el curso. Al finalizar se guarda la fecha para calcular inactividad;
  /// al reactivar se limpia para que la cuenta de inactividad vuelva a cero.
  Future<void> setStatus(String courseId, CourseStatus status) {
    return _coursesRef.doc(courseId).update({
      'status': status.value,
      'finishedAt': status == CourseStatus.finished ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> deleteCourse(String courseId) => _coursesRef.doc(courseId).delete();

  /// Cursos en los que un estudiante está matriculado, según su código universitario.
  /// Usa una consulta de grupo de colección sobre `courses/*/students` para no tener
  /// que recorrer curso por curso.
  Future<List<Course>> fetchCoursesForStudentCode(String studentCode) async {
    if (studentCode.trim().isEmpty) return [];

    final rosterDocs = await FirebaseFirestore.instance
        .collectionGroup('students')
        .where('code', isEqualTo: studentCode.trim())
        .where('status', isEqualTo: 'active')
        .get();

    final courseIds = {
      for (final doc in rosterDocs.docs)
        if (doc.reference.parent.parent != null) doc.reference.parent.parent!.id,
    };
    if (courseIds.isEmpty) return [];

    final courses = await Future.wait(courseIds.map((id) => _coursesRef.doc(id).get()));
    return courses
        .where((doc) => doc.data() != null)
        .map((doc) => Course.fromMap(doc.id, doc.data()!))
        .toList();
  }
}
