import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/services/api_service.dart';
import '../../main.dart';
import '../../data/services/audit_service.dart';

class LoginModal extends StatefulWidget {
  const LoginModal({super.key});

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nitController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final ApiService _apiService;
  late final AuditService _auditService;

  bool _isEmpresa = false; // Toggle: false = Usuario, true = Empresa
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(supabase);
    _auditService = AuditService(supabase);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nitController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final nit = _nitController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1. Iniciar sesión en Supabase
      await _apiService.login(email: email, password: password);

      // 2. Obtener el perfil del usuario logueado
      final userProfile = await _apiService.getCurrentUserProfile();
      final currentUserId = supabase.auth.currentUser?.id;

      // 3. Si seleccionó Empresa, validamos que el NIT coincida con su perfil registrado
      if (_isEmpresa) {
        if (userProfile == null || userProfile.companyNit != nit) {
          await _apiService.signOut();
          _showMessage(
            'El NIT ingresado no coincide con el registrado en esta cuenta corporativa.',
            isError: true,
          );
          return;
        }
      }

      await _auditService.logAuthAttempt(
        email: email,
        exitoso: true,
        usuarioId: currentUserId,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('Inicio de sesión exitoso.', isError: false);
    } on AuthException catch (error) {
      await _auditService.logAuthAttempt(
        email: email,
        exitoso: false,
        detalleError: error.message,
      );
      _showMessage(error.message, isError: true);
    } catch (error) {
      await _auditService.logAuthAttempt(
        email: email,
        exitoso: false,
        detalleError: error.toString(),
      );
      _showMessage(
        'No se pudo iniciar sesión. Verifica tus credenciales.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryGreen,
      ),
    );
  }

  Widget? _hideCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 560),
        child: Row(
          children: [
            // Panel Izquierdo Decorativo
            Expanded(
              child: Container(
                color: AppTheme.lightGreenBg,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_Neogenesis.png',
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.auto_awesome,
                        size: 100,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                        children: [
                          TextSpan(text: 'Bienvenido a\n'),
                          TextSpan(
                            text: 'NeoGenesis ',
                            style: TextStyle(color: AppTheme.textDark),
                          ),
                          TextSpan(
                            text: 'IA',
                            style: TextStyle(color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Inicia sesión para acceder a todas las funcionalidades de la plataforma y gestionar tu información de manera segura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Panel Derecho con Formulario y Toggle
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TOGGLE SUPERIOR (Usuario / Empresa)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isEmpresa = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isEmpresa
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !_isEmpresa
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Usuario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isEmpresa
                                          ? AppTheme.primaryGreen
                                          : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isEmpresa = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isEmpresa
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _isEmpresa
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Empresa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isEmpresa
                                          ? AppTheme.primaryGreen
                                          : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        _isEmpresa
                            ? 'Portal de Empresas'
                            : 'Portal de Usuarios',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEmpresa
                            ? 'Ingresa el NIT y tus credenciales'
                            : 'Ingresa tus credenciales para continuar',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Campo NIT exclusivo si es empresa
                      if (_isEmpresa) ...[
                        TextFormField(
                          controller: _nitController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'NIT de la empresa',
                            prefixIcon: const Icon(
                              Icons.business_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (value) {
                            if (_isEmpresa &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Ingresa el NIT de la empresa';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [FormValidators.emailInputFormatter],
                        maxLength: 254,
                        buildCounter: _hideCounter,
                        decoration: InputDecoration(
                          hintText: 'Correo electrónico',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Ingresa tu contraseña'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Iniciar sesión',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
