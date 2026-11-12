import 'package:flutter/material.dart';

import '../../../Routes/route.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/verification_code_card.dart';

/// Paso 2 de recuperar contraseña: ingresar el código enviado al correo.
class ResetCodeScreen extends StatefulWidget {
  const ResetCodeScreen({super.key});

  @override
  State<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends State<ResetCodeScreen> {
  String _code = '';
  bool _isSubmitting = false;
  bool _showCodeError = false;

  /// Correo enviado como argumento desde la pantalla de recuperar contraseña.
  String get _email {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is String ? args : '';
  }

  void _resendCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nuevo código enviado a $_email')),
    );
  }

  Future<void> _handleVerify() async {
    if (_code.length != verificationCodeLength) {
      setState(() => _showCodeError = true);
      return;
    }

    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pushReplacementNamed(context, AppRoutes.newPassword, arguments: _email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.pin, color: AppColors.primary, size: 38),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Ingresa el código',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Escribe el código de seguridad que enviamos a:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alternate_email, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              VerificationCodeCard(
                hasError: _showCodeError,
                onChanged: (code) => setState(() {
                  _code = code;
                  _showCodeError = false;
                }),
                onResend: _resendCode,
              ),
              const SizedBox(height: 20),
              _buildVerifyButton(),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'El código es de un solo uso y vence en 15 minutos.',
                      style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleVerify,
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
                  ),
                  SizedBox(width: 10),
                  Text('Verificando...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Verificar código', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }
}
