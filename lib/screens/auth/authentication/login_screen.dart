import 'package:flutter/material.dart';

import '../../../Routes/route.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _loginSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _roleHint =>
      _role == UserRole.student ? 'Acceso Alumno' : 'Acceso Docente';

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _loginSuccess = false;
    });

    try {
      final appUser = await AuthService.instance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _loginSuccess = true;
      });

      // Navegamos según el rol real guardado en Firestore, no según el tab elegido en la UI.
      final destination = appUser.role == UserRole.teacher ? AppRoutes.homeTeacher : AppRoutes.homeStudent;
      Navigator.pushReplacementNamed(context, destination);
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
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
          child: Column(
            children: [
              _buildBrandIntro(context),
              const SizedBox(height: 24),
              _buildRoleSelector(context),
              const SizedBox(height: 20),
              _buildLoginCard(context),
              const SizedBox(height: 20),
              _buildSignUpPrompt(context),
              const SizedBox(height: 24),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandIntro(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.school, color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: AppColors.primary, size: 15),
              const SizedBox(width: 6),
              Text(
                'PORTAL ACADÉMICO OFICIAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'AsistApp',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestión y control de asistencia universitaria',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _roleTab(UserRole.student, Icons.school, 'Estudiante')),
          Expanded(child: _roleTab(UserRole.teacher, Icons.menu_book, 'Docente')),
        ],
      ),
    );
  }

  Widget _roleTab(UserRole role, IconData icon, String label) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Correo institucional', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  _roleHint,
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'ejemplo@udla.edu.co',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: Validators.institutionalEmail,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Contraseña', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '••••••••••••',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: Validators.loginPassword,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: _loginSuccess
                    ? ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tertiaryContainer,
                        foregroundColor: AppColors.onTertiaryContainer,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      )
                    : null,
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _buildSubmitButtonContent(),
              ),
            ),
          ],
        ),
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
          Text('Verificando credenciales...'),
        ],
      );
    }
    if (_loginSuccess) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle),
          SizedBox(width: 10),
          Text('¡Sesión Iniciada!'),
        ],
      );
    }
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.login),
        SizedBox(width: 10),
        Text('Iniciar sesión'),
      ],
    );
  }

  Widget _buildSignUpPrompt(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿Aún no tienes una cuenta?', style: TextStyle(color: AppColors.onSurfaceVariant)),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.createAccount),
          child: const Text(
            'Crear cuenta',
            style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.support_agent, size: 16, color: AppColors.onSurfaceVariant),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Mesa de Ayuda TI: soporte@udla.edu.co',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'v1.0 - Campus Digital Académico',
          style: TextStyle(fontSize: 11, color: AppColors.outline),
        ),
      ],
    );
  }
}
