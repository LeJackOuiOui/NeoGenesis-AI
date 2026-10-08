import 'package:flutter/services.dart';

class FormValidators {
  const FormValidators._();

  static final nameInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ .'-]"),
  );

  static final emailInputFormatter = FilteringTextInputFormatter.deny(
    RegExp(r'\s'),
  );

  static final phoneInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9+()\- ]'),
  );

  static final decimalInputFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    if (newValue.text.isEmpty ||
        RegExp(r'^\d*(?:[.,]\d{0,2})?$').hasMatch(newValue.text)) {
      return newValue; // Return the new value if valid
    }
    return oldValue;
  });

  static String? requiredText(
    String? value, {
    String label = 'Este campo',
    int minLength = 1,
    int maxLength = 200,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label es obligatorio.';
    if (text.length < minLength)
      return '$label debe tener al menos $minLength caracteres.';
    if (text.length > maxLength)
      return '$label no puede superar $maxLength caracteres.';
    return null;
  }

  static String? personName(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Ingresa el nombre completo.' : null;
    if (text.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
    if (text.length > 100) return 'El nombre no puede superar 100 caracteres.';
    if (RegExp(r'\d').hasMatch(text))
      return 'El nombre no puede contener números.';
    if (!RegExp(r"^[a-zA-ZÀ-ÖØ-öø-ÿ][a-zA-ZÀ-ÖØ-öø-ÿ .'-]*$").hasMatch(text)) {
      return 'El nombre solo puede contener letras, espacios, puntos, apóstrofes o guiones.';
    }
    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Ingresa el correo electrónico.' : null;
    if (text.length > 254) return 'El correo no puede superar 254 caracteres.';
    if (!RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
    ).hasMatch(text)) {
      return 'Ingresa un correo válido, por ejemplo nombre@dominio.com.';
    }
    final localPart = text.split('@').first;
    if (localPart.length > 64 ||
        localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..')) {
      return 'Revisa el formato del correo electrónico.';
    }
    return null;
  }

  static String? phone(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Ingresa el teléfono.' : null;
    if (!RegExp(r'^[0-9+()\- ]+$').hasMatch(text)) {
      return 'El teléfono solo puede contener números y + ( ) -.';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'El teléfono debe tener entre 7 y 15 dígitos.';
    }
    if (text.indexOf('+') > 0 || text.indexOf('+') != text.lastIndexOf('+')) {
      return 'El signo + solo se permite una vez y al inicio.';
    }
    return null;
  }

  static String? positiveNumber(
    String? value, {
    String label = 'El valor',
    bool allowZero = false,
    double? maximum,
  }) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty) return '$label es obligatorio.';
    final number = double.tryParse(text);
    if (number == null || !number.isFinite) return '$label debe ser numérico.';
    if (allowZero ? number < 0 : number <= 0) {
      return allowZero
          ? '$label no puede ser negativo.'
          : '$label debe ser mayor que cero.';
    }
    if (maximum != null && number > maximum) {
      return '$label no puede ser mayor que ${maximum.toStringAsFixed(0)}.';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    final text = value ?? '';
    if (text.isEmpty) return 'Ingresa una contraseña.';
    if (text.length < minLength) return 'Usa al menos $minLength caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'La contraseña debe incluir al menos una letra y un número.';
    }
    return null;
  }

  static String? confirmedPassword(String? value, String passwordValue) {
    if (value == null || value.isEmpty) return 'Confirma la contraseña.';
    if (value != passwordValue) return 'Las contraseñas no coinciden.';
    return null;
  }
}
