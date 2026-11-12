import 'package:flutter/material.dart';

import '../../../Routes/route.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';

class VerifyAccountScreen extends StatefulWidget {
  const VerifyAccountScreen({super.key});

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen> {
  bool _isChecking = false;
  bool _isResending = false;

  /// Correo enviado como argumento desde la pantalla de crear cuenta.
  String get _email {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is String ? args : (AuthService.instance.currentUser?.email ?? '');
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await AuthService.instance.resendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enlace reenviado a $_email')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleCheckVerified() async {
    setState(() => _isChecking = true);

    final verified = await AuthService.instance.reloadAndCheckEmailVerified();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no detectamos la verificación. Revisa tu correo y toca el enlace.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Cuenta verificada!')),
    );

    final appUser = await AuthService.instance.getCurrentAppUser();
    if (!mounted) return;
    final destination = appUser?.role == UserRole.teacher ? AppRoutes.homeTeacher : AppRoutes.homeStudent;
    Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 28),
              _buildCheckButton(),
              const SizedBox(height: 14),
              _buildResendButton(),
              const SizedBox(height: 20),
              _buildHelpCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: AppColors.secondary),
              SizedBox(width: 6),
              Text(
                'PASO 2 DE 2',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.mark_email_read, color: AppColors.primary, size: 44),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(Icons.verified_user, color: AppColors.onTertiary, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Verifica tu cuenta',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Te enviamos un enlace de verificación a:',
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
              const Icon(Icons.school_outlined, size: 16, color: AppColors.primary),
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
        const SizedBox(height: 10),
        Text(
          'Abre ese correo y toca el enlace. Cuando termines, vuelve aquí y presiona "Ya verifiqué mi correo".',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCheckButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
        onPressed: _isChecking ? null : _handleCheckVerified,
        child: _isChecking
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
                  Text('Ya verifiqué mi correo', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildResendButton() {
    return TextButton.icon(
      onPressed: _isResending ? null : _resendEmail,
      icon: _isResending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 18),
      label: const Text('Reenviar enlace', style: TextStyle(fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.secondary),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿No recibiste el correo institucional?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                ),
                SizedBox(height: 4),
                Text(
                  'Revisa tu bandeja de correo no deseado (spam) o acude con tu ID universitario '
                  'al soporte técnico de campus.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
