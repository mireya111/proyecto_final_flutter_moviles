import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mapa_page.dart';
import 'package:geolocator/geolocator.dart';
import 'sesion.dart';

class CrearProyectoPage extends StatefulWidget {
  const CrearProyectoPage({super.key});

  @override
  State<CrearProyectoPage> createState() => _CrearProyectoPageState();
}

class _CrearProyectoPageState extends State<CrearProyectoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController descripcionCtrl = TextEditingController();
  bool colaborativo = false;
  List<dynamic> usuariosActivos = [];
  List<dynamic> seleccionados = [];

  void _iniciarActualizacionUbicacion() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    ).listen((Position pos) async {
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
          print('Error actualizando ubicación: $e');
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _iniciarActualizacionUbicacion();
  }


  Future<void> _cargarUsuariosActivos() async {
    // Traer usuarios activos con join para obtener el username
    final usuarios = await Supabase.instance.client
        .from('locations')
        .select('id_user, users(username)')
        .eq('status', true);
    setState(() {
      usuariosActivos = usuarios;
      // Eliminar seleccionados que ya no están activos
      seleccionados = seleccionados.where((s) => usuarios.any((u) => u['id_user'] == s)).toList();
    });
  }

  Future<void> _crearProyecto() async {
    if (_formKey.currentState!.validate()) {
      // Participantes: solo los ids de los colaboradores seleccionados (sin duplicados), el creador NO debe estar si no es colaborativo
      List<dynamic> participantes = [];
      if (colaborativo) {
        participantes = List.from(seleccionados);
        // Asegurarse que el creador esté incluido si no lo está
        if (!participantes.contains(userIdActual)) {
          participantes.add(userIdActual);
        }
      } else {
        // Si no es colaborativo, solo el usuario logueado participa
        participantes = [userIdActual];
      }

      try {
        final response = await Supabase.instance.client.from('proyectos').insert({
          'nombre': nombreCtrl.text,
          'descripcion': descripcionCtrl.text,
          'colaborativo': colaborativo,
          'creador': userIdActual,
          'participantes': participantes,
        }).select().single();

        final idProyecto = response['id'];
        if (!mounted) return;

        // Abrir mapa para los usuarios seleccionados (solo en colaborativo)
        if (colaborativo) {
          for (var userId in seleccionados) {
            if (userId != userIdActual) {
              // Aquí podrías implementar una lógica para enviar notificaciones o abrir el mapa automáticamente
              print('Abrir mapa para usuario: $userId');
            }
          }
        }

        // Navegar al mapa para el creador del proyecto
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MapaPage(
              proyectoId: idProyecto,
              colaborativo: colaborativo,
            ),
          ),
        );
      } catch (e) {
        // Manejo de errores
        print('Error al crear el proyecto: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear el proyecto')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del proyecto'),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              SwitchListTile(
                title: const Text('¿Colaborativo?'),
                value: colaborativo,
                onChanged: (val) async {
                  if (!val) {
                    setState(() {
                      colaborativo = false;
                      usuariosActivos = [];
                      seleccionados = [];
                    });
                  } else {
                    setState(() { colaborativo = true; });
                    await _cargarUsuariosActivos();
                  }
                },
              ),
              if (colaborativo)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecciona usuarios activos:'),
                    if (usuariosActivos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No hay usuarios para colaborar', style: TextStyle(color: Colors.grey)),
                      )
                    else ...usuariosActivos.map((u) => CheckboxListTile(
                          title: Text(
                            (u['users'] != null && u['users']['username'] != null)
                              ? u['users']['username']
                              : u['id_user'].toString()
                          ),
                          value: seleccionados.contains(u['id_user']),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                if (!seleccionados.contains(u['id_user'])) {
                                  seleccionados.add(u['id_user']);
                                }
                              } else {
                                seleccionados.remove(u['id_user']);
                              }
                            });
                          },
                        )),
                  ],
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _crearProyecto,
                child: const Text('Crear y abrir mapa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}