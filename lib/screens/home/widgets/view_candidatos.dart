import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/services/candidate_service.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';

class ViewCandidatos extends StatefulWidget {
  const ViewCandidatos({super.key});

  @override
  State<ViewCandidatos> createState() => _ViewCandidatosState();
}

class _ViewCandidatosState extends State<ViewCandidatos> {
  final CandidateService _candidateService = CandidateService(supabase);
  final List<CandidateModel> _candidates = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _busyCandidateId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final candidates = await _candidateService.fetchCandidates();
      if (!mounted) return;
      setState(() {
        _candidates
          ..clear()
          ..addAll(candidates);
      });
      await _reevaluateVacancies(candidates);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reevaluateVacancies(List<CandidateModel> candidates) async {
    final vacancyService = VacancyService(supabase);
    final vacancies = await vacancyService.fetchVacancies();
    for (final vacancy in vacancies) {
      await vacancyService.evaluateCandidates(
        vacancy: vacancy,
        candidates: candidates,
      );
    }
  }

  List<CandidateModel> get _filteredCandidates {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _candidates;
    return _candidates.where((candidate) {
      return '${candidate.fullName} ${candidate.email} ${candidate.phone}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _showCreateCandidateDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    CandidateModel? createdCandidate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar candidato'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  inputFormatters: [FormValidators.nameInputFormatter],
                  maxLength: 100,
                  buildCounter: _hideCounter,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                  ),
                  validator: FormValidators.personName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [FormValidators.emailInputFormatter],
                  maxLength: 254,
                  buildCounter: _hideCounter,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (value) =>
                      FormValidators.email(value, required: false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FormValidators.phoneInputFormatter],
                  maxLength: 20,
                  buildCounter: _hideCounter,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: (value) =>
                      FormValidators.phone(value, required: false),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                createdCandidate = await _candidateService.createCandidate(
                  fullName: nameController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              } catch (error) {
                if (!mounted) return;
                _showMessage(
                  'No se pudo crear el candidato: $error',
                  isError: true,
                );
              }
            },
            child: const Text('Crear candidato'),
          ),
        ],
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    if (createdCandidate != null && mounted) {
      await _loadCandidates();
      await _chooseAndUploadCv(createdCandidate!);
    }
  }

  Future<void> _chooseAndUploadCv(CandidateModel candidate) async {
    late final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo abrir el selector de archivos: $error',
          isError: true,
        );
      }
      return;
    }
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    late final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      _showMessage('No se pudo leer el archivo seleccionado.', isError: true);
      return;
    }
    if (bytes.isEmpty) {
      _showMessage('No se pudo leer el archivo seleccionado.', isError: true);
      return;
    }

    setState(() => _busyCandidateId = candidate.id);
    final stopwatch = Stopwatch()..start();
    try {
      await _candidateService.uploadAndExtractResume(
        candidate: candidate,
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      await _loadCandidates();
      _showMessage(
        'CV analizado y perfil actualizado en ${stopwatch.elapsed.inSeconds}s.',
      );
    } catch (error) {
      if (!mounted) return;
      await _loadCandidates();
      _showMessage(
        '${error.toString().replaceFirst('Exception: ', '')} Puedes completar el perfil manualmente.',
        isError: true,
      );
      final refreshed = _candidates.where((item) => item.id == candidate.id);
      if (refreshed.isNotEmpty) _showCandidateProfile(refreshed.first);
    } finally {
      if (mounted) setState(() => _busyCandidateId = null);
    }
  }

  Future<void> _showCandidateProfile(CandidateModel candidate) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final resume = candidate.resumeData;
          final latestResume = candidate.latestResume;
          final status = latestResume?['status']?.toString() ?? 'Sin CV';
          final skills = _stringList(resume['skills']);
          final experience = _mapList(resume['experience']);
          final education = _mapList(resume['education']);

          return AlertDialog(
            title: Text(candidate.fullName),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      [
                        candidate.email,
                        candidate.phone,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Estado del CV'),
                    Row(
                      children: [
                        _statusBadge(status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            latestResume?['original_filename']?.toString() ??
                                'Aún no se ha cargado un CV.',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (status == 'failed' &&
                        (latestResume?['error_message']
                                ?.toString()
                                .isNotEmpty ??
                            false)) ...[
                      const SizedBox(height: 8),
                      Text(
                        latestResume!['error_message'].toString(),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('Resumen'),
                    Text(
                      (resume['summary'] ?? '').toString().trim().isEmpty
                          ? 'Sin resumen registrado.'
                          : resume['summary'].toString(),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Habilidades'),
                    if (skills.isEmpty)
                      const Text('Sin habilidades registradas.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills
                            .map((skill) => Chip(label: Text(skill)))
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    _sectionTitle('Experiencia'),
                    if (experience.isEmpty)
                      const Text('Sin experiencia registrada.')
                    else
                      ...experience.map(_buildExperienceTile),
                    const SizedBox(height: 12),
                    _sectionTitle('Formación'),
                    if (education.isEmpty)
                      const Text('Sin formación registrada.')
                    else
                      ...education.map(_buildEducationTile),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _chooseAndUploadCv(candidate);
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Cargar/reemplazar CV'),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _showManualEntryDialog(candidate);
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Completar manualmente'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showManualEntryDialog(CandidateModel candidate) async {
    final current = candidate.resumeData;
    final summaryController = TextEditingController(
      text: current['summary']?.toString() ?? '',
    );
    final skillsController = TextEditingController(
      text: _stringList(current['skills']).join(', '),
    );
    final experienceController = TextEditingController(
      text: _mapList(
        current['experience'],
      ).map((item) => item['description'] ?? item['role'] ?? '').join('\n'),
    );
    final educationController = TextEditingController(
      text: _mapList(
        current['education'],
      ).map((item) => item['degree'] ?? item['field'] ?? '').join('\n'),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Completar perfil manualmente'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: summaryController,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Resumen profesional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: skillsController,
                    maxLines: 2,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Habilidades',
                      helperText: 'Separadas por comas.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: experienceController,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Experiencia',
                      helperText: 'Una experiencia por línea.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: educationController,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Formación',
                      helperText: 'Una formación por línea.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final experience = _lines(experienceController.text)
                  .map(
                    (line) => {
                      'company': '',
                      'role': line,
                      'start_date': '',
                      'end_date': '',
                      'description': line,
                    },
                  )
                  .toList();
              final education = _lines(educationController.text)
                  .map(
                    (line) => {
                      'institution': '',
                      'degree': line,
                      'field': line,
                      'start_date': '',
                      'end_date': '',
                    },
                  )
                  .toList();
              final data = <String, dynamic>{
                'summary': summaryController.text.trim(),
                'skills': _lines(skillsController.text.replaceAll(',', '\n')),
                'experience': experience,
                'education': education,
              };
              try {
                await _candidateService.saveManualResumeData(
                  candidateId: candidate.id,
                  resumeData: data,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await _loadCandidates();
                _showMessage('Perfil guardado correctamente.');
              } catch (error) {
                if (mounted)
                  _showMessage('No se pudo guardar: $error', isError: true);
              }
            },
            child: const Text('Guardar perfil'),
          ),
        ],
      ),
    );
    summaryController.dispose();
    skillsController.dispose();
    experienceController.dispose();
    educationController.dispose();
  }

  Widget _buildExperienceTile(Map<String, dynamic> item) {
    final title = item['role']?.toString().trim() ?? '';
    final company = item['company']?.toString().trim() ?? '';
    final dates = [item['start_date'], item['end_date']]
        .map((value) => value?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' – ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.work_outline, color: AppTheme.primaryGreen),
      title: Text(title.isEmpty ? 'Experiencia' : title),
      subtitle: Text(
        [
          company,
          dates,
          item['description']?.toString() ?? '',
        ].where((value) => value.trim().isNotEmpty).join('\n'),
      ),
    );
  }

  Widget _buildEducationTile(Map<String, dynamic> item) {
    final title = item['degree']?.toString().trim() ?? '';
    final institution = item['institution']?.toString().trim() ?? '';
    final field = item['field']?.toString().trim() ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.school_outlined, color: AppTheme.primaryGreen),
      title: Text(title.isEmpty ? 'Formación' : title),
      subtitle: Text(
        [
          institution,
          field,
        ].where((value) => value.trim().isNotEmpty).join(' · '),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    ),
  );

  Widget _statusBadge(String status) {
    final failed = status == 'failed';
    final completed = status == 'completed';
    final color = failed
        ? Colors.red
        : completed
        ? AppTheme.primaryGreen
        : Colors.orange;
    final label = switch (status) {
      'completed' => 'Procesado',
      'processing' => 'Procesando',
      'queued' => 'En cola',
      'failed' => 'Requiere revisión',
      _ => 'Sin CV',
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }

  List<String> _stringList(dynamic value) => value is List
      ? value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];

  List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  List<String> _lines(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget? _hideCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 16,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Candidatos',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Carga CV en PDF y extrae experiencia, habilidades y formación.',
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateCandidateDialog,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Nuevo candidato'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, correo o teléfono...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.primaryGreen,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const LinearProgressIndicator(color: AppTheme.primaryGreen),
                if (_loadError != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(
                    'No se pudo cargar la lista. Aplica la migración SQL y verifica los permisos de reclutador. $_loadError',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _loadCandidates,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
                if (!_isLoading &&
                    _loadError == null &&
                    _filteredCandidates.isEmpty)
                  _emptyState(),
                ..._filteredCandidates.map(_buildCandidateCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(CandidateModel candidate) {
    final resumeStatus =
        candidate.latestResume?['status']?.toString() ?? 'Sin CV';
    final isBusy = _busyCandidateId == candidate.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.lightGreenBg,
            foregroundColor: AppTheme.primaryGreen,
            child: Text(
              candidate.fullName.isEmpty
                  ? '?'
                  : candidate.fullName[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    candidate.email,
                    candidate.phone,
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                const SizedBox(height: 8),
                _statusBadge(resumeStatus),
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              tooltip: 'Cargar CV PDF',
              onPressed: () => _chooseAndUploadCv(candidate),
              icon: const Icon(Icons.upload_file, color: AppTheme.primaryGreen),
            ),
            IconButton(
              tooltip: 'Completar perfil manualmente',
              onPressed: () => _showManualEntryDialog(candidate),
              icon: const Icon(Icons.edit_note, color: AppTheme.primaryGreen),
            ),
            IconButton(
              tooltip: 'Ver perfil',
              onPressed: () => _showCandidateProfile(candidate),
              icon: const Icon(
                Icons.visibility_outlined,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message, style: TextStyle(color: Colors.red.shade800)),
  );

  Widget _emptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(
          Icons.person_search_outlined,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        const Text(
          'Todavía no hay candidatos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Agrega un candidato para subir su CV o completar el perfil manualmente.',
          style: TextStyle(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
