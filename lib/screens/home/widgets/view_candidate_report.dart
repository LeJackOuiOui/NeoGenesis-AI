import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/utils/app_error_handler.dart';
import '../../../core/utils/excel_file_builder.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/models/candidate_report_item.dart';
import '../../../data/models/vacancy_model.dart';
import '../../../data/services/candidate_report_service.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';
import 'app_page_background.dart';

class ViewCandidateReport extends StatefulWidget {
  const ViewCandidateReport({super.key});

  @override
  State<ViewCandidateReport> createState() => _ViewCandidateReportState();
}

class _ViewCandidateReportState extends State<ViewCandidateReport> {
  final _reportService = CandidateReportService(supabase);
  final _vacancyService = VacancyService(supabase);

  List<VacancyModel> _vacancies = [];
  List<CandidateReportItem> _items = [];
  String? _selectedVacancyId;
  String? _selectedStatus;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  static const _statuses = <String, String>{
    'enviada': 'Enviada',
    'aceptada': 'Aceptada',
    'rechazada': 'Rechazada',
    'cancelada': 'Cancelada',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
    });
    try {
      final results = await Future.wait([
        _vacancyService.fetchVacancies(),
        _reportService.fetchReport(
          vacancyId: _selectedVacancyId,
          status: _selectedStatus,
          from: _fromDate,
          to: _toDate,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _vacancies = results[0] as List<VacancyModel>;
        _items = results[1] as List<CandidateReportItem>;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = AppErrorHandler.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart
        ? _fromDate ?? _toDate ?? DateTime.now()
        : _toDate ?? _fromDate ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      if (isStart) {
        _fromDate = selectedDate;
        if (_toDate != null && _toDate!.isBefore(selectedDate)) {
          _toDate = selectedDate;
        }
      } else {
        _toDate = selectedDate;
        if (_fromDate != null && _fromDate!.isAfter(selectedDate)) {
          _fromDate = selectedDate;
        }
      }
    });
    await _load();
  }

  Future<void> _exportPdf() async {
    if (_items.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Text(
              'Reporte consolidado de candidatos',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(_activeFiltersLabel()),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const [
                'Vacante',
                'Candidato',
                'Correo',
                'Perfil',
                'Score',
                'Estado',
                'Registro del perfil',
              ],
              data: _items.map(_pdfRow).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF176B4D),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'reporte_candidatos.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.show(context, error, onRetry: _exportPdf);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_items.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final headers = [
        'Vacante',
        'Candidato',
        'Correo',
        'Teléfono',
        'Perfil',
        'Score',
        'Estado',
        'Registro del perfil',
      ];
      final bytes = ExcelFileBuilder.build(
        headers: headers,
        rows: _items.map(_excelRow).toList(),
      );
      await FileSaver.instance.saveFile(
        name: 'reporte_candidatos',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte Excel exportado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.show(context, error, onRetry: _exportExcel);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<String> _excelRow(CandidateReportItem item) {
    final candidate = item.candidate;
    return [
      item.vacancyTitle,
      candidate?.fullName ?? 'Perfil no disponible',
      candidate?.email ?? '',
      candidate?.phone ?? '',
      _profileSummary(candidate),
      item.score == null ? 'N/D' : '${item.score!.toStringAsFixed(0)}%',
      _statusLabel(item.status),
      _formatDate(item.candidateRegisteredAt),
    ];
  }

  List<String> _pdfRow(CandidateReportItem item) {
    final candidate = item.candidate;
    return [
      item.vacancyTitle,
      candidate?.fullName ?? 'Perfil no disponible',
      candidate?.email ?? '',
      _profileSummary(candidate),
      item.score == null ? 'N/D' : '${item.score!.toStringAsFixed(0)}%',
      _statusLabel(item.status),
      _formatDate(item.candidateRegisteredAt),
    ];
  }

  String _activeFiltersLabel() {
    final vacancyTitle = _selectedVacancyId == null
        ? 'Todas las vacantes'
        : _vacancies
                  .where((vacancy) => vacancy.id == _selectedVacancyId)
                  .map((vacancy) => vacancy.title)
                  .firstOrNull ??
              'Vacante seleccionada';
    final statusLabel = _selectedStatus == null
        ? 'Todos los estados'
        : _statusLabel(_selectedStatus!);
    return '$vacancyTitle | $statusLabel | '
        '${_fromDate == null ? 'Registro desde cualquier fecha' : 'Registro desde ${_formatDate(_fromDate)}'} | '
        '${_toDate == null ? 'Hasta cualquier fecha' : 'Hasta ${_formatDate(_toDate)}'}';
  }

  String _profileSummary(CandidateModel? candidate) {
    if (candidate == null) return 'Sin perfil disponible';
    final resume = candidate.resumeData;
    final summary = resume['summary']?.toString().trim() ?? '';
    if (summary.isNotEmpty) return summary;
    final skills = resume['skills'] is List
        ? (resume['skills'] as List).map((skill) => skill.toString()).join(', ')
        : resume['skills']?.toString() ?? '';
    final rawExperience = resume['experience_years'] ?? resume['experience'];
    final experience = rawExperience is num
        ? '${rawExperience.toStringAsFixed(1)} años'
        : rawExperience is List && rawExperience.isNotEmpty
        ? 'Experiencia registrada (${rawExperience.length} puestos)'
        : '';
    final parts = <String>[
      if (candidate.profilePosition?.isNotEmpty == true)
        'Cargo: ${candidate.profilePosition}',
      if (skills.isNotEmpty) 'Habilidades: $skills',
      if (experience.toString().isNotEmpty) 'Experiencia: $experience',
    ];
    return parts.isEmpty ? 'Perfil sin resumen' : parts.join(' | ');
  }

  String _statusLabel(String status) => _statuses[status] ?? status;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final localDate = date.toLocal();
    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
  }

  void _clearFilters() {
    setState(() {
      _selectedVacancyId = null;
      _selectedStatus = null;
      _fromDate = null;
      _toDate = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
                              'Reporte de candidatos',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Consulta y exporta las postulaciones según los filtros seleccionados.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Actualizar reporte',
                            onPressed: _isLoading ? null : _load,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Elegir formato de exportación',
                            enabled:
                                _items.isNotEmpty &&
                                !_isLoading &&
                                !_isExporting,
                            onSelected: (format) {
                              if (format == 'pdf') {
                                _exportPdf();
                              } else {
                                _exportExcel();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'pdf',
                                child: ListTile(
                                  leading: Icon(Icons.picture_as_pdf_outlined),
                                  title: Text('Exportar como PDF'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'excel',
                                child: ListTile(
                                  leading: Icon(Icons.table_chart_outlined),
                                  title: Text('Exportar como Excel'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isExporting)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.file_download_outlined,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isExporting
                                          ? 'Exportando...'
                                          : 'Exportar',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
                            width: 250,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedVacancyId,
                              decoration: const InputDecoration(
                                labelText: 'Vacante',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todas las vacantes'),
                                ),
                                ..._vacancies.map(
                                  (vacancy) => DropdownMenuItem<String?>(
                                    value: vacancy.id,
                                    child: Text(
                                      vacancy.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedVacancyId = value);
                                _load();
                              },
                            ),
                          ),
                          SizedBox(
                            width: 190,
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todos los estados'),
                                ),
                                ..._statuses.entries.map(
                                  (status) => DropdownMenuItem<String?>(
                                    value: status.key,
                                    child: Text(status.value),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedStatus = value);
                                _load();
                              },
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _selectDate(isStart: true),
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _fromDate == null
                                  ? 'Desde'
                                  : 'Registro desde ${_formatDate(_fromDate)}',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _selectDate(isStart: false),
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _toDate == null
                                  ? 'Hasta'
                                  : 'Hasta ${_formatDate(_toDate)}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('Limpiar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_items.length} candidato(s) | Score calculado según el cumplimiento proporcional de experiencia, habilidades y formación.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    MaterialBanner(
                      content: Text('No se pudo cargar el reporte: $_error'),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
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
                  else if (_items.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'No hay postulaciones para estos filtros.',
                          ),
                        ),
                      ),
                    )
                  else
                    ..._items.map(_buildCandidateCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(CandidateReportItem item) {
    final candidate = item.candidate;
    final score = item.score;
    final scoreColor = score == null
        ? Colors.grey
        : score >= 70
        ? AppTheme.primaryGreen
        : Colors.orange.shade800;
    return Card(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 3,
      shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.lightGreenBg,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate?.fullName ?? 'Perfil no disponible',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(item.vacancyTitle),
                  Text(
                    '${candidate?.email ?? 'Sin correo'}'
                    '${candidate?.phone?.isNotEmpty == true ? ' | ${candidate!.phone}' : ''}',
                  ),
                  Text(_profileSummary(candidate)),
                  Text(
                    'Estado: ${_statusLabel(item.status)} | '
                    'Registro del perfil: ${_formatDate(item.candidateRegisteredAt)}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score == null ? 'N/D' : '${score.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Score',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
