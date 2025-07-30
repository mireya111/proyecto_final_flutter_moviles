import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuariosMapaPage extends StatefulWidget {
  final List<Map<String, dynamic>> usuarios;

  const UsuariosMapaPage({super.key, required this.usuarios});

  @override
  State<UsuariosMapaPage> createState() => _UsuariosMapaPageState();
}

class _UsuariosMapaPageState extends State<UsuariosMapaPage> {
  late GoogleMapController _mapController;
  late Timer _timer;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _usuarios = widget.usuarios;
    _updateMarkers(); // Inicializar los marcadores
    _startMarkerUpdates(); // Iniciar el temporizador para actualizaciones
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancelar el temporizador al salir de la página
    super.dispose();
  }

  void _startMarkerUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Obtener datos actualizados desde la tabla "locations"
        final response = await Supabase.instance.client
            .from('locations')
            .select('id_user, users(username), latitude, longitude, status')
            .eq('status', true);

        final data = response as List<dynamic>? ?? [];
        setState(() {
          _usuarios = data.map<Map<String, dynamic>>((item) {
            return {
              'id_user': item['id_user'],
              'username': item['users']?['username'] ?? 'Usuario',
              'latitude': item['latitude'],
              'longitude': item['longitude'],
            };
          }).toList();
          _updateMarkers();
        });
      } catch (e) {
        print('Error al actualizar los marcadores: $e');
      }
    });
  }

  void _updateMarkers() {
    _markers = _usuarios.map((usuario) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarios.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Territorios Topográficos')),
        body: const Center(child: Text('No hay usuarios activos en el mapa')),
      );
    }

    final primerUsuario = _usuarios.first;
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
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}