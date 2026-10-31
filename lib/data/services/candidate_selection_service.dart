import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/candidate.dart';
import '../models/candidate_selection.dart';

class CandidateSelectionService {
  static List<CandidateSelection> createSelection(List<Candidate> candidates) {
    return candidates
        .map((candidate) => CandidateSelection(candidate: candidate))
        .toList();
  }

  static void selectCandidate(CandidateSelection selection) {
    selection.selected = true;
    selection.interviewEligible = false;
  }

  static void removeCandidate(CandidateSelection selection) {
    selection.selected = false;
    selection.interviewEligible = false;
  }

  static void confirmSelection(List<CandidateSelection> selections) {
    for (final selection in selections) {
      selection.interviewEligible = selection.selected;
    }
  }

  static List<CandidateSelection> getSelectedCandidates(
    List<CandidateSelection> selections,
  ) {
    return selections.where((selection) => selection.selected).toList();
  }

  static List<CandidateSelection> getInterviewEligibleCandidates(
    List<CandidateSelection> selections,
  ) {
    return selections
        .where((selection) => selection.interviewEligible)
        .toList();
  }

  static Future<void> saveConfirmedSelection({
    required SupabaseClient client,
    required String vacancyId,
    required List<CandidateSelection> selections,
  }) async {
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      throw Exception('Debes iniciar sesión para confirmar la selección.');
    }

    final selectedCandidates = getSelectedCandidates(selections);

    final existingRows = await client
        .from('candidate_selections')
        .select('candidate_id')
        .eq('vacancy_id', vacancyId);

    final existingIds = existingRows
        .map((row) => row['candidate_id'] as String)
        .toList();

    final selectedIds = selectedCandidates
        .map((selection) => selection.candidate.id)
        .toSet();

    for (final selection in selectedCandidates) {
      await client.from('candidate_selections').upsert({
        'vacancy_id': vacancyId,
        'candidate_id': selection.candidate.id,
        'selected_by': currentUser.id,
        'is_confirmed': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'vacancy_id,candidate_id');
    }

    for (final candidateId in existingIds) {
      if (!selectedIds.contains(candidateId)) {
        await client
            .from('candidate_selections')
            .delete()
            .eq('vacancy_id', vacancyId)
            .eq('candidate_id', candidateId);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getConfirmedCandidates({
    required SupabaseClient client,
    required String vacancyId,
  }) async {
    final rows = await client
        .from('candidate_selections')
        .select('''
          candidate_id,
          candidatos (
            id,
            full_name,
            email,
            phone,
            resume_data
          )
        ''')
        .eq('vacancy_id', vacancyId)
        .eq('is_confirmed', true);

    return rows
        .map((row) => Map<String, dynamic>.from(row['candidatos']))
        .toList();
  }
}
