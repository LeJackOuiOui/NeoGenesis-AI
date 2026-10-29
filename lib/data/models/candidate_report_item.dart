import 'candidate_model.dart';

class CandidateReportItem {
  final String vacancyId;
  final String vacancyTitle;
  final CandidateModel? candidate;
  final String status;
  final DateTime? candidateRegisteredAt;
  final double? score;

  const CandidateReportItem({
    required this.vacancyId,
    required this.vacancyTitle,
    required this.candidate,
    required this.status,
    required this.candidateRegisteredAt,
    required this.score,
  });
}
