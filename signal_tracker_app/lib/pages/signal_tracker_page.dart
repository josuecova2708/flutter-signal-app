// lib/pages/signal_tracker_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';

import '../api/signals_api.dart';
import 'signal_history_page.dart';

class SignalTrackerPage extends StatefulWidget {
  const SignalTrackerPage({super.key});

  @override
  State<SignalTrackerPage> createState() => _SignalTrackerPageState();
}

class _SignalTrackerPageState extends State<SignalTrackerPage> {
  final FlutterInternetSignal internetSignal = FlutterInternetSignal();
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final NetworkInfo networkInfo = NetworkInfo();

  Map<String, dynamic>? collectedData;
  bool isCollecting = false;
  bool isAutoMode = false;
  String? errorMessage;
  Timer? autoTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.phone,
      Permission.sms,
    ].request();
  }

  Future<Map<String, dynamic>> _collectData() async {
    setState(() {
      isCollecting = true;
      errorMessage = null;
    });

    try {
      // 1. Ubicación
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. Dispositivo
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      // 3. Señal celular
      String? networkOperator = 'N/A';
      int? signalStrength;
      String networkType = 'Unknown';

      try {
        signalStrength = await internetSignal.getMobileSignalStrength();
        networkType = 'Mobile/Cellular';
        networkOperator = androidInfo.version.sdkInt >= 29
            ? androidInfo.display.split(' ').first
            : 'N/A';
      } catch (e) {
        networkOperator = 'N/A o Error';
        signalStrength = null;
        networkType = 'N/A o Error';
      }

      // 4. Red
      final rawConnectivityResult = await Connectivity().checkConnectivity();
      List<String> connectionTypes = [
        rawConnectivityResult.toString().split('.').last
      ];

      String? wifiIP = await networkInfo.getWifiIP();
      String? wifiBSSID = await networkInfo.getWifiBSSID();

      // 5. Datos
      final data = {
        'device_id': androidInfo.id,
        'device_info': {
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'android_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
        },
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
        },
        'cellular': {
          'signal_strength_dbm': signalStrength,
          'network_operator': networkOperator,
          'network_type': networkType,
          'note': signalStrength == null
              ? 'Sin datos de señal o permiso faltante'
              : 'dBm obtenido de forma nativa con flutter_internet_signal',
        },
        'network': {
          'connection_types': connectionTypes,
          'wifi_ip': wifiIP ?? 'N/A',
          'wifi_bssid': wifiBSSID ?? 'N/A',
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      setState(() {
        collectedData = data;
        isCollecting = false;
      });

      return data;
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isCollecting = false;
      });
      rethrow;
    }
  }

  // === NUEVO: recolecta y hace POST (manual y auto) ===
  Future<void> _collectAndPost() async {
    try {
      final data = await _collectData(); // actualiza UI
      final created = await SignalsApi.createSignal(data);
      if (!isAutoMode) {
        // Solo notificamos en modo manual
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado en BD ✔')),
        );
      }
      // print(created); // por si quieres ver el retorno
    } catch (e) {
      if (!isAutoMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      } else {
        // en auto no spameamos al usuario
        // print('Auto-save error: $e');
      }
    }
  }

  void _startAutoCollection() {
    setState(() => isAutoMode = true);

    // Recolecta+POST inmediato
    _collectAndPost();

    // Cada 10s recolecta+POST
    autoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _collectAndPost();
    });
  }

  void _stopAutoCollection() {
    setState(() => isAutoMode = false);
    autoTimer?.cancel();
  }

  String _getSignalQuality(int? dbm) {
    if (dbm == null) return 'Desconocido';
    if (dbm >= -80) return 'Excelente';
    if (dbm >= -95) return 'Buena';
    if (dbm >= -110) return 'Regular';
    return 'Pobre';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('📡 Signal Tracker'),
        actions: [
          IconButton(
            tooltip: 'Ver historial (GET)',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignalHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Botones de control
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    // AHORA hace POST manual
                    onPressed: isCollecting ? null : _collectAndPost,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recopilar & Guardar'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        isAutoMode ? _stopAutoCollection : _startAutoCollection,
                    icon: Icon(isAutoMode ? Icons.pause : Icons.play_arrow),
                    label: Text(isAutoMode ? 'Detener' : 'Auto (10s)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAutoMode ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (isCollecting) const Center(child: CircularProgressIndicator()),

            if (errorMessage != null)
              Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('❌ Error: $errorMessage',
                      style: const TextStyle(color: Colors.red)),
                ),
              ),

            if (collectedData != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📊 Datos en JSON:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 10),
                      SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(collectedData),
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('📋 Vista Resumida:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildInfoCard('🔧 Dispositivo', [
                Text('ID: ${collectedData!['device_id']}'),
                Text('Marca: ${collectedData!['device_info']['brand']}'),
                Text('Modelo: ${collectedData!['device_info']['model']}'),
                Text(
                    'Android: ${collectedData!['device_info']['android_version']}'),
              ]),
              _buildInfoCard('📍 Ubicación', [
                Text(
                    'Lat: ${collectedData!['location']['latitude'].toStringAsFixed(6)}'),
                Text(
                    'Lon: ${collectedData!['location']['longitude'].toStringAsFixed(6)}'),
                Text(
                    'Precisión: ${collectedData!['location']['accuracy'].toStringAsFixed(2)}m'),
                Text(
                    'Velocidad: ${collectedData!['location']['speed'].toStringAsFixed(2)} m/s'),
              ]),
              _buildInfoCard(
                  '📶 Señal Celular',
                  [
                    Text(
                        'dBm: ${collectedData!['cellular']['signal_strength_dbm'] ?? 'N/A'}'),
                    Text(
                        'Calidad: ${_getSignalQuality(collectedData!['cellular']['signal_strength_dbm'] as int?)}'),
                    Text(
                        'Operador: ${collectedData!['cellular']['network_operator']}'),
                    Text('Tipo: ${collectedData!['cellular']['network_type']}'),
                    Text(collectedData!['cellular']['note'] as String,
                        style: const TextStyle(
                            fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                  color: Colors.orange[50]),
              _buildInfoCard('🌐 Red', [
                Text(
                    'Conexiones: ${collectedData!['network']['connection_types'].join(', ')}'),
                Text('IP WiFi: ${collectedData!['network']['wifi_ip']}'),
                Text('BSSID: ${collectedData!['network']['wifi_bssid']}'),
              ]),
              _buildInfoCard('🕐 Timestamp', [
                Text(DateTime.parse(collectedData!['timestamp'])
                    .toLocal()
                    .toString()),
              ]),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('👆 Presiona "Recopilar & Guardar" para empezar',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> items, {Color? color}) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple)),
          const SizedBox(height: 10),
          ...items
              .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0), child: item))
              .toList(),
        ]),
      ),
    );
  }
}
