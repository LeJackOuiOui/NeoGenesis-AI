import 'candidate.dart';

class CandidateMatch {
  final Candidate candidate;
  final double semanticScore;
  final double manualScore;
  final double finalScore;

  CandidateMatch({
    required this.candidate,
    required this.semanticScore,
    required this.manualScore,
    required this.finalScore,
  });
}
