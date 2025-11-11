import 'package:flutter/material.dart';
import '../api/signals_api.dart';

class SignalHistoryPage extends StatefulWidget {
  const SignalHistoryPage({super.key});

  @override
  State<SignalHistoryPage> createState() => _SignalHistoryPageState();
}

class _SignalHistoryPageState extends State<SignalHistoryPage> {
  final _deviceCtrl = TextEditingController();
  DateTime? _from;
  DateTime? _to;

  bool _loading = false;
  String? _error;
  List<dynamic> _items = const [];

  @override
  void dispose() {
    _deviceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: isFrom ? (_from ?? now) : (_to ?? now),
    );
    if (picked != null) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fromIso = _from?.toUtc().toIso8601String();
      final toIso = _to != null
          ? DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59)
              .toUtc()
              .toIso8601String()
          : null;

      final list = await SignalsApi.fetchSignals(
        deviceId:
            _deviceCtrl.text.trim().isEmpty ? null : _deviceCtrl.text.trim(),
        fromIso: fromIso,
        toIso: toIso,
      );
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _signalColor(int? dbm) {
    if (dbm == null) return Colors.grey;
    if (dbm >= -80) return Colors.green;
    if (dbm >= -95) return Colors.orange;
    if (dbm >= -110) return Colors.redAccent;
    return Colors.red.shade900;
  }

  String _signalLabel(int? dbm) {
    if (dbm == null) return 'Desconocido';
    if (dbm >= -80) return 'Excelente';
    if (dbm >= -95) return 'Buena';
    if (dbm >= -110) return 'Regular';
    return 'Pobre';
  }

  @override
  Widget build(BuildContext context) {
    final fromStr = _from == null
        ? '—'
        : '${_from!.year}-${_from!.month.toString().padLeft(2, '0')}-${_from!.day.toString().padLeft(2, '0')}';
    final toStr = _to == null
        ? '—'
        : '${_to!.year}-${_to!.month.toString().padLeft(2, '0')}-${_to!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        elevation: 3,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          '📜 Historial de Señales',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ==== FILTROS ====
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _deviceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID del dispositivo (opcional)',
                        prefixIcon: Icon(Icons.devices),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(true),
                            icon: const Icon(Icons.calendar_today),
                            label: Text('Desde: $fromStr'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(false),
                            icon: const Icon(Icons.calendar_month),
                            label: Text('Hasta: $toStr'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: const Color(0xFF6D28D9),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),

            // ==== RESULTADOS ====
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        '❌ $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _items.isEmpty
                      ? const Center(
                          child: Text('Sin resultados',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final it = _items[i] as Map<String, dynamic>;
                            final ts = it['ts'] ?? it['timestamp'];
                            final lat = it['lat'];
                            final lon = it['lon'];
                            final brand = it['brand'];
                            final signal = it['signalDbm'];
                            final conn =
                                (it['connectionTypes'] as List?)?.join(', ') ??
                                    '';

                            final signalColor = _signalColor(signal);
                            final signalLabel = _signalLabel(signal);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: signalColor.withOpacity(0.2),
                                  child: Icon(Icons.network_cell,
                                      color: signalColor),
                                ),
                                title: Text(
                                  '$brand • $signalLabel',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'dBm: ${signal ?? 'N/A'} | Conexión: $conn'),
                                      Text('Ubicación: ($lat, $lon)'),
                                      Text('🕐 $ts',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
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
