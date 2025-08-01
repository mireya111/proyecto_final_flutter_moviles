import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'crear_proyecto_page.dart';
import 'mapa_page.dart';
import 'sesion.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<List<dynamic>> _obtenerMisProyectos() async {
    if (userIdActual == null) return <dynamic>[];
    return await Supabase.instance.client
        .from('territories')
        .select()
        .eq('creador', userIdActual!)
        .order('created_at', ascending: false);
  }

  Future<List<dynamic>> _obtenerInvitaciones() async {
    if (userIdActual == null) return <dynamic>[];
    return await Supabase.instance.client
        .from('territories')
        .select()
        .contains('participantes', [userIdActual])
        .neq('creador', userIdActual!)
        .neq('finalizado', true)
        .order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _obtenerUbicacionesUsuarios() async {
    final response = await Supabase.instance.client
        .from('locations')
        .select('id_user, users(username, id), latitude, longitude, status')
        .eq('status', true);

    final data = response as List<dynamic>? ?? [];
    return data.map<Map<String, dynamic>>((item) {
      return {
        'id_user': item['id_user'],
        'username': item['users']?['username'] ?? '',
        'user_id': item['users']?['id'] ?? '',
        'latitude': item['latitude'],
        'longitude': item['longitude'],
        'status': item['status'],
      };
    }).toList();
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return 'Fecha no disponible';
    try {
      final DateTime fechaParseada = DateTime.parse(fecha);
      return DateFormat('dd/MM/yyyy').format(fechaParseada);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Territorios Topográficos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mis proyectos'),
              Tab(text: 'Invitaciones'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                try {
                  // 1. Detener primero el servicio en segundo plano
                  await FlutterForegroundTask.stopService();
                  print('Servicio en segundo plano detenido');

                  // 2. Actualizar el estado en la tabla locations
                  if (userIdActual != null) {
                    await Supabase.instance.client
                        .from('locations')
                        .update({'status': false})
                        .eq('id_user', userIdActual!);
                    print('Estado actualizado en la tabla locations');
                  }
                  // 3. Cerrar sesión en Supabase
                  await Supabase.instance.client.auth.signOut();
                  print('Sesión cerrada en Supabase');

                  // 4. Limpiar variables de sesión (si existen)
                  userIdActual = null;
                  userEmailActual = null;

                  // 5. Navegar a la pantalla de inicio de sesión
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                } catch (e) {                
                  // Mostrar mensaje de error al usuario si es necesario
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Error al cerrar sesión. Intente nuevamente.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Página "Mis proyectos"
            _buildMisProyectos(),
            // Página "Invitaciones"
            _buildInvitaciones(),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'usuariosMapa',
              onPressed: () async {
                final usuarios = await _obtenerUbicacionesUsuarios();
                if (context.mounted) {
                  Navigator.pushNamed(
                    context,
                    '/usuarios_mapa',
                    arguments: usuarios,
                  );
                }
              },
              child: const Icon(Icons.group),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: 'crearProyecto',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrearProyectoPage()),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMisProyectos() {
    return FutureBuilder<List<dynamic>>(
      future: _obtenerMisProyectos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final territorios = snapshot.data!;
        if (territorios.isEmpty) {
          return const Center(child: Text('No tienes proyectos aún'));
        }

        // Dividir los proyectos en "en proceso" y "finalizados"
        final proyectosEnProceso = territorios
            .where((t) => t['finalizado'] != true)
            .toList();
        final proyectosFinalizados = territorios
            .where((t) => t['finalizado'] == true)
            .toList();

        return ListView(
          children: [
            // Sección de proyectos en proceso
            if (proyectosEnProceso.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Proyectos en proceso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...proyectosEnProceso.map(
                (territorio) => _buildProyectoCard(
                  territorio,
                  esFinalizado: false,
                  context: context,
                ),
              ),
            ],

            // Sección de proyectos finalizados
            if (proyectosFinalizados.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Proyectos finalizados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...proyectosFinalizados.map(
                (territorio) => _buildProyectoCard(
                  territorio,
                  esFinalizado: true,
                  context: context,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProyectoCard(
    Map<String, dynamic> territorio, {
    required bool esFinalizado,
    required BuildContext context,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        title: Text(territorio['nombre'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propiedades: ${territorio['propieties'] ?? ''}'),
            Text(
              'Colaborativo: ${territorio['colaborativo'] == true ? 'Sí' : 'No'}',
            ),
            Text(
              'Área: ${territorio['area'] != null ? '${(territorio['area'] as num).toStringAsFixed(2)} m²' : 'No calculada'}',
            ),
            Text(
              'Fecha creación: ${_formatearFecha(territorio['created_at'])}',
            ),
            if (territorio['imagen_poligono'] != null &&
                (territorio['imagen_poligono'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    territorio['imagen_poligono'],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('No se pudo cargar la imagen'),
                  ),
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: esFinalizado
            ? const Icon(Icons.lock, color: Colors.grey) // Icono de bloqueo
            : IconButton(
                icon: const Icon(Icons.map),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapaPage(
                        proyectoId: territorio['id'], // ID del proyecto
                        colaborativo: territorio['colaborativo'] ?? false,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildInvitaciones() {
    return FutureBuilder<List<dynamic>>(
      future: _obtenerInvitaciones(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final territorios = snapshot.data!;
        if (territorios.isEmpty) {
          return const Center(child: Text('No tienes invitaciones aún'));
        }
        return ListView.builder(
          itemCount: territorios.length,
          itemBuilder: (context, index) {
            final territorio = territorios[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                title: Text(territorio['nombre'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Propiedades: ${territorio['propieties'] ?? ''}'),
                    Text(
                      'Colaborativo: ${territorio['colaborativo'] == true ? 'Sí' : 'No'}',
                    ),
                    Text(
                      'Área: ${territorio['area'] != null ? '${(territorio['area'] as num).toStringAsFixed(2)} m²' : 'No calculada'}',
                    ),
                    Text(
                      'Fecha creación: ${_formatearFecha(territorio['created_at'])}',
                    ),
                    if (territorio['imagen_poligono'] != null &&
                        (territorio['imagen_poligono'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            territorio['imagen_poligono'],
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Text('No se pudo cargar la imagen'),
                          ),
                        ),
                      ),
                  ],
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.map),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapaPage(
                          proyectoId: territorio['id'], // ID del proyecto
                          colaborativo:
                              territorio['colaborativo'] ??
                              false, // Si es colaborativo
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
