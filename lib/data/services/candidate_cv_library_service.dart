import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/candidate_cv_library_item.dart';
import '../models/candidate_model.dart';
import 'candidate_service.dart';

class CandidateCvLibraryResult {
  final List<CandidateCvLibraryItem> items;
  final String? warning;

  const CandidateCvLibraryResult({required this.items, this.warning});
}

class CandidateCvLibraryService {
  final SupabaseClient client;

  const CandidateCvLibraryService(this.client);

  Future<CandidateCvLibraryResult> fetchCandidates() async {
    final profiles = await client
        .from('profiles')
        .select('id, nombre, email, telefono, role, created_at');
    final profilesByUser = <String, Map<String, dynamic>>{};
    final candidatesByUser = <String, CandidateModel>{};
    for (final row in profiles as List) {
      final profile = Map<String, dynamic>.from(row as Map);
      final id = profile['id']?.toString();
      if (id == null ||
          id.isEmpty ||
          !_isCandidateProfile(profile['role']?.toString())) {
        continue;
      }
      profilesByUser[id] = profile;
      candidatesByUser[id] = CandidateModel.fromMap({
        'id': id,
        'full_name': profile['nombre'],
        'email': profile['email'],
        'phone': profile['telefono'],
        'resume_data': const <String, dynamic>{},
        'created_at': profile['created_at'],
      });
    }

    if (profilesByUser.isEmpty) {
      return const CandidateCvLibraryResult(items: []);
    }

    var storageAvailable = true;
    String? warning;
    List<dynamic> candidateRows;
    try {
      candidateRows = await _fetchCandidateRows(includeStorage: true);
    } on PostgrestException catch (error) {
      if (_isMissingStorageColumns(error)) {
        storageAvailable = false;
        warning =
            'Los perfiles están disponibles, pero falta preparar el almacenamiento '
            'de archivos originales. Ejecuta en Supabase la migración '
            '202610290002_restore_candidate_resume_columns.sql.';
        try {
          candidateRows = await _fetchCandidateRows(includeStorage: false);
        } on PostgrestException catch (fallbackError) {
          warning =
              'Los perfiles están disponibles, pero no se pudieron consultar '
              'los CV: ${fallbackError.message}';
          candidateRows = const [];
        }
      } else {
        warning =
            'No se pudieron consultar los datos de las hojas de vida: '
            '${error.message}';
        candidateRows = const [];
      }
    } on Exception catch (error) {
      warning =
          'No se pudieron consultar los datos de las hojas de vida: $error';
      candidateRows = const [];
    }

    for (final row in candidateRows) {
      final data = Map<String, dynamic>.from(row as Map);
      final userId = userIdForCandidate(data, profilesByUser);
      if (userId == null || userId.isEmpty) continue;

      final resume = CandidateModel.fromMap(data);
      final profile = profilesByUser[userId];
      final existing = candidatesByUser[userId];
      final selectedResume = _shouldPreferResume(existing, resume)
          ? existing!
          : resume;
      candidatesByUser[userId] = CandidateModel(
        id: selectedResume.id,
        fullName: _firstNonEmpty(
          profile?['nombre']?.toString(),
          existing?.fullName,
          selectedResume.fullName,
        ),
        email: _firstNonEmpty(
          profile?['email']?.toString(),
          existing?.email,
          selectedResume.email,
        ),
        phone: _firstNonEmpty(
          profile?['telefono']?.toString(),
          existing?.phone,
          selectedResume.phone,
        ),
        resumeData: selectedResume.resumeData,
        profilePosition:
            existing?.profilePosition ?? selectedResume.profilePosition,
        resumeBucketId: selectedResume.resumeBucketId,
        resumeObjectPath: selectedResume.resumeObjectPath,
        resumeOriginalFilename: selectedResume.resumeOriginalFilename,
        resumeContentType: selectedResume.resumeContentType,
        createdAt: DateTime.tryParse(
          profile?['created_at']?.toString() ??
              data['created_at']?.toString() ??
              '',
        ),
      );
    }

    final items =
        candidatesByUser.values.map((candidate) {
          return CandidateCvLibraryItem(
            candidate: candidate,
            positions: positionsFor(candidate),
            skills: skillsFor(candidate),
            storageAvailable: storageAvailable,
          );
        }).toList()..sort(
          (a, b) => a.candidate.fullName.toLowerCase().compareTo(
            b.candidate.fullName.toLowerCase(),
          ),
        );
    return CandidateCvLibraryResult(items: items, warning: warning);
  }

  static String? userIdForCandidate(
    Map<String, dynamic> candidate,
    Map<String, Map<String, dynamic>> profilesByUser,
  ) {
    final userIds = profilesByUser.keys.toSet();
    final ownerId = candidate['created_by']?.toString();
    if (userIds.contains(ownerId)) return ownerId;

    final candidateId = candidate['id']?.toString();
    if (userIds.contains(candidateId)) return candidateId;

    final candidateEmail = _normalizeSearchText(
      candidate['email']?.toString() ?? '',
    );
    if (candidateEmail.isNotEmpty) {
      for (final entry in profilesByUser.entries) {
        if (_normalizeSearchText(
              entry.value['email']?.toString() ?? '',
            ) ==
            candidateEmail) {
          return entry.key;
        }
      }
    }

    final candidateName = _normalizeSearchText(
      candidate['full_name']?.toString() ?? '',
    );
    if (candidateName.isEmpty) return null;
    final matchingProfiles = profilesByUser.entries
        .where(
          (entry) =>
              _normalizeSearchText(entry.value['nombre']?.toString() ?? '') ==
              candidateName,
        )
        .toList();
    return matchingProfiles.length == 1 ? matchingProfiles.single.key : null;
  }

