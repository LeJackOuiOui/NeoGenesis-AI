import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class HrAssistantService {
  final SupabaseClient _client;

  const HrAssistantService(this._client);

  Future<Map<String, dynamic>> ask(String question) async {
    try {
      final response = await _client.functions.invoke(
        'hr-assistant',
        body: {'question': question},
      );
      if (response.data is! Map) {
        throw const HrAssistantException(
          'El asistente devolvió una respuesta inválida.',
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionsFetchException catch (error) {
      throw HrAssistantException(
        'No se pudo conectar con la función hr-assistant de Supabase. '
        'Verifica que esté desplegada y que su configuración CORS permita '
        'la aplicación. Detalle técnico: ${error.details}',
      );
    } on FunctionException catch (error) {
      final message = _functionErrorMessage(error);
      if (message != null) throw HrAssistantException(message);
      if (error.status == 404) {
        throw const HrAssistantException(
          'La función hr-assistant no está desplegada en Supabase.',
        );
      }
      if (error.status == 401) {
        throw const HrAssistantException(
          'La sesión expiró. Cierra sesión e inicia nuevamente.',
        );
      }
      throw HrAssistantException(
        'No se pudo procesar la consulta '
        '(${error.status}${error.reasonPhrase == null ? '' : ': ${error.reasonPhrase}'}).',
      );
    }
  }

  String? _functionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) return details['error']?.toString();
    if (details is String && details.isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map && decoded['error'] is String) {
          return decoded['error'] as String;
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMyInteractions() async {
    final employeeId = _requireUserId();

    try {
      final response = await _client
          .from('hr_assistant_interactions')
          .select('id, question, answer, status, sources, created_at')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(response).reversed.toList();
    } on PostgrestException catch (error) {
      throw HrAssistantException(_databaseErrorMessage(error));
    }
  }

  Future<List<Map<String, dynamic>>> getEscalatedInteractions() async {
    _requireUserId();
    try {
      final response = await _client
          .from('hr_assistant_interactions')
          .select('id, employee_name, employee_email, question, created_at')
          .eq('status', 'waiting_for_hr')
          .order('created_at', ascending: true)
          .limit(100);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (error) {
      throw HrAssistantException(_databaseErrorMessage(error));
    }
  }

  Future<void> answerEscalatedInteraction({
    required String interactionId,
    required String answer,
  }) async {
    final employeeId = _requireUserId();

    try {
      final response = await _client
          .from('hr_assistant_interactions')
          .update({
            'answer': answer.trim(),
            'status': 'answered',
            'answered_by': employeeId,
            'answered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', interactionId)
          .eq('status', 'waiting_for_hr')
          .select('id')
          .maybeSingle();
      if (response == null) {
        throw const HrAssistantException(
          'La consulta ya fue respondida o no está disponible.',
        );
      }
    } on PostgrestException catch (error) {
      throw HrAssistantException(_databaseErrorMessage(error));
    }
  }

  String _databaseErrorMessage(PostgrestException error) {
    if (error.code == 'PGRST205') {
      return 'La tabla de consultas del asistente aún no existe en Supabase. '
          'Aplica la migración '
          'supabase/migrations/202610290001_create_hr_assistant.sql '
          'desde Supabase SQL Editor y vuelve a intentarlo.';
    }
    return error.message;
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const HrAssistantException('Debes iniciar sesión nuevamente.');
    }
    return userId;
  }
}

class HrAssistantException implements Exception {
  final String message;

  const HrAssistantException(this.message);

  @override
  String toString() => message;
}
