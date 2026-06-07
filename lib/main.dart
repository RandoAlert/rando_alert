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
      home: const CartePage(),
    );
  }
}

class CartePage extends StatelessWidget {
  final List<LatLng>
      pointsGPX; // 👈 Assurez-vous que c'est écrit exactement comme ça

  const CartePage({super.key, required this.pointsGPX}); // 👈 Et ici aussi
  @override
  State<CartePage> createState() => _CartePageState();
}

class _CartePageState extends State<CartePage> {
  final MapController _mapController = MapController();

  // FIX SECURITE : On démarre sur une vraie valeur par défaut stable (Angers / Angrie)
  LatLng _position = const LatLng(47.5684, -0.7831);
  double _monAltitude = 0.0;
  bool _chargement = true;
  List<PointGPX> _pointsGPX = [];
  CarteDef _carteActive = fondsDeCartes[0];
  List<Signalement> _signalements = [];

  String? _alerteMeteo;
  Color _couleurAlerte = Colors.transparent;

  bool _modeSuiviActif = true;
  Timer? _timerRecentrage;

  LatLng? _cibleVisee;
  double _cibleAltitude = 0.0;
  double _distanceViseeMetres = 0.0;

  @override
  void initState() {
    super.initState();
    _initialiserGPS();
  }

  @override
  void dispose() {
    _timerRecentrage?.cancel();
    super.dispose();
  }

