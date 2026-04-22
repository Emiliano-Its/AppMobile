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

  bool _isGeocodingAddress = false;

  // Convierte coordenadas a dirección legible usando Nominatim (OSM, gratuito)
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocodingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json&accept-language=es',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TostaderiaApp/1.0 (contacto@tostaderia.com)',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String direccion = data['display_name'] ?? '';
        if (direccion.isNotEmpty && mounted) {
          setState(() => _direccionController.text = direccion);
        }
      }
    } catch (e) {
      debugPrint("Error geocodificando: $e");
    } finally {
      if (mounted) setState(() => _isGeocodingAddress = false);
    }
  }

  // Prefija la clave con el username para aislar datos entre cuentas
  String _key(String k) => '${_userName}__$k';

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('username') ?? "Usuario";
      _userEmail = prefs.getString('email') ?? "";
      _direccionController.text = prefs.getString(_key('default_address')) ?? '';
      _telefonoController.text  = prefs.getString(_key('default_phone')) ?? '';

      double? lat = prefs.getDouble(_key('last_lat'));
      double? lng = prefs.getDouble(_key('last_lng'));
      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
      }
    });

    if (_direccionController.text.isEmpty && _telefonoController.text.isEmpty) {
      await _loadProfileFromServer();
    }
  }

  Future<void> _loadProfileFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;

      final response = await http.get(
        Uri.parse(ApiConfig.userProfile),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String dir = data['direccion'] ?? '';
        final String tel = data['telefono'] ?? '';
        final double? lat = data['latitud'] != null ? double.tryParse(data['latitud'].toString()) : null;
        final double? lng = data['longitud'] != null ? double.tryParse(data['longitud'].toString()) : null;

        if (mounted) {
          setState(() {
            if (dir.isNotEmpty) _direccionController.text = dir;
            if (tel.isNotEmpty) _telefonoController.text = tel;
            if (lat != null && lng != null) _selectedLocation = LatLng(lat, lng);
          });
          await prefs.setString(_key('default_address'), dir);
          await prefs.setString(_key('default_phone'), tel);
          if (lat != null) await prefs.setDouble(_key('last_lat'), lat);
          if (lng != null) await prefs.setDouble(_key('last_lng'), lng);
        }
      }
    } catch (e) {
      debugPrint("Error cargando perfil del servidor: $e");
    }
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final response = await http.post(
      Uri.parse(ApiConfig.userProfile),
      headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      body: jsonEncode({
        'default_address': _direccionController.text,
        'default_phone':   _telefonoController.text,
        'last_lat':        _selectedLocation.latitude,
        'last_lng':        _selectedLocation.longitude,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      await prefs.setString(_key('default_address'), _direccionController.text);
      await prefs.setString(_key('default_phone'),   _telefonoController.text);
      await prefs.setDouble(_key('last_lat'),  _selectedLocation.latitude);
      await prefs.setDouble(_key('last_lng'),  _selectedLocation.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado")),
        );
      }
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
                            _reverseGeocode(point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.tostaderia.app',
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
                  
                  const SizedBox(height: 8),

                  // Indicador cuando está obteniendo la dirección del pin
                  if (_isGeocodingAddress)
                    Row(
                      children: [
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.verdeBosque,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Obteniendo dirección...",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  else
                    Text(
                      "Toca el mapa para marcar tu ubicación",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),

                  const SizedBox(height: 12),

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

                  ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.red),
                    title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      // Solo borramos las claves de sesión, el resto se queda
                      await prefs.remove('username');
                      await prefs.remove('user_rol');
                      await prefs.remove('access_token');
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