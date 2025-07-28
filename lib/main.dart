import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';
import 'registro.dart';
import 'home_page.dart';
import 'crear_proyecto_page.dart';
import 'mapa_page.dart';
import 'ver_proyecto_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sodlregonixbebwnvdxf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZGxyZWdvbml4YmVid252ZHhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTcyNTgsImV4cCI6MjA2Mzg3MzI1OH0.eyan4TXu8A1vo5YkedqofqvgC_NvmEkkgbBIXHGndak',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topografía App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/registro': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/crear': (context) => const CrearProyectoPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/mapa') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => MapaPage(
              proyectoId: args['proyectoId'],
              colaborativo: args['colaborativo'],
            ),
          );
        }
        if (settings.name == '/ver') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => VerProyectoPage(proyecto: args['proyecto']),
          );
        }
        return null;
      },
    );
  }
}
