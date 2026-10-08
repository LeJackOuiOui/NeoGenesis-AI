import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/api_service.dart';

class OtpVerificationDialog extends StatefulWidget {
  final String email;
  final ApiService apiService;

  const OtpVerificationDialog({
    super.key,
    required this.email,
    required this.apiService,
  });

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el código completo de 6 dígitos.'),
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final response = await widget.apiService.verifyOtp(
        email: widget.email,
        token: code,
      );

      if (!mounted) return;

      if (response.session != null) {
        Navigator.pop(context, true); // Verificación exitosa
      } else {
        throw Exception('No se pudo iniciar sesión con el OTP.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Código inválido o expirado: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Verificación OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ingresa el código de 6 dígitos enviado a:\n${widget.email}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: _isVerifying ? null : _handleVerify,
          child: _isVerifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Verificar'),
        ),
      ],
    );
  }
}
