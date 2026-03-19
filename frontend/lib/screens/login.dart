import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart'; 
import './admin_home.dart'; 
import './customer_shop_screen.dart'; 
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget { 
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> login() async {
    // Validar campos vacíos antes de intentar la conexión
    if (_userController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/users/login/'),
        body: {
          'username': _userController.text.trim(),
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Extraemos los datos del mapa 'user' que envía tu Django
        final String rol = (data['user']['rol'] ?? "").toString().toUpperCase(); // Convertimos a MAYÚSCULAS para evitar errores
        final String username = data['user']['username'] ?? "Usuario";
        final String? direccion = data['user']['direccion'];
        final String? telefono = data['user']['telefono'];

        // Guardar datos localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('user_rol', rol);
        if (direccion != null) await prefs.setString('user_direccion', direccion);
        if (telefono != null) await prefs.setString('user_telefono', telefono);

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bienvenido, $username"), 
            backgroundColor: AppColors.verdeBosque,
            duration: const Duration(seconds: 2),
          ),
        );

        // --- LÓGICA DE DIRECCIONAMIENTO CORREGIDA ---
        // Verificamos el rol normalizado a mayúsculas
        if (rol == 'ADMIN' || rol == 'STAFF') {
          debugPrint("Accediendo como Administrador: $rol");
          Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const AdminInventoryHub())
          );
        } else {
          debugPrint("Accediendo como Cliente: $rol");
          Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const CustomerShopScreen())
          );
        }
        
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Usuario o contraseña incorrectos"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error de Login: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de conexión con el servidor")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tu widget build se mantiene igual...
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.agriculture_outlined, size: 60, color: AppColors.verdeBosque),
              const SizedBox(height: 20),
              const Text("Iniciar Sesión", style: TextStyle(fontSize: 28, color: AppColors.tituloNegro, fontWeight: FontWeight.w500)),
              const SizedBox(height: 40),
              _buildTextField(hint: "Nombre de usuario", obscure: false, controller: _userController),
              const SizedBox(height: 20),
              _buildTextField(hint: "Contraseña", obscure: true, controller: _passwordController),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeBosque,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ENTRAR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, required bool obscure, required TextEditingController controller}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.verdeBorde, width: 2)),
      ),
    );
  }
}