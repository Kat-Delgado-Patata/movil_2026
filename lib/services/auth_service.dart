import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

/// Error legible para mostrar en la UI (ya traducido a español).
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Capa única de acceso a Firebase Auth + el documento de usuario en Firestore.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  /// Emite cada vez que cambia la sesión (login/logout).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Perfil de Firestore del usuario autenticado, o null si no hay sesión o no existe el documento.
  Stream<AppUser?> watchCurrentAppUser() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _usersRef.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromMap(doc.id, data);
    });
  }

  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      final doc = await _usersRef.doc(uid).get();
      if (!doc.exists) {
        throw AuthException('No encontramos tu perfil. Contacta a soporte.');
      }
      return AppUser.fromMap(uid, doc.data()!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  Future<AppUser> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserRole role,
    String? studentCode,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      final appUser = AppUser(
        uid: user.uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        role: role,
        studentCode: role == UserRole.student ? studentCode?.trim() : null,
      );
      await _usersRef.doc(user.uid).set(appUser.toCreateMap());
      try {
        // No bloqueamos el registro si falla el envío; se puede reenviar desde "Verificar cuenta".
        await user.sendEmailVerification();
      } catch (_) {
        // Ignorado a propósito.
      }
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  /// Perfil de Firestore del usuario autenticado en este instante (una sola lectura).
  Future<AppUser?> getCurrentAppUser() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _usersRef.doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromMap(doc.id, data);
  }

  /// Reenvía el enlace de verificación al correo del usuario autenticado.
  Future<void> resendEmailVerification() async {
    final user = currentUser;
    if (user == null) throw AuthException('No hay una sesión activa');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  /// Recarga el usuario y devuelve si ya confirmó el enlace de verificación.
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Cambia la contraseña del usuario ya autenticado (requiere re-ingresar la actual).
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw AuthException('No hay una sesión activa');
    }
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo institucional';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo';
      case 'weak-password':
        return 'La contraseña es demasiado débil';
      case 'invalid-email':
        return 'El correo no es válido';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'network-request-failed':
        return 'Sin conexión a internet';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada';
      default:
        return 'Ocurrió un error. Intenta nuevamente';
    }
  }
}
