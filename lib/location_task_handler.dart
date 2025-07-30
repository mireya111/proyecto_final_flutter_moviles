import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sesion.dart';

class LocationTaskHandler extends TaskHandler {
  final Location _location = Location();
  bool _isTracking = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    _isTracking = true;

    // Configuración de ubicación
    await _location.changeSettings(
      interval: 5000, // Cada 5 segundos
      distanceFilter: 0,
      accuracy: LocationAccuracy.high,
    );

    // Escuchar cambios de ubicación
    _location.onLocationChanged.listen((LocationData currentLocation) async {
      if (userIdActual != null && _isTracking) {
        try {
          await Supabase.instance.client.from('locations').upsert({
            'id_user': userIdActual,
            'latitude': currentLocation.latitude,
            'longitude': currentLocation.longitude,
            'timestamp': DateTime.now().toIso8601String(),
            'status': true,
          }, onConflict: 'id_user');
        } catch (e) {
          print('Error en background: $e');
        }
      }
    });
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // Puedes enviar datos al aislado principal si es necesario
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isRepeatEvent) async {
    _isTracking = false;
    await _location.changeSettings(interval: 0);
    await _location.enableBackgroundMode(enable: false);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Lógica para eventos repetitivos si es necesario
  }
}
