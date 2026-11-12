import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra de 3 segmentos que indica qué tan segura es una contraseña.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  /// Fuerza de la contraseña de 0 a 3 (segmentos de la barra).
  static int strengthOf(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) ||
        (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password))) {
      score++;
    }
    return score;
  }

  static Color colorOf(int strength) => switch (strength) {
        1 => AppColors.error,
        2 => AppColors.secondary,
        3 => AppColors.tertiaryContainer,
        _ => AppColors.surfaceContainerHigh,
      };

  static String labelOf(int strength) => switch (strength) {
        1 => 'DÉBIL',
        2 => 'MEDIA',
        3 => 'FUERTE',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final strength = strengthOf(password);
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 4,
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: i < strength ? colorOf(strength) : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
