import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../main.dart';

class RegisterModal extends StatefulWidget {
  final bool isRRHH;

  const RegisterModal({super.key, this.isRRHH = false});

  @override
  State<RegisterModal> createState() => _RegisterModalState();
}

class _RegisterModalState extends State<RegisterModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nitController = TextEditingController();
  final _rutController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isRRHH => widget.isRRHH;

  String get _selectedRole => 'Empleado';

  String get _selectedPosition =>
      _isRRHH ? 'Responsable de Recursos Humanos' : 'Empleado';

  String? _validateNit(String? value) {
    final nit = value?.trim() ?? '';
    if (nit.isEmpty) return 'Ingresa el NIT de la empresa.';
    if (!RegExp(r'^\d{9,10}$').hasMatch(nit)) {
      return 'El NIT debe tener entre 9 y 10 dígitos.';
    }
    return null;
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nitController.dispose();
    _rutController.dispose();
    _companyAddressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _guardarRegistro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim().toLowerCase();

    try {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {
          'full_name': _nameController.text.trim(),
          'position': _selectedPosition,
          'role': _selectedRole,
          'isRRHH': _isRRHH,
          'phone': _phoneController.text.trim(),
          if (_isRRHH) ...{
            'company_nit': _nitController.text.trim(),
            'company_rut': _rutController.text.trim(),
            'company_address': _companyAddressController.text.trim(),
            'company_verification_status': 'pending',
          },
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw const AuthException('No se pudo crear el usuario.');
      }

      // The database trigger creates the profile when email confirmation is enabled.
      // If a session is available, this also repairs profiles created before the trigger.
      if (authResponse.session != null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'nombre': _nameController.text.trim(),
          'email': email,
          'telefono': _phoneController.text.trim(),
          'role': _selectedRole,
          if (_isRRHH) ...{
            'company_nit': _nitController.text.trim(),
            'company_rut': _rutController.text.trim(),
            'company_address': _companyAddressController.text.trim(),
            'company_verification_status': 'pending',
          },
        });
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authResponse.session == null
                ? _isRRHH
                      ? 'Solicitud de empresa creada. Revisa tu correo para confirmar el acceso; la verificación está pendiente.'
                      : 'Cuenta creada. Revisa tu correo para confirmar el acceso.'
                : _isRRHH
                ? 'Solicitud de empresa creada. La verificación está pendiente.'
                : 'Cuenta creada correctamente. Ya puedes iniciar sesión.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La cuenta se creó, pero no se pudo guardar el perfil: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.textDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ENCABEZADO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Crear Cuenta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Regístrate para comenzar a usar NEOGENESIS IA',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 24),

                Text(
                  _isRRHH ? 'Razón social' : 'Nombre completo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: _isRRHH
                      ? null
                      : [FormValidators.nameInputFormatter],
                  maxLength: 100,
                  buildCounter: _hideCounter,
                  decoration: _inputDecoration(
                    _isRRHH ? 'Razón social registrada' : 'Tu nombre completo',
                  ),
                  validator: _isRRHH
                      ? (value) => FormValidators.requiredText(
                          value,
                          label: 'El nombre de la empresa',
                          minLength: 2,
                          maxLength: 100,
                        )
                      : FormValidators.personName,
                ),
                if (_isRRHH) ...[
                  const SizedBox(height: 16),
                  _buildFieldLabel('NIT'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nitController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    buildCounter: _hideCounter,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'NIT, con dígito de verificación',
                    ),
                    validator: _validateNit,
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('Número de registro del RUT'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rutController,
                    maxLength: 30,
                    buildCounter: _hideCounter,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Número impreso en el RUT'),
                    validator: (value) => FormValidators.requiredText(
                      value,
                      label: 'El número de registro del RUT',
                      minLength: 3,
                      maxLength: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel('Dirección de la empresa'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _companyAddressController,
                    maxLength: 200,
                    buildCounter: _hideCounter,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Dirección registrada'),
                    validator: (value) => FormValidators.requiredText(
                      value,
                      label: 'La dirección de la empresa',
                      minLength: 5,
                      maxLength: 200,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La información se guardará como pendiente de verificación. '
                    'El registro no confirma automáticamente la identidad de la empresa.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),

                // CAMPO: CORREO ELECTRÓNICO
                _buildFieldLabel(
                  _isRRHH ? 'Correo de contacto' : 'Correo electrónico',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [FormValidators.emailInputFormatter],
                  maxLength: 254,
                  buildCounter: _hideCounter,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ejemplo@correo.com',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: FormValidators.email,
                ),
                const SizedBox(height: 16),

                _buildFieldLabel(_isRRHH ? 'Teléfono de contacto' : 'Teléfono'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FormValidators.phoneInputFormatter],
                  maxLength: 20,
                  buildCounter: _hideCounter,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Tu número de teléfono'),
                  validator: FormValidators.phone,
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Contraseña'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _inputDecoration(
                        'Contraseña (mínimo 8 caracteres, letras y números)',
                      ).copyWith(
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                  validator: FormValidators.password,
                ),
                const SizedBox(height: 24),

                // BOTÓN DE REGISTRO
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardarRegistro,
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
                            'Registrarse',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget? _hideCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}
