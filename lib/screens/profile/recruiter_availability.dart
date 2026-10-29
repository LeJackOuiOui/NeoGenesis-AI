import 'package:flutter/material.dart';
import '../../data/services/recruiter_availability_service.dart';

class RecruiterAvailabilityScreen extends StatefulWidget {
  const RecruiterAvailabilityScreen({super.key});

  @override
  State<RecruiterAvailabilityScreen> createState() =>
      _RecruiterAvailabilityScreenState();
}

class _RecruiterAvailabilityScreenState
    extends State<RecruiterAvailabilityScreen> {
  final _service = RecruiterAvailabilityService();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;

  late Future<List<Map<String, dynamic>>> _availabilityFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _availabilityFuture = _service.getMyAvailability();
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> _handleSave({String? editId}) async {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha, hora de inicio y hora de fin'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final startStr = _formatTimeOfDay(_startTime!);
      final endStr = _formatTimeOfDay(_endTime!);

      if (editId == null) {
        await _service.addAvailabilityBlock(
          date: _selectedDate!,
          startTime: startStr,
          endTime: endStr,
        );
      } else {
        await _service.updateAvailabilityBlock(
          id: editId,
          date: _selectedDate!,
          startTime: startStr,
          endTime: endStr,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editId == null
                  ? 'Disponibilidad guardada'
                  : 'Disponibilidad actualizada',
            ),
          ),
        );
        setState(() {
          _selectedDate = null;
          _startTime = null;
          _endTime = null;
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditModal(Map<String, dynamic> item) {
    setState(() {
      _selectedDate = DateTime.parse(item['date']);

      final startParts = item['start_time'].toString().split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      final endParts = item['end_time'].toString().split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Bloque de Horario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fecha: ${_selectedDate!.toLocal().toString().split(' ')[0]}'),
            Text('Inicio: ${_startTime!.format(context)}'),
            Text('Fin: ${_endTime!.format(context)}'),
            const SizedBox(height: 12),
            const Text(
              'Para cambiar fecha u hora, usa los selectores principales de la pantalla.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSave(editId: item['id']);
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Mi Disponibilidad')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Selectores de fecha y hora
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _selectedDate == null
                    ? 'Seleccionar Fecha'
                    : 'Fecha: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(
                _startTime == null
                    ? 'Hora de Inicio'
                    : 'Inicio: ${_startTime!.format(context)}',
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) setState(() => _startTime = picked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: Text(
                _endTime == null
                    ? 'Hora de Fin'
                    : 'Fin: ${_endTime!.format(context)}',
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _handleSave(),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Guardar Nuevo Bloque'),
            ),
            const Divider(height: 32),
            const Text(
              'Mis Bloques Guardados (Vigentes)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Lista de espacios guardados con edición y borrado
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _availabilityFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final data = snapshot.data ?? [];
                  if (data.isEmpty) {
                    return const Center(
                      child: Text(
                        'No tienes bloques de disponibilidad activos.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      final isBooked = item['is_booked'] == true;

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.event_available,
                            color: isBooked ? Colors.orange : Colors.green,
                          ),
                          title: Text('Fecha: ${item['date']}'),
                          subtitle: Text(
                            'De ${item['start_time']} a ${item['end_time']} ${isBooked ? "(Reservado)" : ""}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isBooked)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _openEditModal(item),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: isBooked
                                    ? null
                                    : () async {
                                        await _service.deleteAvailabilityBlock(
                                          item['id'],
                                        );
                                        _loadData();
                                      },
                              ),
                            ],
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
