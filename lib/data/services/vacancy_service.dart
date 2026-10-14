import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/candidate_model.dart';
import '../models/vacancy_model.dart';
import 'candidate_criteria_evaluator.dart';

class VacancyService {
  final SupabaseClient client;

  const VacancyService(this.client);

  Future<List<VacancyModel>> fetchVacancies() async {
    final currentUser = client.auth.currentUser;
    final metadata = currentUser?.userMetadata;
    final isRRHH =
        metadata?['isRRHH'] == true ||
        metadata?['role']?.toString().toLowerCase() == 'responsable rrhh';

    var query = client
        .from('vacantes')
        .select(
          'id, title, min_experience_years, required_skills, min_education_level, removed_candidate_ids, created_by',
        );

    // Si es una empresa, mostramos únicamente sus vacantes creadas
    if (isRRHH && currentUser != null) {
      query = query.eq('created_by', currentUser.id);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((row) => VacancyModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> aplicarAVacante(String vacancyId) async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('Debes iniciar sesión para postularte.');
    }

    await client.from('postulaciones').insert({
      'vacante_id': vacancyId,
      'usuario_id': currentUser.id,
      'estado': 'enviada',
    });
  }

  Future<VacancyModel> saveVacancy({
    String? id,
    required String title,
    required double minExperienceYears,
    required List<String> requiredSkills,
    required String minEducationLevel,
  }) async {
    final currentUser = client.auth.currentUser;
    final vacancyId = id ?? _newVacancyId();
    final payload = {
      'id': vacancyId,
      'title': title.trim(),
      'min_experience_years': minExperienceYears,
      'required_skills': requiredSkills,
      'min_education_level': minEducationLevel,
      if (id == null && currentUser != null) 'created_by': currentUser.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = id == null
        ? await client.from('vacantes').insert(payload).select().single()
        : await client
              .from('vacantes')
              .update(payload)
              .eq('id', vacancyId)
              .select()
              .single();
    return VacancyModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteVacancy(String vacancyId) async {
    final deleted = await client
        .from('vacantes')
        .delete()
        .eq('id', vacancyId)
        .select('id')
        .maybeSingle();
    if (deleted == null) {
      throw Exception(
        'No se pudo eliminar la vacante. Verifica tus permisos de reclutador.',
      );
    }
  }

  Future<void> removeCandidateFromVacancy({
    required String vacancyId,
    required String candidateId,
  }) async {
    final row = await client
        .from('vacantes')
        .select('removed_candidate_ids, evaluations')
        .eq('id', vacancyId)
        .maybeSingle();
    if (row == null) throw Exception('No se encontró la vacante.');

    final removedIds = row['removed_candidate_ids'] is List
        ? (row['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : <String>{};
    removedIds.add(candidateId);
    final evaluations = row['evaluations'] is Map
        ? Map<String, dynamic>.from(row['evaluations'] as Map)
        : <String, dynamic>{};
    evaluations.remove(candidateId);

    await client
        .from('vacantes')
        .update({
          'removed_candidate_ids': removedIds.toList(),
          'evaluations': evaluations,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vacancyId);
  }

  Future<void> restoreCandidateToVacancy({
    required String vacancyId,
    required String candidateId,
  }) async {
    final row = await client
        .from('vacantes')
        .select('removed_candidate_ids')
        .eq('id', vacancyId)
        .maybeSingle();
    if (row == null) throw Exception('No se encontró la vacante.');

    final removedIds = row['removed_candidate_ids'] is List
        ? (row['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : <String>{};
    removedIds.remove(candidateId);
    await client
        .from('vacantes')
        .update({
          'removed_candidate_ids': removedIds.toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vacancyId);
  }

  String _newVacancyId() {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<Map<String, CandidateEvaluation>> evaluateCandidates({
    required VacancyModel vacancy,
    required List<CandidateModel> candidates,
  }) async {
    final vacancyRow = await client
        .from('vacantes')
        .select('removed_candidate_ids')
        .eq('id', vacancy.id)
        .maybeSingle();
    final removedIds = vacancyRow?['removed_candidate_ids'] is List
        ? (vacancyRow!['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : vacancy.removedCandidateIds.toSet();
    final evaluatedAt = DateTime.now().toUtc();
    final evaluations = <String, CandidateEvaluation>{};
    for (final candidate in candidates) {
      if (removedIds.contains(candidate.id)) continue;
      final reasons = CandidateCriteriaEvaluator.exclusionReasonsFor(
        candidate,
        vacancy,
      );
      evaluations[candidate.id] = CandidateEvaluation(
        candidateId: candidate.id,
        meetsCriteria: reasons.isEmpty,
        exclusionReasons: reasons,
        evaluatedAt: evaluatedAt,
      );
    }

    final evaluationData = {
      for (final entry in evaluations.entries)
        entry.key: {
          'meets_criteria': entry.value.meetsCriteria,
          'exclusion_reasons': entry.value.exclusionReasons,
          'evaluated_at': evaluatedAt.toIso8601String(),
        },
    };
    await client
        .from('vacantes')
        .update({
          'evaluations': evaluationData,
          'updated_at': evaluatedAt.toIso8601String(),
        })
        .eq('id', vacancy.id);

    return evaluations;
  }

  Future<Map<String, CandidateEvaluation>> fetchEvaluations(
    String vacancyId,
  ) async {
    final row = await client
        .from('vacantes')
        .select('evaluations')
        .eq('id', vacancyId)
        .maybeSingle();
    final rawEvaluations = row?['evaluations'];
    if (rawEvaluations is! Map) return const {};
    return {
      for (final entry in rawEvaluations.entries)
        entry.key.toString(): CandidateEvaluation.fromMap({
          ...Map<String, dynamic>.from(entry.value as Map),
          'candidate_id': entry.key.toString(),
        }),
    };
  }

  Future<bool> usuarioYaSePostulo(String vacanteId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await client
        .from('postulaciones')
        .select('id')
        .eq('vacante_id', vacanteId)
        .eq('usuario_id', userId)
        .maybeSingle();

    return response != null;
  }

  Future<void> cancelarPostulacion(String vacanteId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await client
        .from('postulaciones')
        .delete()
        .eq('vacante_id', vacanteId)
        .eq('usuario_id', userId);
  }

  Future<Map<String, int>> fetchConteoPostulaciones() async {
    try {
      final response = await client.from('postulaciones').select('vacante_id');
      final Map<String, int> conteo = {};
      for (var row in (response as List)) {
        final vacanteId = row['vacante_id'].toString();
        conteo[vacanteId] = (conteo[vacanteId] ?? 0) + 1;
      }
      return conteo;
    } catch (_) {
      return {};
    }
  }
}