  Future<void> _initialiserGPS() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _chargement = false);
      return;
    }
    _chargerSignalements();

    Position? dernierePos = await Geolocator.getLastKnownPosition();
    if (dernierePos != null && mounted) {
      // FIX SECURITE : On vérifie que la position stockée n'est pas NaN
      if (!dernierePos.latitude.isNaN &&
          !dernierePos.longitude.isNaN &&
          dernierePos.latitude.isFinite &&
          dernierePos.longitude.isFinite) {
        setState(() {
          _position = LatLng(dernierePos.latitude, dernierePos.longitude);
          _monAltitude =
              dernierePos.altitude.isNaN ? 0.0 : dernierePos.altitude;
          _chargement = false;
        });
        _verifierAlerteMeteoOpenMeteo();
      } else {
        if (mounted) setState(() => _chargement = false);
      }
    } else {
      if (mounted) setState(() => _chargement = false);
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position pos) async {
      // FIX SECURITE ULTRA CRUCIAL : Bloque les flux NaN pour éviter le crash écran rouge
      if (pos.latitude.isNaN ||
          pos.longitude.isNaN ||
          !pos.latitude.isFinite ||
          !pos.longitude.isFinite) {
        print("Position GPS invalide (NaN) détectée et ignorée.");
        return;
      }

      if (mounted) {
        setState(() {
          _position = LatLng(pos.latitude, pos.longitude);
          _monAltitude = pos.altitude.isNaN ? 0.0 : pos.altitude;
          _calculerMetriquesVisee();

          if (_modeSuiviActif) {
            _mapController.move(_position, _mapController.camera.zoom);
          }
        });
        _verifierAlerteMeteoOpenMeteo();
      }
    });
  }

  void _onMapPointerDown() {
    _timerRecentrage?.cancel();
    if (_modeSuiviActif) {
      setState(() => _modeSuiviActif = false);
    }
    _timerRecentrage = Timer(const Duration(seconds: 10), () {
      if (mounted && !_position.latitude.isNaN) {
        setState(() => _modeSuiviActif = true);
        _mapController.move(_position, _mapController.camera.zoom);
      }
    });
  }

  void _calculerMetriquesVisee() {
    if (_cibleVisee == null) return;
    if (_position.latitude.isNaN ||
        _cibleVisee!.latitude.isNaN ||
        !_position.latitude.isFinite ||
        !_cibleVisee!.latitude.isFinite) return;

    setState(() {
      _distanceViseeMetres = Geolocator.distanceBetween(
        _position.latitude,
        _position.longitude,
        _cibleVisee!.latitude,
        _cibleVisee!.longitude,
      );
    });
  }

  void _gererClicLongCarte(TapPosition tapPosition, LatLng point) async {
    if (point.latitude.isNaN ||
        point.longitude.isNaN ||
        !point.latitude.isFinite ||
        !point.longitude.isFinite) return;
    setState(() {
      _cibleVisee = point;
      _cibleAltitude = 0.0;
      _calculerMetriquesVisee();
    });

    final alt = await GeoLocationService.getAltitude(point);
    if (mounted && _cibleVisee == point) {
      setState(() => _cibleAltitude = alt.isNaN ? 0.0 : alt);
    }
  }

  void _verifierAlerteMeteoOpenMeteo() async {
    if (_position.latitude.isNaN || _position.longitude.isNaN) return;
    final resultat = await MeteoService.fetchVigilanceOpenMeteo(_position);
    if (mounted) {
      setState(() {
        if (resultat != null) {
          _alerteMeteo = resultat['message'];
          _couleurAlerte = MeteoService.getCouleurVigilance(
            resultat['couleur'],
          );
        } else {
          _alerteMeteo = null;
          _couleurAlerte = Colors.transparent;
        }
      });
    }
  }

  void _chargerSignalements() async {
    final items = await SupabaseService.chargerSignalements();
    if (mounted)
      setState(() => _signalements = items.where((s) => !s.estExpire).toList());
  }

  void _ouvrirGPX() async {
    //  NOUVEAU CODE
//  NOUVELLE SYNTAXE UNIQUE POUR FILE_PICKER v8+
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null) return;
    try {
      final file = File(result.files.single.path!);
      final contenu = await file.readAsString();
      final document = xml.XmlDocument.parse(contenu);
      final List<PointGPX> points = [];
      for (final p in document.findAllElements("trkpt")) {
        final lat = double.tryParse(p.getAttribute("lat") ?? "");
        final lon = double.tryParse(p.getAttribute("lon") ?? "");
        if (lat != null &&
            lon != null &&
            !lat.isNaN &&
            !lon.isNaN &&
            lat.isFinite &&
            lon.isFinite) {
          points.add(PointGPX(position: LatLng(lat, lon), altitude: 0));
        }
      }
      if (points.isNotEmpty && mounted) {
        setState(() => _pointsGPX = points);
        _mapController.move(points.first.position, 14);
      }
    } catch (e) {
      print(e);
    }
  }

  void _signalerProbleme() {
    if (_position.latitude.isNaN || _position.longitude.isNaN) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS indisponible pour le moment.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    TypeSignalement typeChoisi = typesSignalement.first;
    String desc = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Signaler un problème",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...typesSignalement.map(
                (t) => RadioListTile<TypeSignalement>(
                  title: Row(
                    children: [
                      Icon(t.icone, color: t.couleur),
                      const SizedBox(width: 12),
                      Text(t.nom, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                  value: t,
                  groupValue: typeChoisi,
                  activeColor: Colors.green,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setModalState(() => typeChoisi = v!),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Description ou précision (optionnel)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (v) => desc = v,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  final success = await SupabaseService.creerSignalement(
                    type: typeChoisi.nom,
                    latitude: _position.latitude,
                    longitude: _position.longitude,
                    description: desc,
                  );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signalement enregistré avec succès !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _chargerSignalements();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Erreur lors de l\'envoi du signalement.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text(
                  "Envoyer le signalement",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double diffAltitude = _cibleAltitude - _monAltitude;
    if (diffAltitude.isNaN || diffAltitude.isInfinite) diffAltitude = 0.0;

    String texteDistance = _distanceViseeMetres > 1000
        ? '${(_distanceViseeMetres / 1000).toStringAsFixed(2)} km'
        : '${_distanceViseeMetres.toStringAsFixed(0)} m';

    String texteDenivele = diffAltitude >= 0
        ? '+${diffAltitude.toStringAsFixed(0)} m'
        : '${diffAltitude.toStringAsFixed(0)} m';

    double margeBasseBoutons =
        (_alerteMeteo != null && _couleurAlerte != Colors.transparent)
            ? 70.0
            : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RandoAlert'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Météo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CartePage(pointsGPX: _pointsGPX)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _ouvrirGPX,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AidePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fondsDeCartes
                      .map(
                        (c) => ListTile(
                          title: Text(c.nom),
                          onTap: () {
                            setState(() => _carteActive = c);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Listener(
              onPointerDown: (_) => _onMapPointerDown(),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _position,
                      initialZoom: 14,
                      maxZoom: _carteActive.maxZoom.toDouble(),
                      onLongPress: _gererClicLongCarte,
                    ),
                    mapController: _mapController,
                    children: [
                      TileLayer(
                        urlTemplate: _carteActive.url,
                        userAgentPackageName: 'com.example.rando_alerte',
                      ),
                      if (_pointsGPX.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points:
                                  _pointsGPX.map((p) => p.position).toList(),
                              strokeWidth: 4.0,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      if (_cibleVisee != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_position, _cibleVisee!],
                              strokeWidth: 3.0,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _position,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                          if (_cibleVisee != null)
                            Marker(
                              point: _cibleVisee!,
                              child: const Icon(
                                Icons.gps_fixed,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          ..._signalements.map((s) {
                            final t = typesSignalement.firstWhere(
                              (element) => element.nom == s.type,
                              orElse: () => typesSignalement.last,
                            );
                            return Marker(
                              point: s.position,
                              child: GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(s.type),
                                    content: Text(s.description),
                                  ),
                                ),
                                child: Icon(
                                  t.icone,
                                  color: t.couleur,
                                  size: 30,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                  if (_cibleVisee != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 80,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              texteDistance,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              texteDenivele,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _cibleVisee = null),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: margeBasseBoutons,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: 'gps',
                          mini: true,
                          backgroundColor:
                              _modeSuiviActif ? Colors.green : Colors.white,
                          foregroundColor:
                              _modeSuiviActif ? Colors.white : Colors.green,
                          onPressed: () {
                            if (!_position.latitude.isNaN) {
                              setState(() => _modeSuiviActif = true);
                              _mapController.move(_position, 15);
                            }
                          },
                          child: const Icon(Icons.gps_fixed),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 65,
                          height: 65,
                          child: FloatingActionButton(
                            heroTag: 'alert',
                            backgroundColor: Colors.red.shade600,
                            elevation: 6,
                            onPressed: _signalerProbleme,
                            child: const Icon(Icons.add_alert, size: 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_alerteMeteo != null &&
                      _couleurAlerte != Colors.transparent)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: _couleurAlerte,
                        padding: const EdgeInsets.all(12),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: MeteoService.getTextColor(
                                  _couleurAlerte,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _alerteMeteo!,
                                  style: TextStyle(
                                    color: MeteoService.getTextColor(
                                      _couleurAlerte,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

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
            const SizedBox(height: 8),
            const Text(
              "Pour importer une trace de randonnée, nous vous recommandons ces deux outils gratuits :",
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text(
                  "Randogps.net",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                subtitle: const Text(
                  "Des milliers de circuits et traces GPS de randonnée pédestre à télécharger gratuitement en France.",
                ),
                leading: const Icon(Icons.language, color: Colors.grey),
                onTap: () => _lancerNavigateur("https://www.randogps.net/"),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: ListTile(
                title: const Text(
                  "VisuGPX.com",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                subtitle: const Text(
                  "Permet de créer facilement vos itinéraires, les analyser, calculer les profils et partager vos traces GPS.",
                ),
                leading: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.grey,
                ),
                onTap: () => _lancerNavigateur("https://www.visugpx.com/"),
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "RandoAlert — Version Terrain 2026",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
