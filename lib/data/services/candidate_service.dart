import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/candidate_model.dart';

class CandidateService {
  static const resumeBucket = 'candidatos-cv';
  static const maxResumeBytes = 15 * 1024 * 1024;

  final SupabaseClient client;

  const CandidateService(this.client);

  Future<List<CandidateModel>> fetchCandidates() async {
    final rows = await client
        .from('candidatos')
        .select(
          'id, full_name, email, phone, resume_data, created_at, resume_status, resume_original_filename, resume_error_message, resume_bucket_id, resume_object_path, resume_uploaded_at',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) =>
              CandidateModel.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<CandidateModel> createCandidate({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final row = await client
        .from('candidatos')
        .insert({
          'full_name': fullName.trim(),
          'email': email.trim().isEmpty ? null : email.trim(),
          'phone': phone.trim().isEmpty ? null : phone.trim(),
        })
        .select('id, full_name, email, phone, resume_data')
        .single();
    return CandidateModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<CandidateModel> uploadAndExtractResume({
    required CandidateModel candidate,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (!filename.toLowerCase().endsWith('.pdf')) {
      throw Exception('Selecciona un archivo PDF.');
    }
    if (bytes.lengthInBytes > maxResumeBytes) {
      throw Exception('El PDF supera el límite de 15 MB.');
    }
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw Exception('El archivo seleccionado no es un PDF válido.');
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Inicia sesión para cargar un CV.');
    final safeFilename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final objectPath =
        '${candidate.id}/${DateTime.now().microsecondsSinceEpoch}_$safeFilename';
    var uploaded = false;
    var candidateUpdated = false;
    try {
      await client.storage
          .from(resumeBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );
      uploaded = true;
      final savedCandidate = await client
          .from('candidatos')
          .update({
            'resume_bucket_id': resumeBucket,
            'resume_object_path': objectPath,
            'resume_original_filename': filename,
            'resume_content_type': 'application/pdf',
            'resume_file_size_bytes': bytes.lengthInBytes,
            'resume_status': 'queued',
            'resume_error_message': null,
            'resume_uploaded_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', candidate.id)
          .select('id')
          .maybeSingle();
      if (savedCandidate == null) {
        throw Exception(
          'El PDF se subió, pero no se guardaron sus datos en candidatos. Verifica los permisos RLS de la tabla.',
        );
      }
      candidateUpdated = true;

      final response = await client.functions.invoke(
        'extract-cv',
        body: {'candidate_id': candidate.id},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return CandidateModel.fromMap({
          'id': candidate.id,
          'full_name': candidate.fullName,
          'email': candidate.email,
          'phone': candidate.phone,
          'resume_data': data['data'],
        });
      }
      throw Exception('El análisis del CV no devolvió los datos esperados.');
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : details?.toString().trim().isNotEmpty == true
          ? details.toString()
          : 'No se pudo procesar el CV (HTTP ${error.status}). Verifica la función extract-cv y sus secretos de Supabase/OpenAI.';
      throw Exception(message);
    } on StorageException catch (error) {
      throw Exception('Supabase Storage: ${error.message}');
    } on PostgrestException catch (error) {
      throw Exception('Supabase (candidatos): ${error.message}');
    } catch (_) {
      rethrow;
    } finally {
      // Retain a PDF only after its path has been saved on the candidate row.
      if (uploaded && !candidateUpdated) {
        try {
          await client.storage.from(resumeBucket).remove([objectPath]);
        } catch (_) {
          // The original upload error is more useful than a cleanup error.
        }
      }
    }
  }

  Future<void> saveManualResumeData({
    required String candidateId,
    required Map<String, dynamic> resumeData,
  }) async {
    await client
        .from('candidatos')
        .update({
          'resume_data': resumeData,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', candidateId);
  }
}
