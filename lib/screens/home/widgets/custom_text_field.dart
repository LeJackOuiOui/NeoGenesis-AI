
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final int? maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.maxLength,
    this.buildCounter,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      maxLength: maxLength,
      buildCounter: buildCounter,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, size: 20),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                icon: Icon(suffixIcon),
                onPressed: onSuffixPressed,
              ),
      ),
    );
  }
}
