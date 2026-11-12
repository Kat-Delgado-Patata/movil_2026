import 'package:flutter/material.dart';

import '../../../Routes/route.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await AuthService.instance.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _emailSent = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: _goToLogin,
                ),
              ),
              const SizedBox(height: 8),
              _buildHeader(context),
              const SizedBox(height: 28),
              if (_emailSent) _buildSuccessCard() else ...[
                _buildForm(),
                const SizedBox(height: 20),
                _buildDeliveryInfo(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _goToLogin,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Volver al inicio de sesión', style: TextStyle(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppColors.onSurface),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: AppColors.outline),
                  SizedBox(width: 6),
                  Text(
                    'Plataforma Académica Segura',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.lock, color: AppColors.primary, size: 38),
                ),
                Positioned(
                  right: -6,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceContainer, width: 3),
                    ),
                    child: const Icon(Icons.key, color: AppColors.onSecondary, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recuperar contraseña',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo institucional registrado para recibir un enlace seguro '
          'y restablecer tu clave de acceso.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Correo institucional', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  institutionalEmailDomain,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'estudiante$institutionalEmailDomain',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: Validators.institutionalEmail,
            onFieldSubmitted: (_) => _handleSubmit(),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.school_outlined, size: 14, color: AppColors.onSurfaceVariant),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Usa la cuenta institucional asignada por la universidad',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info, size: 18, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instrucciones de entrega',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                ),
                SizedBox(height: 4),
                Text(
                  'Te enviaremos un enlace de un solo uso para crear una nueva contraseña. '
                  'Revisa también tu carpeta de spam.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _buildSubmitButtonContent(),
      ),
    );
  }

  Widget _buildSubmitButtonContent() {
    if (_isSubmitting) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimary),
          ),
          SizedBox(width: 10),
          Text('Enviando enlace...'),
        ],
      );
    }
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.send, size: 20),
        SizedBox(width: 10),
        Text('Enviar enlace de recuperación', style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_read, color: AppColors.onTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Enlace enviado!',
                  style: const TextStyle(color: AppColors.onTertiary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa ${_emailController.text.trim()} y toca el enlace para crear una nueva contraseña.',
            style: const TextStyle(color: AppColors.onTertiaryContainer, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => setState(() => _emailSent = false),
            style: TextButton.styleFrom(foregroundColor: AppColors.onTertiary),
            child: const Text('Usar otro correo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
