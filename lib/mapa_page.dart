import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
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

  Uint8List? _imageBytes;
  String? _imageName;

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

  Future<Uint8List> _resizeImage(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('No se pudo procesar la imagen');

    final resized = img.copyResize(image, width: 1080, height: 1350);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<void> _pickImageFromGallery(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);

    if (result != null) {
      final bytes = await result.readAsBytes();
      final resizedBytes = await _resizeImage(bytes);

      setState(() {
        _imageBytes = resizedBytes;
        _imageName = result.name;
      });

      setStateDialog(() {}); // Así se usa correctamente un StateSetter
    }
  }

  Future<void> _pickImageFromCamera(StateSetter setStateDialog) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);

    if (result != null) {
      final bytes = await result.readAsBytes();
      final resizedBytes = await _resizeImage(bytes);

      setState(() {
        _imageBytes = resizedBytes;
        _imageName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });

      setStateDialog(() {});
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null || _imageName == null) return null;

    try {
      final fileName =
          'poligono_${widget.proyectoId}_${DateTime.now().millisecondsSinceEpoch}_$_imageName';
      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(fileName, _imageBytes!);

      final imageUrl = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  @override
  void dispose() {
    // Libera el controlador del mapa
    mapController?.dispose();
    super.dispose();
  }

  Positioned _buildFinalizarButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: ElevatedButton.icon(
        onPressed: (puntos.length > 2 &&
                !finalizado &&
                userIdActual == creadorId) // Verifica si el usuario es el creador
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
                        'finalizado': true, // Marca el proyecto como finalizado
                      })
                      .eq('id', widget.proyectoId);

                  setState(() => finalizado = true);

                  if (context.mounted) {
                    _mostrarModalFinalizar(context);
                  }
                } catch (e) {
                  print('Error al finalizar el territorio: $e');
                }
              }
            : null, // Deshabilita el botón si no cumple las condiciones
        icon: const Icon(Icons.check_circle),
        label: const Text('Finalizar Escaneo'),
      ),
    );
  }

  Future<void> _showImagePickerDialog(StateSetter setStateDialog) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery(setStateDialog);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromCamera(setStateDialog);
                },
              ),
            ],
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa del Territorio')),
      body: Row(
        children: [
          if (mostrarBarraLateral)
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey[100],
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Coordenadas',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                    ),
                    Expanded(
                      child: puntos.isEmpty
                          ? const Center(child: Text('No hay puntos todavía'))
                          : ListView.builder(
                              itemCount: puntos.length,
                              itemBuilder: (context, index) {
                                final p = puntos[index];
                                return ListTile(
                                  title: Text(
                                    'Lat: ${p.latitude.toStringAsFixed(6)}',
                                  ),
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
            ),
          Expanded(
            flex: mostrarBarraLateral ? 3 : 1,
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) async {
                    mapController = controller;
                    await _cargarPuntosColaborativos();
                    _dibujarPoligono();
                  },
                  initialCameraPosition: CameraPosition(
                    target:
                        ubicacionActual ?? const LatLng(-0.22985, -78.52495),
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polygons: _poligonos,
                  markers: _marcadores,
                  polylines: _polilineas,
                  mapType: MapType.normal,
                ),
                if (!mostrarBarraLateral)
                  Positioned(
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
                  ),
                Positioned(
                  bottom: 80,
                  left: 20,
                  child: ElevatedButton.icon(
                    onPressed: cargandoUbicacion || finalizado
                        ? null
                        : _marcarUbicacionActual,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Marcar'),
                  ),
                ),
                _buildFinalizarButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalFinalizar(BuildContext context) {
    bool cargandoImagen = false; // Variable para controlar el estado de carga
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
                        ? const Center(
                            child: CircularProgressIndicator(), // Indicador de carga
                          )
                        : (_imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'No se ha seleccionado ninguna imagen',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      setStateDialog(() {
                        cargandoImagen = true; // Activa el estado de carga
                      });

                      await _showImagePickerDialog(setStateDialog);

                      setStateDialog(() {
                        cargandoImagen = false; // Desactiva el estado de carga
                      });
                    },
                    child: const Text('Seleccionar Imagen'),
                  ),
                ],
              ),
              actions: [
                if (_imageBytes != null)
                  ElevatedButton(
                    onPressed: () async {
                      final imageUrl = await _uploadImage();
                      if (imageUrl != null) {
                        await Supabase.instance.client
                            .from('territories')
                            .update({'imagen_poligono': imageUrl})
                            .eq('id', widget.proyectoId);

                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                            (route) => false,
                          );
                        }
                      }
                    },
                    child: const Text('Subir Imagen'),
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

  Future<void> _marcarUbicacionActual() async {
    if (ubicacionActual == null || finalizado) return;

    try {
      // Inserta la ubicación actual en la base de datos
      await Supabase.instance.client.from('puntos').insert({
        'usuario': userIdActual,
        'latitud': ubicacionActual!.latitude,
        'longitud': ubicacionActual!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'proyecto_id': widget.proyectoId,
      });

      // Agrega el nuevo punto a la lista de puntos
      setState(() {
        puntos.add(ubicacionActual!);
      });
      _dibujarPoligono();

      // Recarga los puntos colaborativos y actualiza el polígono
      await _cargarPuntosColaborativos();
    } catch (e) {
      print('Error al insertar punto: $e');
    }
  }
}
