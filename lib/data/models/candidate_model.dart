import 'dart:convert';

class CandidateModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePosition;
  final Map<String, dynamic> resumeData;
  final Map<String, dynamic>? latestResume;
  final String? resumeBucketId;
  final String? resumeObjectPath;
  final String? resumeOriginalFilename;
  final String? resumeContentType;
  final DateTime? createdAt;

  const CandidateModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.resumeData,
    this.latestResume,
    this.profilePosition,
    this.resumeBucketId,
    this.resumeObjectPath,
    this.resumeOriginalFilename,
    this.resumeContentType,
    this.createdAt,
  });

  factory CandidateModel.fromMap(Map<String, dynamic> map) {
    dynamic rawResume = map['resume_data'];
    Map<String, dynamic> parsedResume = {};

    if (rawResume is Map) {
      parsedResume = Map<String, dynamic>.from(rawResume);
    } else if (rawResume is String && rawResume.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawResume);
        if (decoded is Map) {
          parsedResume = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return CandidateModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      profilePosition: (map['cargo'] ?? map['position'])?.toString(),
      resumeData: parsedResume,
      resumeBucketId: map['resume_bucket_id']?.toString(),
      resumeObjectPath: map['resume_object_path']?.toString(),
      resumeOriginalFilename: map['resume_original_filename']?.toString(),
      resumeContentType: map['resume_content_type']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}
