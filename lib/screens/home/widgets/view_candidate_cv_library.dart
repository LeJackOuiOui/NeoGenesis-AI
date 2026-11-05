import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/app_error_handler.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/models/candidate_cv_library_item.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/services/candidate_cv_library_service.dart';
import '../../../main.dart';
import 'app_page_background.dart';

class ViewCandidateCvLibrary extends StatefulWidget {
  const ViewCandidateCvLibrary({super.key});

  @override
  State<ViewCandidateCvLibrary> createState() => _ViewCandidateCvLibraryState();
}

class _ViewCandidateCvLibraryState extends State<ViewCandidateCvLibrary> {
  final _service = CandidateCvLibraryService(supabase);
  final _searchController = TextEditingController();

  List<CandidateCvLibraryItem> _candidates = [];
  String? _selectedSkill;
  String? _selectedPosition;
  bool _isLoading = true;
  String? _error;
  String? _warning;
  String? _downloadingCandidateId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _warning = null;
    });
    try {
      final result = await _service.fetchCandidates();
      if (mounted) {
        setState(() {
          _candidates = result.items;
          _warning = result.warning;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = AppErrorHandler.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _download(CandidateModel candidate) async {
    if (candidate.resumeObjectPath?.isNotEmpty != true) return;
    setState(() => _downloadingCandidateId = candidate.id);
    try {
      final bytes = await _service.downloadOriginal(candidate);
      final filename =
          candidate.resumeOriginalFilename?.trim().isNotEmpty == true
          ? candidate.resumeOriginalFilename!
          : 'cv_${candidate.fullName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
      final extension = filename.contains('.')
          ? filename.split('.').last.toLowerCase()
          : 'pdf';
      await FileSaver.instance.saveFile(
        name: filename.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        bytes: Uint8List.fromList(bytes),
        fileExtension: extension,
        mimeType: extension == 'pdf' ? MimeType.pdf : MimeType.other,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CV de ${candidate.fullName} descargado.')),
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.show(context, error, onRetry: () => _download(candidate));
    } finally {
      if (mounted) setState(() => _downloadingCandidateId = null);
    }
  }

  Future<void> _downloadResumePdf(CandidateCvLibraryItem item) async {
    final candidate = item.candidate;
    setState(() => _downloadingCandidateId = candidate.id);
    try {
      final document = pw.Document();
      final resumeSections = candidate.resumeData.entries
          .map(
            (entry) => (
              label: _formatFieldName(entry.key),
              value: _formatResumeValue(entry.value),
            ),
          )
          .where((section) => section.value.isNotEmpty)
          .toList();

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Text(
              'HOJA DE VIDA',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.green700,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              candidate.fullName.isEmpty ? 'Candidato' : candidate.fullName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            if (candidate.profilePosition?.isNotEmpty == true) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                candidate.profilePosition!,
                style: const pw.TextStyle(
                  fontSize: 13,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Text(
              [
                if (candidate.email.isNotEmpty) candidate.email,
                if (candidate.phone?.isNotEmpty == true) candidate.phone!,
              ].join('  |  '),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.green700),
            if (resumeSections.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Text(
                  item.hasResume
                      ? 'No hay información adicional registrada en el perfil.'
                      : 'Este perfil no tiene una hoja de vida registrada. '
                            'El PDF incluye únicamente los datos de contacto disponibles.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              )
            else
              for (final section in resumeSections)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        section.label,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        section.value,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );

      await FileSaver.instance.saveFile(
        name: 'hoja_de_vida_${_safeFilename(candidate.fullName)}',
        bytes: Uint8List.fromList(await document.save()),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF de ${candidate.fullName} descargado.')),
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.show(
        context,
        error,
        onRetry: () => _downloadResumePdf(item),
      );
    } finally {
      if (mounted) setState(() => _downloadingCandidateId = null);
    }
  }

  String _safeFilename(String value) {
    final filename = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return filename.isEmpty ? 'candidato' : filename;
  }

  List<String> get _availableSkills =>
      _candidates.expand((item) => item.skills).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get _availablePositions =>
      _candidates.expand((item) => item.positions).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<CandidateCvLibraryItem> get _filteredCandidates {
    return CandidateCvLibraryService.filterCandidates(
      items: _candidates,
      query: _searchController.text,
      skill: _selectedSkill,
      position: _selectedPosition,
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedSkill = null;
      _selectedPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _filteredCandidates;
    return AppPageBackground(
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biblioteca de hojas de vida',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Perfiles de candidatos con y sin hoja de vida. Busca por nombre, correo, habilidad o cargo.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar biblioteca',
                        onPressed: _isLoading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Card(
                    color: Colors.white.withValues(alpha: 0.94),
                    elevation: 3,
                    shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText:
                                    'Buscar por nombre, correo, habilidad o cargo',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedSkill,
                              decoration: const InputDecoration(
                                labelText: 'Habilidad',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'Todas las habilidades',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ..._availableSkills.map(
                                  (skill) => DropdownMenuItem<String?>(
                                    value: skill,
                                    child: Text(
                                      skill,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedSkill = value),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedPosition,
                              decoration: const InputDecoration(
                                labelText: 'Cargo',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'Todos los cargos',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ..._availablePositions.map(
                                  (position) => DropdownMenuItem<String?>(
                                    value: position,
                                    child: Text(
                                      position,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedPosition = value),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('Limpiar filtros'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        '${candidates.length} perfil(es) encontrado(s)',
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_warning != null)
                    MaterialBanner(
                      content: Text(_warning!),
                      leading: const Icon(Icons.warning_amber_outlined),
                      actions: [
                        FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  if (_error != null)
                    MaterialBanner(
                      content: Text(
                        'No se pudieron cargar los perfiles: $_error',
                      ),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    )
                  else if (candidates.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 48,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _error == null
                                      ? 'No hay perfiles que coincidan con la búsqueda'
                                      : 'No se pudieron cargar los perfiles',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _candidates.isEmpty
                                      ? 'Aún no hay perfiles de candidatos registrados.'
                                      : 'Prueba con otro nombre, correo, habilidad o cargo, o limpia los filtros.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ...candidates.map(_buildCandidateCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(CandidateCvLibraryItem item) {
    final candidate = item.candidate;
    final isDownloading = _downloadingCandidateId == candidate.id;
    final experienceYears = candidate.resumeData['experience_years'];
    final educationLevel = candidate.resumeData['education_level']?.toString();
    final additionalInfo = candidate.resumeData['additional_info']
        ?.toString()
        .trim();
    return Card(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 3,
      shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.lightGreenBg,
              child: Icon(
                Icons.description_outlined,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.fullName.isEmpty
                        ? 'Candidato sin nombre'
                        : candidate.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    candidate.email.isEmpty ? 'Sin correo' : candidate.email,
                  ),
                  if (candidate.phone?.isNotEmpty == true)
                    Text('Teléfono: ${candidate.phone}'),
                  Text(
                    'Cargo: ${item.positions.isEmpty ? 'No identificado' : item.positions.join(', ')}',
                  ),
                  Text(
                    'Habilidades: ${item.skills.isEmpty ? 'No identificadas' : item.skills.join(', ')}',
                  ),
                  if (experienceYears != null)
                    Text('Experiencia: $experienceYears año(s)'),
                  if (educationLevel?.isNotEmpty == true)
                    Text('Formación: ${_educationLabel(educationLevel!)}'),
                  if (additionalInfo?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Información adicional: $additionalInfo',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      item.hasResume
                          ? 'Hoja de vida registrada'
                          : 'Hoja de vida no registrada',
                      style: TextStyle(
                        color: item.hasResume
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    !item.storageAvailable
                        ? 'Documento original: almacenamiento sin configurar'
                        : item.hasOriginalDocument
                        ? 'Documento original: ${candidate.resumeOriginalFilename ?? 'CV disponible'}'
                        : 'Documento original: no cargado',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (item.hasResume)
                          FilledButton.tonalIcon(
                            onPressed: () => _showResumeDetails(item),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Ver hoja de vida'),
                          ),
                        FilledButton.icon(
                          onPressed: isDownloading
                              ? null
                              : () => _downloadResumePdf(item),
                          icon: isDownloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Descargar PDF'),
                        ),
                        if (item.hasOriginalDocument && item.storageAvailable)
                          OutlinedButton.icon(
                            onPressed: isDownloading
                                ? null
                                : () => _download(candidate),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Descargar original'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResumeDetails(CandidateCvLibraryItem item) {
    final resume = item.candidate.resumeData;
    final standardFields = {
      'summary',
      'profile',
      'objective',
      'experience_years',
      'education_level',
      'skills',
      'additional_info',
      'experience',
      'education',
    };
    final additionalFields = resume.entries
        .where((entry) => !standardFields.contains(entry.key))
        .toList();

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hoja de vida de ${item.candidate.fullName}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _resumeDetail(
                  'Perfil',
                  resume['summary'] ?? resume['profile'] ?? resume['objective'],
                ),
                _resumeDetail(
                  'Experiencia',
                  resume['experience_years'] == null
                      ? resume['experience']
                      : '${resume['experience_years']} año(s)',
                ),
                _resumeDetail(
                  'Formación',
                  resume['education_level'] == null
                      ? resume['education']
                      : _educationLabel(resume['education_level'].toString()),
                ),
                _resumeDetail('Habilidades', resume['skills']),
                _resumeDetail(
                  'Información adicional',
                  resume['additional_info'],
                ),
                for (final entry in additionalFields)
                  _resumeDetail(_formatFieldName(entry.key), entry.value),
                if (item.hasOriginalDocument) ...[
                  const Divider(height: 28),
                  Text(
                    'Documento original: '
                    '${item.candidate.resumeOriginalFilename ?? 'CV disponible'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa el botón de descarga del perfil para guardar el archivo original.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _resumeDetail(String label, dynamic value) {
    final displayValue = _formatResumeValue(value);
    if (displayValue.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          SelectableText(displayValue),
        ],
      ),
    );
  }

  String _formatResumeValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      return value
          .map(_formatResumeValue)
          .where((entry) => entry.isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      return value.entries
          .map(
            (entry) =>
                '${_formatFieldName(entry.key.toString())}: '
                '${_formatResumeValue(entry.value)}',
          )
          .where((entry) => !entry.endsWith(': '))
          .join('\n');
    }
    return value.toString();
  }

  String _formatFieldName(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) =>
            '${word[0].toUpperCase()}${word.length > 1 ? word.substring(1) : ''}',
      )
      .join(' ');

  String _educationLabel(String value) => switch (value) {
    'none' => 'Sin mínimo',
    'secondary' => 'Secundaria',
    'technical' => 'Técnica / tecnológica',
    'bachelor' => 'Universitaria',
    'postgraduate' => 'Posgrado',
    'doctorate' => 'Doctorado',
    _ => value,
  };
}
