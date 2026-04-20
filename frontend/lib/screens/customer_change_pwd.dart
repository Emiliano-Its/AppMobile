import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../api_config.dart';

class CustomerChangePwdScreen extends StatefulWidget {
  const CustomerChangePwdScreen({super.key});

  @override
  State<CustomerChangePwdScreen> createState() => _CustomerChangePwdScreenState();
}

class _CustomerChangePwdScreenState extends State<CustomerChangePwdScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar("Completa todos los campos", Colors.orange);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar("Las nuevas contraseñas no coinciden", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.post(
        Uri.parse(ApiConfig.changePassword),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
          'confirm_password': _confirmPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // --- FIX: El servidor devuelve un token nuevo tras el cambio.
        // Lo guardamos para que todas las pantallas siguientes no reciban 401.
        final String newToken = data['token'] ?? '';
        if (newToken.isNotEmpty) {
          await prefs.setString('access_token', newToken);
        }

        _showSnackBar("¡Contraseña actualizada!", AppColors.verdeBosque);
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () => Navigator.pop(context));
        }
      } else if (response.statusCode == 401) {
        _showSnackBar("Sesión no autorizada. Re-inicia sesión.", Colors.red);
      } else {
        // Django puede devolver el error como string simple, lista o mapa anidado.
        // {"error": "..."} | {"new_password": ["muy corta", "muy común"]}
        try {
          final error = jsonDecode(response.body);
          String msg = "Error desconocido";
          if (error is Map) {
            if (error.containsKey('error')) {
              msg = error['error'].toString();
            } else {
              final parts = <String>[];
              error.forEach((key, value) {
                if (value is List) {
                  parts.addAll(value.map((e) => e.toString()));
                } else {
                  parts.add(value.toString());
                }
              });
              msg = parts.join('\n');
            }
          }
          _showSnackBar(msg, Colors.red);
        } catch (_) {
          _showSnackBar("Error al procesar la respuesta.", Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Seguridad", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Icon(Icons.lock_reset_rounded, size: 80, color: AppColors.verdeBosque),
            const SizedBox(height: 30),
            _buildField("Contraseña Actual", _oldPasswordController),
            const SizedBox(height: 15),
            _buildField("Nueva Contraseña", _newPasswordController),
            const SizedBox(height: 15),
            _buildField("Confirmar Nueva", _confirmPasswordController),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator(color: AppColors.verdeBosque)
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verdeBosque,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text(
                        "ACTUALIZAR",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            const Icon(Icons.vpn_key_outlined, color: AppColors.verdeBosque),
        suffixIcon: IconButton(
          icon:
              Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}