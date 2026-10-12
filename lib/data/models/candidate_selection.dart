import 'candidate.dart';

class CandidateSelection {
  final Candidate candidate;
  bool selected;
  bool interviewEligible;

  CandidateSelection({
    required this.candidate,
    this.selected = false,
    this.interviewEligible = false,
  });
}
