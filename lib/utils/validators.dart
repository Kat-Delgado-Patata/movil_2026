const String institutionalEmailDomain = '@udla.edu.co';

/// Validadores reutilizables para los formularios de la app.
class Validators {
  Validators._();

  static final _emailFormat = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _hasDigit = RegExp(r'\d');

  static String? required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? institutionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo institucional';
    if (!_emailFormat.hasMatch(email)) return 'Ingresa un correo válido';
    if (!email.toLowerCase().endsWith(institutionalEmailDomain)) {
      return 'Debes usar tu correo institucional ($institutionalEmailDomain)';
    }
    return null;
  }

  /// Contraseña para iniciar sesión.
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static bool hasMinLength(String value) => value.length >= 8;
  static bool hasUpperAndLower(String value) =>
      RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value);
  static bool hasNumber(String value) => _hasDigit.hasMatch(value);

  /// Contraseña nueva con todos los requisitos de seguridad (crear cuenta y restablecer).
  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa una contraseña';
    if (!hasMinLength(value)) return 'Mínimo 8 caracteres';
    if (!hasUpperAndLower(value)) return 'Usa al menos una mayúscula y una minúscula';
    if (!hasNumber(value)) return 'Incluye al menos un número';
    return null;
  }

  /// Confirmación: debe ser igual a [password].
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != password) return 'Las contraseñas no coinciden';
    return null;
  }
}
