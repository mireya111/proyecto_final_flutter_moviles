import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  bool mostrarBarraLateral = true;
  GoogleMapController? mapController;
  List<LatLng> puntos = [];
  final Set<Polygon> _poligonos = {};
  final Set<Marker> _marcadores = {};
  final Set<Polyline> _polilineas = {};
  LatLng? ubicacionActual;
  bool cargandoUbicacion = false;
  bool finalizado = false;
  String? creadorId;

  @override
  void initState() {
    super.initState();
    _verificarPermisoGPS();
    _obtenerUbicacion();
    _iniciarTrackingUbicacion();
    _iniciarActualizacionPoligonoColaborativo();

    if (widget.colaborativo) {
      _cargarPuntosColaborativos();
      _iniciarActualizacionPuntosColaborativos();
    }
    _cargarCreador();
  }

  Future<void> _cargarCreador() async {
    try {
      final response = await Supabase.instance.client
          .from('territories')
          .select('creador')
          .eq('id', widget.proyectoId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          creadorId = response['creador'];
        });
      }
    } catch (e) {
      print('Error al cargar el creador: $e');
    }
  }

  @override
  void dispose() {
    // Libera el controlador del mapa
    mapController?.dispose();
    super.dispose();
  }

  void _iniciarActualizacionPoligonoColaborativo() {
    Future.doWhile(() async {
      if (!finalizado && mounted) {
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
      if (!finalizado && mounted) {
        await _cargarPuntosColaborativos();
        _dibujarPoligono();
        await Future.delayed(
          const Duration(seconds: 5),
        ); // Actualizar cada 5 segundos
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
      if (mounted) {
        setState(() {
          ubicacionActual = LatLng(pos.latitude, pos.longitude);
          cargandoUbicacion = false;
        });
      }
    } catch (e) {
      print('Error al obtener ubicación: $e');
    }
  }

  Future<void> _cargarPuntosColaborativos() async {
    try {
      final puntosDB = await Supabase.instance.client
          .from('puntos')
          .select('latitud,longitud')
          .eq('proyecto_id', widget.proyectoId);
      if (mounted) {
        setState(() {
          puntos = List<LatLng>.from(
            puntosDB.map((p) => LatLng(p['latitud'], p['longitud'])),
          );
        });
      }

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
      _marcadores.add(
        Marker(
          markerId: MarkerId('punto_$i'),
          position: puntos[i],
          infoWindow: InfoWindow(title: 'Punto ${i + 1}'),
        ),
      );
    }

    _polilineas.clear();
    if (puntos.length > 1) {
      _polilineas.add(
        Polyline(
          polylineId: const PolylineId('linea1'),
          points: puntos,
          color: Colors.blue,
          width: 3,
        ),
      );
    }

    _poligonos.clear();
    if (puntos.length > 2) {
      final puntosPoligono = List<LatLng>.from(puntos);
      if (puntosPoligono.first != puntosPoligono.last) {
        puntosPoligono.add(puntosPoligono.first);
      }

      final nuevoPoligono = Polygon(
        polygonId: const PolygonId('poligono1'),
        points: puntosPoligono,
        fillColor: const Color.fromARGB(100, 33, 150, 243),
        strokeColor: Colors.blue,
        strokeWidth: 3,
      );
      _poligonos.add(nuevoPoligono);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _iniciarTrackingUbicacion() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) async {
      setState(() {
        ubicacionActual = LatLng(pos.latitude, pos.longitude);
      });
      if (userIdActual != null) {
        try {
          await Supabase.instance.client.from('locations').upsert({
            'id_user': userIdActual,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'timestamp': DateTime.now().toIso8601String(),
            'status': true,
          }, onConflict: 'id_user');
        } catch (e) {
          print('Error actualizando location: $e');
        }
      }
    });
  }

  double _calcularArea() {
    if (puntos.length < 3) return 0.0;
    List<LatLng> poly = List.from(puntos);
    if (poly.first != poly.last) {
      poly.add(poly.first);
    }
    double total = 0.0;
    final earthRadius = 6378137.0; // Radio de la Tierra en metros
    for (int i = 0; i < poly.length - 1; i++) {
      final p1 = poly[i];
      final p2 = poly[i + 1];
      total +=
          (p2.longitude * pi / 180 - p1.longitude * pi / 180) *
          (2 + sin(p1.latitude * pi / 180) + sin(p2.latitude * pi / 180));
    }
    return (total * earthRadius * earthRadius / 2).abs();
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

    print(
      'Punto medio: Latitud ${puntoMedio.latitude}, Longitud ${puntoMedio.longitude}',
    );
    return puntoMedio;
  }

  String _determinarTipoFigura() {
    final numPuntos =
        puntos.length - 1; // Excluir el punto repetido al cerrar el polígono

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
        return 'Círculo';
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

  double _determinarZoomDesdeArea(double area) {
    if (area < 500) return 19;
    if (area < 2000) return 18;
    if (area < 10000) return 17;
    if (area < 50000) return 16;
    if (area < 200000) return 15;
    return 14; // Más lejos para áreas grandes
  }

  void _mostrarArea() {
    final area = _calcularArea();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Área del Territorio'),
        content: Text('El área calculada es: ${area.toStringAsFixed(2)} m²'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  LatLng _calcularCentro(List<LatLng> puntos) {
    double lat = 0.0;
    double lng = 0.0;

    for (var punto in puntos) {
      lat += punto.latitude;
      lng += punto.longitude;
    }

    return LatLng(lat / puntos.length, lng / puntos.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Territorio'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Row(
        children: [
          if (mostrarBarraLateral) _buildBarraLateral(),
          Expanded(
            flex: mostrarBarraLateral ? 3 : 1,
            child: Stack(
              children: [
                _buildGoogleMap(),
                if (!mostrarBarraLateral) _buildMostrarCoordenadasButton(),
                _buildMarcarUbicacionButton(),
                _buildFinalizarButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraLateral() {
    return Expanded(
      flex: 1,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildBarraLateralHeader(),
            Expanded(
              child: puntos.isEmpty
                  ? const Center(child: Text('No hay puntos todavía'))
                  : ListView.builder(
                      itemCount: puntos.length,
                      itemBuilder: (context, index) {
                        final p = puntos[index];
                        return ListTile(
                          title: Text('Lat: ${p.latitude.toStringAsFixed(6)}'),
                          subtitle: Text(
                            'Lng: ${p.longitude.toStringAsFixed(6)}',
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: () => _mostrarArea(),
              child: const Text('Mostrar Área'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraLateralHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Coordenadas',
              style: TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                mostrarBarraLateral = false;
              });
            },
            icon: const Icon(Icons.visibility_off),
            tooltip: 'Ocultar coordenadas',
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleMap() {
    return Stack(
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
          myLocationEnabled: !finalizado,
          myLocationButtonEnabled: !finalizado,
          polygons: _poligonos,
          markers: _marcadores,
          polylines: _polilineas,
          mapType: MapType.normal,
        ),
      ],
    );
  }

  Widget _buildMostrarCoordenadasButton() {
    return Positioned(
      top: 20,
      left: 20,
      child: FloatingActionButton(
        mini: true,
        onPressed: () {
          setState(() {
            mostrarBarraLateral = true;
          });
        },
        child: const Icon(Icons.visibility),
        tooltip: 'Mostrar coordenadas',
      ),
    );
  }

  Widget _buildMarcarUbicacionButton() {
    return Positioned(
      bottom: 80,
      left: 20,
      child: ElevatedButton.icon(
        onPressed: cargandoUbicacion || finalizado
            ? null
            : _marcarUbicacionActual,
        icon: const Icon(Icons.add_location),
        label: const Text('Marcar'),
      ),
    );
  }

  Positioned _buildFinalizarButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: ElevatedButton.icon(
        onPressed:
            (puntos.length > 2 && !finalizado && userIdActual == creadorId)
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

                  if (context.mounted) {
                    _mostrarModalFinalizar(context);
                  }
                } catch (e) {
                  print('Error al finalizar el territorio: $e');
                }
              }
            : null,
        icon: const Icon(Icons.check_circle),
        label: const Text('Finalizar Escaneo'),
      ),
    );
  }

  void _mostrarModalFinalizar(BuildContext context) {
    bool cargandoImagen = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Finalizar Escaneo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: cargandoImagen
                        ? const Center(child: CircularProgressIndicator())
                        : const Center(
                            child: Text(
                              'Se generará una captura del mapa con las líneas y el área completa.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    setStateDialog(() {
                      cargandoImagen = true; // Activa el estado de carga
                    });

                    try {
                      setState(() {
                        finalizado = true;
                      });

                      // Dibujar el polígono con zIndex para que se muestre por encima
                      _dibujarPoligonoConZIndex();

                      // Guardar los marcadores originales
                      final Set<Marker> marcadoresOriginales = Set.from(
                        _marcadores,
                      );

                      // Ocultar los marcadores y deshabilitar la ubicación del usuario
                      setState(() {
                        _marcadores.clear();
                      });

                      // Calcular el área y el punto medio
                      final area = _calcularArea();
                      final puntoMedio = _calcularCentro(puntos);
                      final zoom = _determinarZoomDesdeArea(area);

                      // Ajustar la cámara al punto medio y al zoom calculado
                      await mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(puntoMedio, zoom),
                      );

                      // Capturar el mapa
                      final Uint8List? captura = await mapController
                          ?.takeSnapshot();

                      // Restaurar los marcadores y la ubicación del usuario
                      setState(() {
                        _marcadores.addAll(marcadoresOriginales);
                      });

                      if (captura != null) {
                        // Subir la captura al almacenamiento de Supabase
                        final fileName =
                            'captura_mapa_${widget.proyectoId}_${DateTime.now().millisecondsSinceEpoch}.png';
                        await Supabase.instance.client.storage
                            .from('uploads')
                            .uploadBinary(fileName, captura);

                        final imageUrl = Supabase.instance.client.storage
                            .from('uploads')
                            .getPublicUrl(fileName);

                        // Actualizar el territorio con la URL de la imagen
                        await Supabase.instance.client
                            .from('territories')
                            .update({
                              'imagen_poligono': imageUrl,
                              'finalizado': true,
                            })
                            .eq('id', widget.proyectoId);

                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                            (route) => false,
                          );
                        }
                      } else {
                        throw Exception('No se pudo capturar el mapa');
                      }
                    } catch (e) {
                      print('Error al capturar o subir la imagen: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error al capturar o subir la imagen',
                            ),
                          ),
                        );
                      }
                    } finally {
                      setStateDialog(() {
                        cargandoImagen = false; // Desactiva el estado de carga
                      });
                    }
                  },
                  child: const Text('Capturar y Subir'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Regresar al Proyecto'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Función para dibujar el polígono con zIndex
  void _dibujarPoligonoConZIndex() {
    _poligonos.clear();
    if (puntos.length > 2) {
      final puntosPoligono = List<LatLng>.from(puntos);
      if (puntosPoligono.first != puntosPoligono.last) {
        puntosPoligono.add(puntosPoligono.first);
      }

      final nuevoPoligono = Polygon(
        polygonId: const PolygonId('poligono1'),
        points: puntosPoligono,
        fillColor: const Color.fromARGB(100, 33, 150, 243),
        strokeColor: Colors.blue,
        strokeWidth: 3,
        zIndex: 1,
      );
      _poligonos.add(nuevoPoligono);
    }

    _polilineas.clear();
    if (puntos.length > 1) {
      _polilineas.add(
        Polyline(
          polylineId: const PolylineId('linea1'),
          points: puntos,
          color: Colors.blue,
          width: 3,
          zIndex: 1,
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _marcarUbicacionActual() async {
    if (finalizado) return;

    try {
      // Obtén la ubicación actual en tiempo real
      final Position pos = await Geolocator.getCurrentPosition();

      // Actualiza la ubicación actual
      final nuevaUbicacion = LatLng(pos.latitude, pos.longitude);

      // Agrega el nuevo punto a la lista de puntos inmediatamente
      setState(() {
        puntos.add(nuevaUbicacion);
        _dibujarPoligono(); // Redibuja el polígono con el nuevo punto
      });

      // Inserta la ubicación actual en la base de datos en segundo plano
      await Supabase.instance.client.from('puntos').insert({
        'usuario': userIdActual,
        'latitud': nuevaUbicacion.latitude,
        'longitud': nuevaUbicacion.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'proyecto_id': widget.proyectoId,
      });
    } catch (e) {
      print('Error al insertar punto: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al marcar la ubicación')),
        );
      }
    }
  }
}
