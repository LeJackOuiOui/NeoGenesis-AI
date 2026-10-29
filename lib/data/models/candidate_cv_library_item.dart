import 'candidate_model.dart';

class CandidateCvLibraryItem {
  final CandidateModel candidate;
  final List<String> positions;
  final List<String> skills;
  final bool storageAvailable;

  bool get hasOriginalDocument =>
      candidate.resumeObjectPath?.isNotEmpty == true;

  bool get hasResume =>
      hasOriginalDocument || hasResumeData(candidate.resumeData);

  const CandidateCvLibraryItem({
    required this.candidate,
    required this.positions,
    required this.skills,
    this.storageAvailable = true,
  });

  static bool hasResumeData(Map<String, dynamic> resume) {
    for (final key in const [
      'summary',
      'profile',
      'objective',
      'skills',
      'experience',
      'education',
      'education_level',
      'experience_years',
      'certifications',
      'additional_info',
      'position',
      'job_title',
      'cargo',
    ]) {
      final value = resume[key];
      if (value is String && value.trim().isNotEmpty) return true;
      if (value is List && value.isNotEmpty) return true;
      if (value is Map && value.isNotEmpty) return true;
      if (value is num && value > 0) return true;
    }
    return false;
  }
}
