import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crear_proyecto_page.dart';
import 'mapa_page.dart';
import 'ver_proyecto_page.dart';
import 'sesion.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos Topográficos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (userIdActual != null) {
                await Supabase.instance.client.from('locations').update({'status': false}).eq('usuario', userIdActual!);
              }
              await Supabase.instance.client.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: () async {
          if (userIdActual == null) return <dynamic>[];
          // Solo proyectos creados por el usuario logeado
          final proyectos = await Supabase.instance.client
              .from('proyectos')
              .select()
              .eq('creador', userIdActual!)
              .order('creado_en', ascending: false);
          return proyectos;
        }(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final proyectos = snapshot.data!;
          if (proyectos.isEmpty) {
            return const Center(child: Text('No hay proyectos aún'));
          }
          return ListView.builder(
            itemCount: proyectos.length,
            itemBuilder: (context, index) {
              final proyecto = proyectos[index];
              // Mostrar todos los datos relevantes del proyecto
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text(proyecto['nombre'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descripción: ${proyecto['descripcion'] ?? ''}'),
                      Text('Colaborativo: ${proyecto['colaborativo'] == true ? 'Sí' : 'No'}'),
                      Text('Área: ${proyecto['area'] ?? 'No calculada'}'),
                      Text('Fecha creación: ${proyecto['creado_en'] ?? ''}'),
                      Text('ID: ${proyecto['id'] ?? ''}'),
                      if (proyecto['imagen_poligono'] != null && (proyecto['imagen_poligono'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              proyecto['imagen_poligono'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Text('No se pudo cargar la imagen'),
                            ),
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VerProyectoPage(proyecto: proyecto),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CrearProyectoPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}