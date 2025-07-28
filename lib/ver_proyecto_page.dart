import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VerProyectoPage extends StatelessWidget {
  final Map proyecto;
  const VerProyectoPage({super.key, required this.proyecto});

  @override
  Widget build(BuildContext context) {
    final LatLng centro = const LatLng(-0.22985, -78.52495);

    return Scaffold(
      appBar: AppBar(title: Text(proyecto['nombre'] ?? 'Proyecto')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: centro, zoom: 15),
        myLocationEnabled: true,
        mapType: MapType.hybrid,
      ),
    );
  }
}

