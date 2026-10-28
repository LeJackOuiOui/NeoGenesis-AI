import 'package:supabase_flutter/supabase_flutter.dart';

class CandidateInterviewService {
  final _supabase = Supabase.instance.client;

  // Obtener bloques libres del reclutador dueño de la vacante
  Future<List<Map<String, dynamic>>> getAvailableSlotsForVacancy(
    String vacancyId,
  ) async {
    // 1. Obtener el ID del reclutador (created_by) desde la tabla 'vacantes'
    final vacancyRes = await _supabase
        .from('vacantes')
        .select('created_by')
        .eq('id', vacancyId)
        .single();

    final recruiterId = vacancyRes['created_by'];

    // 2. Consultar los bloques de disponibilidad que NO estén reservados
    final slots = await _supabase
        .from('recruiter_availability')
        .select()
        .eq('recruiter_id', recruiterId)
        .eq('is_booked', false)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(slots);
  }

  // Confirmar y registrar la entrevista seleccionada
  Future<void> bookInterview({
    required String vacancyId,
    required String candidateId,
    required String recruiterId,
    required String availabilityId,
    required DateTime scheduledDateTime,
  }) async {
    // 1. Crear el registro en la tabla de entrevistas
    await _supabase.from('interviews').insert({
      'vacancy_id': vacancyId,
      'candidate_id': candidateId,
      'recruiter_id': recruiterId,
      'availability_id': availabilityId,
      'scheduled_at': scheduledDateTime.toIso8601String(),
      'status': 'scheduled',
    });

    // 2. Marcar el bloque como reservado para que nadie más lo tome
    await _supabase
        .from('recruiter_availability')
        .update({'is_booked': true})
        .eq('id', availabilityId);
  }
}
