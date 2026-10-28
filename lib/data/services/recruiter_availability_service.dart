import 'package:supabase_flutter/supabase_flutter.dart';

class RecruiterAvailabilityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Insertar bloque
  Future<void> addAvailabilityBlock({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final formattedDate = date.toIso8601String().split('T')[0];

    await _supabase.from('recruiter_availability').insert({
      'recruiter_id': user.id,
      'date': formattedDate,
      'start_time': startTime,
      'end_time': endTime,
      'is_booked': false,
    });
  }

  // Obtener bloques del reclutador (y opcionalmente limpiar los vencidos)
  Future<List<Map<String, dynamic>>> getMyAvailability() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Opcional: Eliminar automáticamente los bloques cuya fecha ya pasó y no fueron reservados
    await _supabase
        .from('recruiter_availability')
        .delete()
        .eq('recruiter_id', user.id)
        .eq('is_booked', false)
        .lt('date', today);

    // Obtener los vigentes
    final response = await _supabase
        .from('recruiter_availability')
        .select()
        .eq('recruiter_id', user.id)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // Actualizar un bloque existente
  Future<void> updateAvailabilityBlock({
    required String id,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    final formattedDate = date.toIso8601String().split('T')[0];
    await _supabase
        .from('recruiter_availability')
        .update({
          'date': formattedDate,
          'start_time': startTime,
          'end_time': endTime,
        })
        .eq('id', id);
  }

  // Eliminar un bloque
  Future<void> deleteAvailabilityBlock(String id) async {
    await _supabase.from('recruiter_availability').delete().eq('id', id);
  }
}
