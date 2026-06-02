import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class GeoService {
  static Future<String?> getDepartementCode(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RandoAlert/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        // Essayer de trouver le code département dans les détails
        final dept =
            address?['ISO3166-2-lvl4'] ?? // Ex: "FR-49"
            address?['county_code'] ?? // Alternative
            address?['state_code']; // Alternative
        if (dept != null && dept is String) {
          // Extraire le code (ex: "FR-49" -> "49")
          return dept.split('-').last;
        }
      }
    } catch (e) {
      print('Erreur GeoService: $e');
      return null;
    }
    return null; // Retourne null si non trouvé
  }
}
