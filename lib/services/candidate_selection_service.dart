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
}
