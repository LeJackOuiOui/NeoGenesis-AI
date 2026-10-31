import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/candidate_interview_service.dart';

class CandidateScheduleSelectionScreen extends StatefulWidget {
  final String vacancyId;
  final String recruiterId;
  final String candidateId;

  const CandidateScheduleSelectionScreen({
    super.key,
    required this.vacancyId,
    required this.recruiterId,
    required this.candidateId,
  });

  @override
  State<CandidateScheduleSelectionScreen> createState() =>
      _CandidateScheduleSelectionScreenState();
}

class _CandidateScheduleSelectionScreenState
    extends State<CandidateScheduleSelectionScreen> {
  final _service = CandidateInterviewService();
  late Future<List<Map<String, dynamic>>> _slotsFuture;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _service.getAvailableSlotsForVacancy(widget.vacancyId);
  }

  Future<void> _bookInterview(Map<String, dynamic> slot) async {
    if (_isBooking) return;

    setState(() {
      _isBooking = true;
    });

    try {
      final scheduledDate = DateTime.parse(
        '${slot['date']} ${slot['start_time']}',
      );

      // Obtener el ID real del candidato.
      final candidateRow = await Supabase.instance.client
          .from('candidatos')
          .select('id')
          .eq('id', widget.candidateId)
          .maybeSingle();

      if (candidateRow == null) {
        throw Exception('No se encontró el candidato seleccionado.');
      }

      final actualCandidateId = candidateRow['id'].toString();

      // Guardar la entrevista y reservar el horario.
      await _service.bookInterview(
        vacancyId: widget.vacancyId,
        candidateId: actualCandidateId,
        recruiterId: widget.recruiterId,
        availabilityId: slot['id'].toString(),
        scheduledDateTime: scheduledDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Entrevista agendada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agendar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios disponibles')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona un horario disponible para la entrevista:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _slotsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar los horarios: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final slots = snapshot.data ?? [];

                  if (slots.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay horarios disponibles en este momento.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.event_available,
                            color: Colors.green,
                          ),
                          title: Text('Fecha: ${slot['date']}'),
                          subtitle: Text(
                            'Horario: ${slot['start_time']} - ${slot['end_time']}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: _isBooking
                                ? null
                                : () => _bookInterview(slot),
                            child: _isBooking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Seleccionar'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
