import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; 
import '../api_config.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- LÓGICA DE VALIDACIÓN (REGEXP) ---
  
  // Usuario: Solo letras, números y guiones bajos (evita espacios y símbolos raros)
  final RegExp _userRegExp = RegExp(r'^[a-zA-Z0-9_]{4,15}$');
  
  // Email: Formato estándar de correo
  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  // Contraseña: Mínimo 8 caracteres, una mayúscula, una minúscula, un número y un carácter especial
  final RegExp _passwordRegExp = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final Map<String, dynamic> userData = {
      "username": _usernameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "rol": "CLIENTE",
    };

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/users/"), 
        headers: ApiConfig.headers,
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        _showSnackBar("¡Registro exitoso! Bienvenido.", Colors.green);
        if (mounted) Navigator.pop(context);
      } else {
        final error = json.decode(response.body);
        _showSnackBar("Error: ${error.values.first}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión con el servidor", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Nueva Cuenta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, size: 70, color: AppColors.verdeBosque),
                const SizedBox(height: 20),
                
                // --- CAMPO USUARIO ---
                _buildTextField(
                  controller: _usernameController,
                  label: "Nombre de Usuario",
                  icon: Icons.alternate_email,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "El usuario es obligatorio";
                    if (!_userRegExp.hasMatch(val)) return "4-15 caracteres, sin espacios ni símbolos";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // --- CAMPO EMAIL ---
                _buildTextField(
                  controller: _emailController,
                  label: "Correo Electrónico",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "El correo es obligatorio";
                    if (!_emailRegExp.hasMatch(val)) return "Ingresa un correo válido";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // --- CAMPO CONTRASEÑA ---
                _buildTextField(
                  controller: _passwordController,
                  label: "Contraseña Segura",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "La contraseña es obligatoria";
                    if (!_passwordRegExp.hasMatch(val)) return "Usa Mayúscula, número y símbolo (@#\$)";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // --- CONFIRMAR CONTRASEÑA ---
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: "Confirmar Contraseña",
                  icon: Icons.security,
                  isPassword: true,
                  validator: (val) {
                    if (val != _passwordController.text) return "Las contraseñas no coinciden";
                    return null;
                  },
                ),
                
                const SizedBox(height: 35),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verdeBosque,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _isLoading ? null : _registerUser,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("CREAR CUENTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Valida mientras escriben
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.verdeBosque),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        errorMaxLines: 2, // Para que el mensaje de error de la contraseña se vea bien
      ),
    );
  }
}