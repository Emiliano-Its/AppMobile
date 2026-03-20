import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart'; // Importación vital
import './admin_home.dart'; 
import './customer_shop_screen.dart'; 

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
    if (_userController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena todos los campos"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- CAMBIO: Usamos ApiConfig.login ---
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        // Nota: Si tu backend espera JSON, usa jsonEncode y ApiConfig.headers
        // Si espera Form-Data (como estaba originalmente), deja el body así:
        body: {
          'username': _userController.text.trim(),
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        final String rol = (data['user']['rol'] ?? "").toString().toUpperCase(); 
        final String username = data['user']['username'] ?? "Usuario";
        final String? direccion = data['user']['direccion'];
        final String? telefono = data['user']['telefono'];

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

        if (rol == 'ADMIN' || rol == 'STAFF') {
          Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const AdminInventoryHub())
          );
        } else {
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
      debugPrint("Error de Login en Debian: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo conectar con el servidor de la tostadería")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              const Icon(Icons.bakery_dining_rounded, size: 80, color: AppColors.verdeBosque),
              const SizedBox(height: 20),
              const Text("Tostadería el Molino", 
                style: TextStyle(fontSize: 24, color: AppColors.verdeBosque, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Iniciar Sesión", 
                style: TextStyle(fontSize: 18, color: AppColors.tituloNegro, fontWeight: FontWeight.w400)),
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
                    ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text("ENTRAR", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.verdeBosque, width: 2)),
      ),
    );
  }
}