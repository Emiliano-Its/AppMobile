import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import '../main.dart';
import './login.dart';
import './customer_change_pwd.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  String _userName = "Usuario";
  String _userEmail = ""; // Añadido para mostrar más info si gustas
  
  // Coordenadas iniciales (Monterrey)
  LatLng _selectedLocation = const LatLng(25.6866, -100.3161); 
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Cargamos el nombre y datos básicos guardados en el login
      _userName = prefs.getString('username') ?? "Usuario";
      _userEmail = prefs.getString('email') ?? ""; 
      _direccionController.text = prefs.getString('default_address') ?? '';
      _telefonoController.text = prefs.getString('default_phone') ?? '';
      
      double? lat = prefs.getDouble('last_lat');
      double? lng = prefs.getDouble('last_lng');
      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
      }
    });
  }

Future<void> _saveProfileData() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token') ?? ''; // Recuperas el token del login

  final response = await http.post(
    Uri.parse(ApiConfig.userProfile),
    headers: {
      ...ApiConfig.headers,
      'Authorization': 'Token $token', // ESTO QUITA EL 401
    },
    body: jsonEncode({
      'default_address': _direccionController.text,
      'default_phone': _telefonoController.text,
      'last_lat': _selectedLocation.latitude,
      'last_lng': _selectedLocation.longitude,
    }),
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    // Si el server responde bien, guardas en local
    await prefs.setString('default_address', _direccionController.text);
    await prefs.setString('default_phone', _telefonoController.text);
    await prefs.setDouble('last_lat', _selectedLocation.latitude);
    await prefs.setDouble('last_lng', _selectedLocation.longitude);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Perfil actualizado")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Mi Cuenta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header del perfil
            Container(
              color: AppColors.verdeBosque,
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 10),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 60, color: AppColors.verdeBosque),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _userName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (_userEmail.isNotEmpty)
                    Text(_userEmail, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSectionTitle("DATOS DE ENVÍO"),
                  _buildTextField("Dirección", _direccionController, Icons.location_on),
                  _buildTextField("Teléfono", _telefonoController, Icons.phone),
                  
                  const SizedBox(height: 10),
                  
                  // Mapa para ubicación
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 14.0,
                          onTap: (tapPosition, point) {
                            setState(() => _selectedLocation = point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation,
                                width: 80,
                                height: 80,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfileData,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verdeBosque,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionTitle("SEGURIDAD Y SESIÓN"),
                  
                  // BOTÓN CAMBIAR CONTRASEÑA
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.verdeBosque),
                    title: const Text("Cambiar Contraseña"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CustomerChangePwdScreen()),
                      );
                    },
                  ),
                  
                  const Divider(),

                  // BOTÓN CERRAR SESIÓN
                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear(); // Limpia token y datos
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context, 
                          MaterialPageRoute(builder: (context) => const LoginScreen()), 
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verdeBosque, letterSpacing: 1.2)
        )
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.verdeBosque),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}