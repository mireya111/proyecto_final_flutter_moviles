import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        .order('created_at', ascending: false);
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
      length: 2, // Número de pestañas
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
              icon: const Icon(Icons.refresh), // Botón de recargar
              onPressed: () {
                // Recargar la página
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (userIdActual != null) {
                  await Supabase.instance.client
                      .from('locations')
                      .update({'status': false})
                      .eq('id_user', userIdActual!);
                }
                await Supabase.instance.client.auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
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
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearProyectoPage()),
          ),
          child: const Icon(Icons.add),
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
                    Text('Área: ${territorio['area'] ?? 'No calculada'}'),
                    Text(
                      'Fecha creación: ${_formatearFecha(territorio['created_at'])}',
                    ),
                    if (territorio['imagen_polig'] != null &&
                        (territorio['imagen_polig'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            territorio['imagen_polig'],
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
              ),
            );
          },
        );
      },
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
                    Text('Área: ${territorio['area'] ?? 'No calculada'}'),
                    Text(
                      'Fecha creación: ${_formatearFecha(territorio['created_at'])}',
                    ),
                    if (territorio['imagen_polig'] != null &&
                        (territorio['imagen_polig'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            territorio['imagen_polig'],
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
