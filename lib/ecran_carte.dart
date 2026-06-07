import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CartePage extends StatelessWidget {
  final List<LatLng> pointsGPX;

  const CartePage({super.key, required this.pointsGPX});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RandoAlert - Carte'),
        backgroundColor: Colors.green,
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(47.5684, -0.7831),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.rando_alerte',
          ),
          /* if (pointsGPX.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: pointsGPX,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          */
        ],
      ),
    );
  }
}
