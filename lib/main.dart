import 'ecran_carte.dart';
import 'ecran_meteo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart' as fmtc;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class AppConfig {
  static const String supabaseUrl = 'https://sybfkrkmgaikofmpptqa.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_eV3P0v5ytn6TMBUAObQzyQ_gXZSJjU7';
}

class GeoLocationService {
  static Future<double> getAltitude(LatLng position) async {
    if (position.latitude.isNaN ||
        position.longitude.isNaN ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite) return 0.0;
    try {
      final url =
          'https://data.geopf.fr/altimetrie/resources/elevation.json?lon=${position.longitude}&lat=${position.latitude}';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elevations = data['elevations'] as List<dynamic>?;
        if (elevations != null && elevations.isNotEmpty) {
          return double.tryParse(elevations[0]['z'].toString()) ?? 0.0;
        }
      }
    } catch (e) {
      print('Erreur API Altitude: $e');
    }
    return 0.0;
  }
}

class MeteoService {
  static Future<Map<String, dynamic>?> fetchVigilanceOpenMeteo(
    LatLng pos,
  ) async {
    if (pos.latitude.isNaN ||
        pos.longitude.isNaN ||
        !pos.latitude.isFinite ||
        !pos.longitude.isFinite ||
        pos.latitude == 0.0) return null;
    try {
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=weather_code&timezone=auto&models=meteofrance&alert_events=true';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final warnings = data['warnings'] as List<dynamic>? ??
            data['alerts'] as List<dynamic>?;

        if (warnings != null && warnings.isNotEmpty) {
          final firstAlert = warnings[0];
          final event = firstAlert['event'] as String? ?? 'Alerte météo';
          final headline = firstAlert['headline'] as String? ?? '';

          String couleur = 'jaune';
          final txtAlerte = '$event $headline'.toLowerCase();

          if (txtAlerte.contains('orange') ||
              txtAlerte.contains('severe') ||
              txtAlerte.contains('modéré')) {
            couleur = 'orange';
          } else if (txtAlerte.contains('rouge') ||
              txtAlerte.contains('red') ||
              txtAlerte.contains('extreme')) {
            couleur = 'rouge';
          }

          return {
            'message': headline.isNotEmpty ? '$event : $headline' : event,
            'couleur': couleur,
          };
        }
      }
    } catch (e) {
      print('Erreur API Open-Météo: $e');
    }
    return null;
  }

  static Color getCouleurVigilance(String couleur) {
    if (couleur == 'jaune') return Colors.orange.shade400;
    if (couleur == 'orange') return Colors.orange.shade800;
    if (couleur == 'rouge') return Colors.red;
    return Colors.transparent;
  }

  static Color getTextColor(Color background) => Colors.white;
}

class SupabaseService {
  static final _client = Supabase.instance.client;

  static Future<List<Signalement>> chargerSignalements() async {
    try {
      final List<dynamic> response = await _client
          .from('signalements')
          .select()
          .order('created_at', ascending: false);

      return response.map((item) {
        return Signalement(
          id: item['id']?.toString() ?? '',
          type: item['type'] as String? ?? 'Autre',
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          description: item['description'] as String? ?? '',
          createdAt: DateTime.parse(item['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      print('Erreur Supabase chargement: $e');
      return [];
    }
  }

  static Future<bool> creerSignalement({
    required String type,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      await _client.from('signalements').insert({
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
      });
      return true;
    } catch (e) {
      print('Erreur insertion Supabase: $e');
      return false;
    }
  }
}

class CarteDef {
  final String nom;
  final String url;
  final int maxZoom;
  const CarteDef({required this.nom, required this.url, this.maxZoom = 19});
}

class PointGPX {
  final LatLng position;
  final double altitude;
  const PointGPX({required this.position, required this.altitude});
}

class Signalement {
  final String id;
  final String type;
  final double latitude;
  final double longitude;
  final String description;
  final DateTime createdAt;

  const Signalement({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.createdAt,
  });

  LatLng get position => LatLng(latitude, longitude);

  bool get estExpire {
    final t = typesSignalement.firstWhere(
      (element) => element.nom == type,
      orElse: () => typesSignalement.last,
    );
    return DateTime.now().difference(createdAt).inHours > t.dureeHeures;
  }
}

class TypeSignalement {
  final String nom;
  final IconData icone;
  final Color couleur;
  final int dureeHeures;
  const TypeSignalement({
    required this.nom,
    required this.icone,
    required this.couleur,
    required this.dureeHeures,
  });
}

const List<TypeSignalement> typesSignalement = [
  TypeSignalement(
    nom: 'Troupeau / Clôture',
    icone: Icons.pets,
    couleur: Colors.brown,
    dureeHeures: 4,
  ),
  TypeSignalement(
    nom: 'Sentier inondé',
    icone: Icons.water,
    couleur: Colors.blue,
    dureeHeures: 336,
  ),
  TypeSignalement(
    nom: 'Arbre / Branche tombée',
    icone: Icons.forest,
    couleur: Colors.green,
    dureeHeures: 672,
  ),
  TypeSignalement(
    nom: 'Balisage manquant',
    icone: Icons.wrong_location,
    couleur: Colors.red,
    dureeHeures: 672,
  ),
  TypeSignalement(
    nom: 'Travaux / Chemin fermé',
    icone: Icons.construction,
    couleur: Colors.orange,
    dureeHeures: 720,
  ),
  TypeSignalement(
    nom: 'Autre',
    icone: Icons.warning,
    couleur: Colors.grey,
    dureeHeures: 720,
  ),
];

const List<CarteDef> fondsDeCartes = [
  CarteDef(
    nom: 'Open Topo Map',
    url: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    maxZoom: 17,
  ),
  CarteDef(
    nom: 'OSM Standard',
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    maxZoom: 19,
  ),
  CarteDef(
    nom: 'OSM France',
    url: 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
    maxZoom: 20,
  ),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fmtc.FMTCObjectBoxBackend().initialise();
  await fmtc.FMTCStore('mapCache').manage.create();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const RandoAlerteApp());
}

class RandoAlerteApp extends StatelessWidget {
  const RandoAlerteApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RandoAlert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: false,
      ),
      // On affiche directement notre écran de carte personnalisé avec une liste vide au démarrage
      home: const CartePage(pointsGPX: []),
    );
  }
}

// L'ÉCRAN D'AIDE RESTE ICI COMME DEMANDÉ
class AidePage extends StatelessWidget {
  const AidePage({super.key});

  Future<void> _lancerNavigateur(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Erreur lien : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aide & Mode d'emploi"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.explore, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Text(
                  "Fonction Visée & Guidage",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Besoin de connaître la distance d'un sommet ou d'un carrefour visible au loin ? L'application intègre un outil de calcul topographique instantané.",
              style: TextStyle(color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Comment ça marche ?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "1. Faites un clic long sur la carte à l'endroit que vous visez (votre objectif).",
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    "2. Une ligne bleue relie instantanément votre position GPS actuelle et ce point.",
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    "3. Un encadré apparaît en haut de l'écran avec deux informations cruciales :",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 12.0),
                    child: Text(
                      "• En bleu : La distance à vol d'oiseau.\n• En orange : Le dénivelé exact à franchir calculé grâce aux bases de données altimétriques.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.map, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text(
                  "Où trouver des tracés GPX ?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
