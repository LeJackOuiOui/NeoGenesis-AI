import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/candidate.dart';
import '../../lib/models/candidate_selection.dart';
import '../../lib/services/candidate_selection_service.dart';

void main() {
  final candidate1 = Candidate(
    id: '1',
    name: 'Juan Pérez',
    cvText: 'Desarrollador Flutter',
    skills: ['Flutter', 'Dart'],
    experienceYears: 3,
  );

  final candidate2 = Candidate(
    id: '2',
    name: 'María López',
    cvText: 'Desarrolladora de software',
    skills: ['Flutter'],
    experienceYears: 2,
  );

  group('CandidateSelectionService', () {
    test('crea una selección por cada candidato', () {
      final selections = CandidateSelectionService.createSelection([
        candidate1,
        candidate2,
      ]);

      expect(selections.length, 2);
      expect(selections[0].candidate, candidate1);
      expect(selections[1].candidate, candidate2);
      expect(selections[0].selected, false);
      expect(selections[0].interviewEligible, false);
    });

    test('selecciona un candidato correctamente', () {
      final selection = CandidateSelection(candidate: candidate1);

      CandidateSelectionService.selectCandidate(selection);

      expect(selection.selected, true);
      expect(selection.interviewEligible, false);
    });

    test('quita un candidato correctamente', () {
      final selection = CandidateSelection(
        candidate: candidate1,
        selected: true,
      );

      CandidateSelectionService.removeCandidate(selection);

      expect(selection.selected, false);
      expect(selection.interviewEligible, false);
    });

    test('confirma únicamente los candidatos seleccionados', () {
      final selections = [
        CandidateSelection(candidate: candidate1, selected: true),
        CandidateSelection(candidate: candidate2, selected: false),
      ];

      CandidateSelectionService.confirmSelection(selections);

      expect(selections[0].interviewEligible, true);
      expect(selections[1].interviewEligible, false);
    });

    test('obtiene los candidatos seleccionados', () {
      final selections = [
        CandidateSelection(candidate: candidate1, selected: true),
        CandidateSelection(candidate: candidate2, selected: false),
      ];

      final selected = CandidateSelectionService.getSelectedCandidates(
        selections,
      );

      expect(selected.length, 1);
      expect(selected.first.candidate, candidate1);
    });

    test('obtiene los candidatos aptos para entrevista', () {
      final selections = [
        CandidateSelection(
          candidate: candidate1,
          selected: true,
          interviewEligible: true,
        ),
        CandidateSelection(
          candidate: candidate2,
          selected: true,
          interviewEligible: false,
        ),
      ];

      final eligible = CandidateSelectionService.getInterviewEligibleCandidates(
        selections,
      );

      expect(eligible.length, 1);
      expect(eligible.first.candidate, candidate1);
    });
  });
}
