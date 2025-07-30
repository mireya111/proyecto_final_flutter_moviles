import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UsuariosMapaPage extends StatelessWidget {
  final List<Map<String, dynamic>> usuarios;

  const UsuariosMapaPage({super.key, required this.usuarios});

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Territorios Topográficos')),
        body: const Center(child: Text('No hay usuarios activos en el mapa')),
      );
    }

    Set<Marker> markers = usuarios.map((usuario) {
      return Marker(
        markerId: MarkerId(usuario['id_user'].toString()),
        position: LatLng(
          usuario['latitude'] ?? 0.0,
          usuario['longitude'] ?? 0.0,
        ),
        infoWindow: InfoWindow(
          title: usuario['username'] ?? 'Usuario',
          snippet: 'Lat: ${usuario['latitude']}, Lng: ${usuario['longitude']}',
        ),
      );
    }).toSet();

    final primerUsuario = usuarios.first;
    final CameraPosition initialPosition = CameraPosition(
      target: LatLng(
        primerUsuario['latitude'] ?? 0.0,
        primerUsuario['longitude'] ?? 0.0,
      ),
      zoom: 12,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios en mapa')),
      body: GoogleMap(
        initialCameraPosition: initialPosition,
        markers: markers,
      ),
    );
  }
}