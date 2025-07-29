import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'sesion.dart';

class MapaPage extends StatefulWidget {
  final String proyectoId;
  final bool colaborativo;

  const MapaPage({
    super.key,
    required this.proyectoId,
    required this.colaborativo,
  });

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  bool mostrarCoordenadas = false;
  GoogleMapController? mapController;
  List<LatLng> puntos = [];
  final Set<Polygon> _poligonos = {};
  final Set<Marker> _marcadores = {};
  final Set<Polyline> _polilineas = {};
  LatLng? ubicacionActual;
  bool cargandoUbicacion = false;
  bool finalizado = false;

  @override
  void initState() {
    super.initState();
    _verificarPermisoGPS();
    _obtenerUbicacion();
    _iniciarTrackingUbicacion();
    _iniciarActualizacionPoligonoColaborativo();

    // Cargar puntos colaborativos al iniciar
    if (widget.colaborativo) {
      _cargarPuntosColaborativos();
      _iniciarActualizacionPuntosColaborativos();
    }
  }

  void _iniciarActualizacionPoligonoColaborativo() {
    Future.doWhile(() async {
      if (!finalizado) {
        await _cargarPuntosColaborativos();
        _dibujarPoligono();
        await Future.delayed(const Duration(seconds: 2));
        return true;
      }
      return false;
    });
  }

  void _iniciarActualizacionPuntosColaborativos() {
    Future.doWhile(() async {
      if (!finalizado) {
        await _cargarPuntosColaborativos();
        _dibujarPoligono();
        await Future.delayed(const Duration(seconds: 5)); // Actualizar cada 5 segundos
        return true;
      }
      return false;
    });
  }

