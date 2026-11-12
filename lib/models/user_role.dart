/// Rol académico compartido por las pantallas de autenticación y perfil.
enum UserRole { student, teacher }

extension UserRoleX on UserRole {
  String get label => this == UserRole.student ? 'Estudiante' : 'Docente';

  /// Valor que se guarda en el documento de Firestore (`users/{uid}.role`).
  String get value => this == UserRole.student ? 'student' : 'teacher';

  static UserRole fromValue(String? value) =>
      value == 'teacher' ? UserRole.teacher : UserRole.student;
}
