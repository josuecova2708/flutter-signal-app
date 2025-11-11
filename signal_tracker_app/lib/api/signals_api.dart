// lib/api/signals_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignalsApi {
  // IMPORTANTE: ajusta el host según tu caso:
  // - Emulador Android -> http://10.0.2.2:3000
  // - Dispositivo físico -> http://IP_DE_TU_PC:3000
  static const String baseUrl = 'https://backend-sop-production.up.railway.app';

  static Future<Map<String, dynamic>> createSignal(
      Map<String, dynamic> collectedData) async {
    final payload = {
      'Lat': collectedData['location']['latitude'],
      'lon': collectedData['location']['longitude'],
      'alt': collectedData['location']['altitude'],
      'Brand': collectedData['device_info']['brand'],
      'signal': collectedData['cellular']['signal_strength_dbm'],
      'connection_types':
          List<String>.from(collectedData['network']['connection_types']),
      'device_id': collectedData['device_id'],
      'timestamp': collectedData['timestamp'],
    };

    final res = await http.post(
      Uri.parse('$baseUrl/signals'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('POST /signals ${res.statusCode}: ${res.body}');
  }

  static Future<List<dynamic>> fetchSignals({
    String? deviceId,
    String? fromIso,
    String? toIso,
    int? take,
  }) async {
    final query = <String, String>{};
    if (deviceId != null && deviceId.isNotEmpty) query['device_id'] = deviceId;
    if (fromIso != null && fromIso.isNotEmpty) query['from'] = fromIso;
    if (toIso != null && toIso.isNotEmpty) query['to'] = toIso;
    // `take` es opcional; tu backend por ahora fija a 100. Si luego lo soportas, lo pasas aquí.

    final uri = Uri.parse('$baseUrl/signals').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('GET /signals ${res.statusCode}: ${res.body}');
  }
}
