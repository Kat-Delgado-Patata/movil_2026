import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../Routes/route.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/validators.dart';
import '../../../widgets/password_strength_bar.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentCodeController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentCodeController.dispose();
    super.dispose();
  }

  String get _roleHint => _role == UserRole.student
      ? 'Podrás marcar asistencia en tus asignaturas matriculadas.'
      : 'Podrás gestionar la asistencia de tus asignaturas a cargo.';

  Future<void> _handleSubmit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!formValid || !_acceptedTerms) return;

    setState(() => _isSubmitting = true);

    try {
      await AuthService.instance.signUp(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _role,
        studentCode: _role == UserRole.student ? _studentCodeController.text : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pushNamed(
        context,
        AppRoutes.verifyAccount,
        arguments: _emailController.text.trim(),
      );
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildRoleSelector(),
                if (_role == UserRole.student) ...[
                  const SizedBox(height: 16),
                  _buildStudentCodeField(),
                ],
                const SizedBox(height: 20),
                _buildNameFields(),
                const SizedBox(height: 16),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 20),
                _buildTermsCheckbox(),
                const SizedBox(height: 20),
                _buildSubmitButton(),
                const SizedBox(height: 10),
                _buildCodeNotice(),
                const SizedBox(height: 32),
                _buildLoginPrompt(),
              ],
            ),
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
          onPressed: _goToLogin,
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
                'PASO 1 DE 2',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear cuenta',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Regístrate con tu correo institucional para sincronizar tus asistencias.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Selecciona tu rol académico'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _roleTab(UserRole.student, Icons.school, 'Estudiante')),
              Expanded(child: _roleTab(UserRole.teacher, Icons.co_present_outlined, 'Docente')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _roleHint,
                style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildStudentCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Código universitario'),
        TextFormField(
          controller: _studentCodeController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Ej. 202410881',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (v) => _role == UserRole.student
              ? Validators.required(v, 'Ingresa tu código universitario')
              : null,
        ),
        const SizedBox(height: 4),
        const Text(
          'Es el mismo código que tu docente usa para matricularte en sus cursos.',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildNameFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Nombres'),
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Ej. Carlos'),
                validator: (v) => Validators.required(v, 'Ingresa tus nombres'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Apellidos'),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'Ej. Mendoza'),
                validator: (v) => Validators.required(v, 'Ingresa tus apellidos'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Correo institucional'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'usuario$institutionalEmailDomain',
            prefixIcon: Icon(Icons.domain, color: AppColors.secondary),
          ),
          validator: Validators.institutionalEmail,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  children: [
                    const TextSpan(text: 'Debe terminar estrictamente en '),
                    TextSpan(
                      text: institutionalEmailDomain,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Contraseña'),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: Validators.strongPassword,
        ),
        const SizedBox(height: 8),
        PasswordStrengthBar(password: _passwordController.text),
        const SizedBox(height: 6),
        const Text(
          'Mínimo 8 caracteres, mayúscula, minúscula y un número',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: _showTermsError ? Border.all(color: AppColors.error, width: 1.5) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() {
                    _acceptedTerms = v ?? false;
                    if (_acceptedTerms) _showTermsError = false;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                    children: [
                      const TextSpan(text: 'Acepto los '),
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Funcionalidad próximamente disponible')),
                            );
                          },
                      ),
                      const TextSpan(
                        text: ' del sistema y la política de geolocalización y asistencia del campus.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showTermsError)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Debes aceptar los términos para continuar',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
        onPressed: _isSubmitting ? null : _handleSubmit,
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
                  Text('Enviando código...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continuar y verificar correo', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildCodeNotice() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 14, color: AppColors.tertiaryContainer),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Se enviará un código seguro de 6 dígitos a tu correo.',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('¿Ya tienes cuenta institucional?', style: TextStyle(color: AppColors.onSurfaceVariant)),
        TextButton(
          onPressed: _goToLogin,
          child: const Text(
            'Iniciar sesión',
            style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}


