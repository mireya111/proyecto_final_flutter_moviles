import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'home_page.dart';
import 'crear_proyecto_page.dart';
import 'mapa_page.dart';
import 'usuarios_mapa.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga el archivo .env
  await dotenv.load(fileName: "assets/.env");

  // Inicializa Supabase con las credenciales del archivo .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territorios Topográficos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
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
        if (settings.name == '/usuarios_mapa') {
          final usuarios = settings.arguments as List<Map<String, dynamic>>;
          return MaterialPageRoute(
            builder: (_) => UsuariosMapaPage(usuarios: usuarios),
          );
        }
        return null;
      },
    );
  }
}
