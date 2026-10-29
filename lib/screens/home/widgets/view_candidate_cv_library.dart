import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/models/candidate_cv_library_item.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/services/candidate_cv_library_service.dart';
import '../../../main.dart';

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
      if (mounted) setState(() => _error = error.toString());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar el CV: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingCandidateId = null);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de hojas de vida'),
        actions: [
          IconButton(
            tooltip: 'Actualizar biblioteca',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perfiles de candidatos con y sin hoja de vida. Busca por nombre, correo, habilidad o cargo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
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
                      labelText: 'Buscar por nombre, correo, habilidad o cargo',
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
                          child: Text(skill, overflow: TextOverflow.ellipsis),
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
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${candidates.length} perfil(es) encontrado(s)'),
            const SizedBox(height: 8),
            if (_warning != null)
              MaterialBanner(
                content: Text(_warning!),
                leading: const Icon(Icons.warning_amber_outlined),
                actions: [
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            if (_error != null)
              MaterialBanner(
                content: Text('No se pudieron cargar los perfiles: $_error'),
                leading: const Icon(Icons.error_outline),
                actions: [
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    )
                  : candidates.isEmpty
                  ? Center(
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
                              style: Theme.of(context).textTheme.titleMedium,
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
                    )
                  : ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildCandidateCard(candidates[index]),
                    ),
            ),
          ],
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.lightGreenBg,
          child: Icon(Icons.description_outlined, color: AppTheme.primaryGreen),
        ),
        title: Text(
          candidate.fullName.isEmpty
              ? 'Candidato sin nombre'
              : candidate.fullName,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate.email.isEmpty ? 'Sin correo' : candidate.email),
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
                Text(
                  'Información adicional: $additionalInfo',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                item.hasResume
                    ? 'Hoja de vida registrada'
                    : 'Hoja de vida no registrada',
                style: TextStyle(
                  color: item.hasResume
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.hasResume)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _showResumeDetails(item),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver hoja de vida'),
                  ),
                ),
              Text(
                !item.storageAvailable
                    ? 'Documento original: almacenamiento sin configurar'
                    : item.hasOriginalDocument
                    ? 'Documento original: ${candidate.resumeOriginalFilename ?? 'CV disponible'}'
                    : 'Documento original: no cargado',
              ),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: item.hasOriginalDocument && item.storageAvailable
              ? 'Descargar CV original'
              : !item.storageAvailable
              ? 'El almacenamiento de CV no está configurado'
              : 'No hay documento original cargado',
          onPressed:
              isDownloading ||
                  !item.hasOriginalDocument ||
                  !item.storageAvailable
              ? null
              : () => _download(candidate),
          icon: isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
        ),
        isThreeLine: true,
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
          TextButton(
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
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