  Future<List<dynamic>> _fetchCandidateRows({
    required bool includeStorage,
  }) async {
    final columns = includeStorage
        ? 'id, full_name, email, phone, resume_data, created_by, '
              'resume_bucket_id, resume_object_path, resume_original_filename, '
              'resume_content_type, created_at'
        : 'id, full_name, email, phone, resume_data, created_by, created_at';
    return await client
        .from('candidatos')
        .select(columns)
        .order('created_at', ascending: false);
  }

  static bool _shouldPreferResume(
    CandidateModel? current,
    CandidateModel incoming,
  ) {
    if (current == null) return false;
    final currentHasOriginal = current.resumeObjectPath?.isNotEmpty == true;
    final incomingHasOriginal = incoming.resumeObjectPath?.isNotEmpty == true;
    if (currentHasOriginal != incomingHasOriginal) return currentHasOriginal;

    final currentHasData = CandidateCvLibraryItem.hasResumeData(
      current.resumeData,
    );
    final incomingHasData = CandidateCvLibraryItem.hasResumeData(
      incoming.resumeData,
    );
    return currentHasData && !incomingHasData;
  }

  static bool _isCandidateProfile(String? role) {
    final normalizedRole = role?.trim().toLowerCase();
    return normalizedRole == null ||
        normalizedRole.isEmpty ||
        const {'empleado', 'candidato', 'candidate'}.contains(normalizedRole);
  }

  static bool _isMissingStorageColumns(PostgrestException error) =>
      error.code == '42703' &&
      (error.message.contains('resume_bucket_id') ||
          error.message.contains('resume_object_path') ||
          error.message.contains('resume_original_filename') ||
          error.message.contains('resume_content_type'));

  static List<CandidateCvLibraryItem> filterCandidates({
    required List<CandidateCvLibraryItem> items,
    String query = '',
    String? skill,
    String? position,
  }) {
    final normalizedQuery = _normalizeSearchText(query);
    return items.where((item) {
      if (skill != null &&
          !item.skills.any(
            (value) => value.toLowerCase() == skill.toLowerCase(),
          )) {
        return false;
      }
      if (position != null &&
          !item.positions.any(
            (value) => value.toLowerCase() == position.toLowerCase(),
          )) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      final candidate = item.candidate;
      return _normalizeSearchText(
            candidate.fullName,
          ).contains(normalizedQuery) ||
          _normalizeSearchText(candidate.email).contains(normalizedQuery) ||
          item.skills.any(
            (value) => _normalizeSearchText(value).contains(normalizedQuery),
          ) ||
          item.positions.any(
            (value) => _normalizeSearchText(value).contains(normalizedQuery),
          );
    }).toList();
  }

  static String _normalizeSearchText(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n');

  Future<Uint8List> downloadOriginal(CandidateModel candidate) async {
    final objectPath = candidate.resumeObjectPath;
    if (objectPath == null || objectPath.isEmpty) {
      throw Exception('El candidato no tiene un CV original almacenado.');
    }
    final bucket = candidate.resumeBucketId?.isNotEmpty == true
        ? candidate.resumeBucketId!
        : CandidateService.resumeBucket;
    try {
      return await client.storage.from(bucket).download(objectPath);
    } on StorageException catch (error) {
      throw Exception('No se pudo descargar el CV original: ${error.message}');
    }
  }

  static List<String> skillsFor(CandidateModel candidate) {
    final rawSkills = candidate.resumeData['skills'];
    if (rawSkills is List) {
      return rawSkills
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
    }
    if (rawSkills is String) {
      return rawSkills
          .split(RegExp(r'[,;\n]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
    }
    return const [];
  }

  static List<String> positionsFor(CandidateModel candidate) {
    final positions = <String>{};
    final explicitPosition = candidate.profilePosition?.trim();
    if (explicitPosition != null && explicitPosition.isNotEmpty) {
      positions.add(explicitPosition);
    }

    final experience = candidate.resumeData['experience'];
    if (experience is List) {
      for (final entry in experience.whereType<Map>()) {
        for (final key in const [
          'position',
          'job_title',
          'title',
          'role',
          'cargo',
        ]) {
          final value = entry[key]?.toString().trim();
          if (value != null && value.isNotEmpty) positions.add(value);
        }
      }
    }
    for (final key in const ['position', 'job_title', 'cargo']) {
      final value = candidate.resumeData[key]?.toString().trim();
      if (value != null && value.isNotEmpty) positions.add(value);
    }
    return positions.toList()..sort();
  }

  static String _firstNonEmpty(String? first, String? second, String? third) {
    for (final value in [first, second, third]) {
      if (value?.trim().isNotEmpty == true) return value!.trim();
    }
    return '';
  }
}
