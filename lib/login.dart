import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sesion.dart'; // importa tu variable de sesión

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
          .eq('password', password) // En producción, usa hash
          .maybeSingle();

      final userId = response != null ? response['id'] : null;
      final userEmail = response != null ? response['email'] : null;

      if (userId != null) {
        // ✅ Guardar el usuario logueado en variables globales
        userIdActual = userId;
        userEmailActual = userEmail;

        // Actualizar status en locations
        await Supabase.instance.client
            .from('locations')
            .update({'status': true})
            .eq('usuario', userId);

        // Redirigir al home
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
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
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su contraseña' : null,
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _login();
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final result =
                      await Navigator.pushNamed(context, '/registro');
                  if (result == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('¡Registro exitoso! Ahora puedes iniciar sesión.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('¿No tienes cuenta? Regístrate aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
