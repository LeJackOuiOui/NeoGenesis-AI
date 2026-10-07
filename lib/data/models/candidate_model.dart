class CandidateModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic>? latestResume;

  const CandidateModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.resumeData,
    this.latestResume,
  });

  factory CandidateModel.fromMap(Map<String, dynamic> map) {
    final rawResumeData = map['resume_data'];
    final rawLatestResume = map['latest_resume'];
    final latestResume = rawLatestResume is Map
        ? Map<String, dynamic>.from(rawLatestResume)
        : map['resume_status'] == null
        ? null
        : <String, dynamic>{
            'status': map['resume_status'],
            'original_filename': map['resume_original_filename'],
            'error_message': map['resume_error_message'],
            'bucket_id': map['resume_bucket_id'],
            'object_path': map['resume_object_path'],
            'created_at': map['resume_uploaded_at'],
          };
    return CandidateModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      resumeData: rawResumeData is Map
          ? Map<String, dynamic>.from(rawResumeData)
          : const <String, dynamic>{},
      latestResume: latestResume,
    );
  }
}
