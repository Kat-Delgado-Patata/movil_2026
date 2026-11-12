import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/validators.dart';
import '../../../widgets/password_strength_bar.dart';

/// Cambiar contraseña estando autenticado (se abre desde "Mi Perfil · Seguridad y Contraseña").
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _showSuccess = true;
      });

      // Deja ver el aviso de éxito antes de volver al perfil.
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Volver',
                    onPressed: _isSubmitting || _showSuccess ? null : () => Navigator.pop(context),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _showSuccess ? _buildSuccessBanner() : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 16),
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildFormCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_outlined, size: 14, color: AppColors.outline),
                    SizedBox(width: 6),
                    Text(
                      'Validación institucional AsistApp v1.0',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.onTertiaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 16, color: AppColors.tertiaryContainer),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Contraseña actualizada con éxito!',
                  style: TextStyle(color: AppColors.onTertiary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Tus credenciales de AsistApp han sido actualizadas.',
                  style: TextStyle(color: AppColors.onTertiaryContainer, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onTertiary, size: 20),
            tooltip: 'Cerrar',
            onPressed: () => setState(() => _showSuccess = false),
          ),
        ],
      ),
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.secondaryContainer, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x33003EA8), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.lock_reset, color: AppColors.onPrimary, size: 38),
            ),
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(Icons.verified_user, color: AppColors.onTertiary, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Cambiar contraseña',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Confirma tu contraseña actual y crea una nueva para proteger el acceso a tus clases y registros de asistencia.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final password = _passwordController.text;
    final strength = PasswordStrengthBar.strengthOf(password);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Contraseña actual'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.lock_person_outlined),
              suffixIcon: _visibilityToggle(
                _obscureCurrent,
                () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            validator: (v) => Validators.required(v, 'Ingresa tu contraseña actual'),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('Nueva contraseña'),
              Text(
                PasswordStrengthBar.labelOf(strength),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: PasswordStrengthBar.colorOf(strength),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: _visibilityToggle(
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: Validators.strongPassword,
          ),
          const SizedBox(height: 10),
          PasswordStrengthBar(password: password),
          const SizedBox(height: 18),
          _label('Confirmar nueva contraseña'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: '••••••••••••',
              prefixIcon: const Icon(Icons.check_circle_outline),
              suffixIcon: _visibilityToggle(
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) => Validators.confirmPassword(v, password),
            onFieldSubmitted: (_) => _handleSubmit(),
          ),
          const SizedBox(height: 18),
          _buildRequirements(password),
        ],
      ),
    );
  }

  Widget _buildRequirements(String password) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REQUISITOS DE SEGURIDAD',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _requirement('Al menos 8 caracteres', Validators.hasMinLength(password)),
          _requirement('Al menos una letra mayúscula y una minúscula', Validators.hasUpperAndLower(password)),
          _requirement('Al menos un número', Validators.hasNumber(password)),
        ],
      ),
    );
  }

  Widget _requirement(String text, bool met) {
    final color = met ? AppColors.tertiaryContainer : AppColors.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met ? Icons.check_circle : Icons.check,
              key: ValueKey(met),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: met ? AppColors.onSurface : AppColors.onSurfaceVariant,
                fontWeight: met ? FontWeight.w500 : FontWeight.normal,
              ),
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
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
        onPressed: _isSubmitting || _showSuccess ? null : _handleSubmit,
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
                  Text('Guardando...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 20),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Guardar nueva contraseña',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
      onPressed: onPressed,
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
  }
}
