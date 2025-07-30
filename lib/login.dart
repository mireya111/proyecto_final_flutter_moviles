import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'sesion.dart';
import 'location_task_handler.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  Location location = Location();

  @override
  void initState() {
    super.initState();
    _initializeForegroundTask();
  }

  void _initializeForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_channel',
        channelName: 'Location Tracking',
        channelDescription: 'Tracking your location in background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(5000),
      ),
    );
  }

  Future<void> _openBatterySettings() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 23) {
      // Verificar si la optimización de batería está deshabilitada
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      );
      final result = await intent.canResolveActivity();
      if (result == null || !result) {
        return;
      }

      // Abrir la configuración de batería si es necesario
      const openSettingsIntent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await openSettingsIntent.launch();
    }
  }

  Future<void> _startLocationTracking() async {
    // Solicitar permisos de ubicación
    if (await Permission.location.request().isGranted) {
      if (await Permission.locationAlways.request().isGranted) {
        // Verificar si el servicio de ubicación está habilitado
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          serviceEnabled = await location.requestService();
          if (!serviceEnabled) return;
        }

        // Iniciar servicio en segundo plano
        await FlutterForegroundTask.startService(
          notificationTitle: 'Rastreo de ubicación activo',
          notificationText: 'La aplicación está rastreando tu ubicación.',
          callback: startCallback,
        );

        // Configurar actualizaciones de ubicación
        location.changeSettings(
          interval: 5000, // Cada 5 segundos
          distanceFilter: 0,
          accuracy: LocationAccuracy.high,
        );

        location.onLocationChanged.listen((LocationData currentLocation) async {
          if (userIdActual != null) {
            try {
              await Supabase.instance.client.from('locations').upsert({
                'id_user': userIdActual,
                'latitude': currentLocation.latitude,
                'longitude': currentLocation.longitude,
                'timestamp': DateTime.now().toIso8601String(),
                'status': true,
              }, onConflict: 'id_user');
            } catch (e) {
              print('Error al enviar ubicación: $e');
            }
          }
        });
      }
    }
  }

  static void startCallback() {
    FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, email')
          .eq('email', email)
          .eq('password', password)
          .maybeSingle();

      final userId = response != null ? response['id'] : null;
      final userEmail = response != null ? response['email'] : null;

      if (userId != null) {
        userIdActual = userId;
        userEmailActual = userEmail;
        await _startLocationTracking();
        await _openBatterySettings();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _error = 'Credenciales incorrectas';
        });
      }
    } catch (e) {
      print('Error al iniciar sesión: $e');
      setState(() {
        _error = 'Error al iniciar sesión';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio de Sesión'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono de topografía
            const Icon(
              Icons.terrain, // Ícono que simula la topografía
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Territorios Topográficos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 40),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Ingrese su email' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) =>
                        value!.isEmpty ? 'Ingrese su contraseña' : null,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              _login();
                            }
                          },
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar sesión'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
