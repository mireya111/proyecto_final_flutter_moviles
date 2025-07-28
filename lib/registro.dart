import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<bool> _isUnique(String field, String value) async {
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq(field, value)
        .maybeSingle();
    return response == null;
  }

  bool _isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=(?:.*\d){3})(?=(?:.*[^A-Za-z0-9]){3}).{6,10}$');
    return regex.hasMatch(password);
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!await _isUnique('username', username)) {
      setState(() {
        _error = 'El username ya está en uso';
        _loading = false;
      });
      return;
    }
    if (!await _isUnique('email', email)) {
      setState(() {
        _error = 'El email ya está en uso';
        _loading = false;
      });
      return;
    }

    try {
      // 1. Insertar en users
      await Supabase.instance.client
          .from('users')
          .insert({
            'username': username,
            'email': email,
            'password': password, // En producción, nunca guardes contraseñas en texto plano.
            'created_at': DateTime.now().toIso8601String(),
          });

      // 2. Buscar el usuario recién creado para obtener su id
      final userRecord = await Supabase.instance.client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (userRecord != null && userRecord['id'] != null) {
        // 3. Obtener ubicación actual y registrar en locations
        try {
          final pos = await Geolocator.getCurrentPosition();
          await Supabase.instance.client.from('locations').insert({
            'id_user': userRecord['id'],
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'timestamp': DateTime.now().toIso8601String(),
            'status': false,
          });
        } catch (e) {
          // Si falla la ubicación, igual continúa
        }
        Navigator.pop(context); // Vuelve al login
      } else {
        setState(() {
          _error = 'Error al registrar (no se pudo obtener el id)';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al registrar';
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
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su username' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese su contraseña';
                  }
                  if (!_isPasswordValid(value)) {
                    return '6-10 caracteres, mínimo 1 letra, 3 números y 3 caracteres especiales';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _register();
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Registrarse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}