  Future<void> _verificarPermisoGPS() async {
    final permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => cargandoUbicacion = true);
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        ubicacionActual = LatLng(pos.latitude, pos.longitude);
        cargandoUbicacion = false;
      });
    } catch (e) {
      print('Error al obtener ubicación: $e');
    }
  }

  Future<void> _subirImagenPoligono() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = 'poligono_${widget.proyectoId}_${DateTime.now().millisecondsSinceEpoch}.png';

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(fileName, fileBytes);

      final publicUrl = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('proyectos')
          .update({'imagen_poligono': publicUrl})
          .eq('id', widget.proyectoId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen subida correctamente')),
        );
      }
    }
  }

  Future<void> _cargarPuntosColaborativos() async {
  try {
    final puntosDB = await Supabase.instance.client
        .from('puntos')
        .select('latitud,longitud')
        .eq('proyecto_id', widget.proyectoId);

    setState(() {
      puntos = List<LatLng>.from(
        puntosDB.map((p) => LatLng(p['latitud'], p['longitud'])),
      );
    });

    // Hacer zoom en el último punto cargado
    if (puntos.isNotEmpty && mapController != null) {
      await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(puntos.last, 18), // Zoom nivel 18
      );
    }
  } catch (e) {
    print('Error al cargar puntos: $e');
  }
}

  void _dibujarPoligono() {
    _marcadores.clear();
    for (int i = 0; i < puntos.length; i++) {
      _marcadores.add(Marker(
        markerId: MarkerId('punto_$i'),
        position: puntos[i],
        infoWindow: InfoWindow(title: 'Punto ${i + 1}'),
      ));
    }

    _polilineas.clear();
    if (puntos.length > 1) {
      _polilineas.add(Polyline(
        polylineId: const PolylineId('linea1'),
        points: puntos,
        color: Colors.blue,
        width: 3,
      ));
    }

    _poligonos.clear();
    if (puntos.length > 2 && puntos.first == puntos.last) {
      final nuevoPoligono = Polygon(
        polygonId: const PolygonId('poligono1'),
        points: puntos,
        fillColor: const Color.fromARGB(100, 33, 150, 243),
        strokeColor: Colors.blue,
        strokeWidth: 3,
      );
      _poligonos.add(nuevoPoligono);
    }

    setState(() {});
  }

  void _iniciarTrackingUbicacion() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) async {
      ubicacionActual = LatLng(pos.latitude, pos.longitude);
      if (userIdActual != null) {
        try {
          final loc = await Supabase.instance.client
              .from('locations')
              .select('status')
              .eq('id_user', userIdActual!)
              .maybeSingle();
          if (loc != null && loc['status'] == true) {
            await Supabase.instance.client.from('locations').upsert({
              'id_user': userIdActual,
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'timestamp': DateTime.now().toIso8601String(),
              'status': true,
            }, onConflict: 'id_user');
          }
        } catch (e) {
          print('Error actualizando location: $e');
        }
      }
      setState(() {});
    });
  }

  double _calcularArea() {
    if (puntos.length < 3) return 0.0;
    List<LatLng> poly = List.from(puntos);
    if (poly.first != poly.last) {
      poly.add(poly.first);
    }
    double area = 0.0;
    for (int i = 0; i < poly.length - 1; i++) {
      area += poly[i].latitude * poly[i + 1].longitude;
      area -= poly[i + 1].latitude * poly[i].longitude;
    }
    return (area / 2).abs();
  }

  LatLng _calcularPuntoMedio() {
    if (puntos.isEmpty) {
      print('No hay puntos para calcular el punto medio.');
      return const LatLng(0, 0);
    }

    double sumaLatitudes = 0;
    double sumaLongitudes = 0;

    for (var punto in puntos) {
      sumaLatitudes += punto.latitude;
      sumaLongitudes += punto.longitude;
    }

    final puntoMedio = LatLng(
      sumaLatitudes / puntos.length,
      sumaLongitudes / puntos.length,
    );

    print('Punto medio: Latitud ${puntoMedio.latitude}, Longitud ${puntoMedio.longitude}');
    return puntoMedio;
  }

  String _determinarTipoFigura() {
    final numPuntos = puntos.length - 1; // Excluir el punto repetido al cerrar el polígono

    if (!_esPoligonoRegular()) {
      return 'Polígono Irregular';
    }

    switch (numPuntos) {
      case 3:
        return 'Triángulo';
      case 4:
        return 'Cuadrado';
      case 5:
        return 'Pentágono';
      case 6:
        return 'Hexágono';
      case 7:
        return 'Heptágono';
      case 8:
        return 'Octágono';
      case 9:
        return 'Nonágono';
      case 10:
        return 'Decágono';
      default:
        return 'Polígono';
    }
  }

  bool _esPoligonoRegular() {
    if (puntos.length < 4) return true; // Triángulos siempre son regulares

    final distancias = <double>[];

    for (int i = 0; i < puntos.length - 1; i++) {
      final dx = puntos[i + 1].latitude - puntos[i].latitude;
      final dy = puntos[i + 1].longitude - puntos[i].longitude;
      distancias.add(sqrt(dx * dx + dy * dy));
    }

    // Verificar si todas las distancias son aproximadamente iguales
    final primeraDistancia = distancias.first;
    for (final distancia in distancias) {
      if ((distancia - primeraDistancia).abs() > 0.01) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa del Proyecto')),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          mostrarCoordenadas = !mostrarCoordenadas;
                        });
                      },
                      icon: Icon(mostrarCoordenadas ? Icons.visibility_off : Icons.visibility),
                      label: Text(mostrarCoordenadas ? 'Ocultar coordenadas' : 'Ver coordenadas'),
                    ),
                  ),
                  if (mostrarCoordenadas)
                    Expanded(
                      child: puntos.isEmpty
                          ? const Center(child: Text('No hay puntos todavía'))
                          : ListView.builder(
                              itemCount: puntos.length,
                              itemBuilder: (context, index) {
                                final p = puntos[index];
                                return ListTile(
                                  title: Text('Lat: ${p.latitude.toStringAsFixed(6)}'),
                                  subtitle: Text('Lng: ${p.longitude.toStringAsFixed(6)}'),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) async {
                    mapController = controller;
                    await _cargarPuntosColaborativos();
                    _dibujarPoligono();
                  },
                  initialCameraPosition: CameraPosition(
                    target: ubicacionActual ?? const LatLng(-0.22985, -78.52495),
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polygons: _poligonos,
                  markers: _marcadores,
                  polylines: _polilineas,
                  mapType: MapType.normal,
                ),
                Positioned(
                  bottom: 80,
                  left: 20,
                  child: ElevatedButton.icon(
                    onPressed: cargandoUbicacion || finalizado ? null : _marcarUbicacionActual,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Marcar'),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: ElevatedButton.icon(
                    onPressed: puntos.length > 2 && !finalizado
                        ? () async {
                            if (puntos.isNotEmpty && puntos.first != puntos.last) {
                              setState(() {
                                puntos.add(puntos.first);
                              });
                              _dibujarPoligono();
                            }
                            final area = _calcularArea();
                            final puntoMedio = _calcularPuntoMedio();
                            final tipoFigura = _determinarTipoFigura();

                            try {
                              await Supabase.instance.client
                                  .from('territories')
                                  .update({
                                    'area': area,
                                    'latitude': puntoMedio.latitude,
                                    'longitude': puntoMedio.longitude,
                                    'polygon': tipoFigura,
                                  })
                                  .eq('id', widget.proyectoId);

                              setState(() => finalizado = true);

                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                              }
                            } catch (e) {
                              print('Error al finalizar el territorio: $e');
                            }
                          }
                        : null,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Finalizar'),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _calcularPuntoMedio,
                    child: const Text('Calcular Punto Medio'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarUbicacionActual() async {
    if (ubicacionActual == null || finalizado) return;

    if (userIdActual != null) {
      try {
        await Supabase.instance.client.from('puntos').insert({
          'usuario': userIdActual,
          'latitud': ubicacionActual!.latitude,
          'longitud': ubicacionActual!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'proyecto_id': widget.proyectoId,
        });
        await _cargarPuntosColaborativos();
        _dibujarPoligono();
      } catch (e) {
        print('Error al insertar punto: $e');
      }
    }
  }
}


