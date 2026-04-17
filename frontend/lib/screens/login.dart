import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Importaciones de configuración y estilos
import '../main.dart'; 
import '../api_config.dart'; 

// --- IMPORTACIONES DE TUS PANTALLAS ---
import 'registro_user.dart'; 
import 'main_wrapper.dart';

class LoginScreen extends StatefulWidget { 
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true; 
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> login() async {
    // 1. Validación básica
    if (_userController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar("Por favor, llena todos los campos", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Petición al servidor
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: ApiConfig.headers,
        body: json.encode({
          'username': _userController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // 3. Extraer datos (maneja si vienen en data['user'] o directo en data)
        final dynamic userData = data['user'] ?? data;
        final String rol = (userData['rol'] ?? "CLIENTE").toString().toUpperCase().trim(); 
        final String username = userData['username'] ?? "Usuario";
        
        // 4. Guardar sesión
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('user_rol', rol);

        if (!mounted) return;
        
        _showSnackBar("¡Bienvenido, $username!", AppColors.verdeBosque);

        // 5. NAVEGACIÓN AL WRAPPER (Él decide qué mostrar según el rol)
        Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => const MainWrapper()),
            (route) => false,
        );
        
      } else {
        _showSnackBar("Usuario o contraseña incorrectos", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error al conectar con el servidor", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bakery_dining_rounded, size: 90, color: AppColors.verdeBosque),
              const SizedBox(height: 15),
              const Text(
                "Tostadería el Molino", 
                style: TextStyle(fontSize: 26, color: AppColors.verdeBosque, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              
              _buildTextField(
                hint: "Nombre de usuario", 
                icon: Icons.person_outline, 
                controller: _userController
              ),
              const SizedBox(height: 20),
              _buildTextField(
                hint: "Contraseña", 
                icon: Icons.lock_outline, 
                isPassword: true, 
                controller: _passwordController
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeBosque,
                    shape: const StadiumBorder(),
                    elevation: 2,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        width: 25, 
                        height: 25, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      )
                    : const Text(
                        "INICIAR SESIÓN", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                ),
              ),
              
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("¿No tienes cuenta? ", style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterUserScreen()),
                      );
                    },
                    child: const Text(
                      "Regístrate aquí", 
                      style: TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint, 
    required IconData icon, 
    bool isPassword = false, 
    required TextEditingController controller
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.verdeBosque),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: const BorderSide(color: AppColors.verdeBosque, width: 2)
        ),
      ),
    );
  }
}