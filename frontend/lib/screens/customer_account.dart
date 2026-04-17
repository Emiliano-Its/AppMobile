import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart'; // Librería gratuita
import 'package:latlong2/latlong.dart'; // Para manejo de coordenadas
import '../main.dart';
import './login.dart';
import './customer_pedidos.dart'; // Importación para la pantalla de pedidos

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  
  // Coordenadas iniciales (Monterrey como ejemplo, cámbialas a tu zona)
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
      _direccionController.text = prefs.getString('default_address') ?? '';
      _telefonoController.text = prefs.getString('default_phone') ?? '';
      
      // Intentar cargar coordenadas guardadas
      double? lat = prefs.getDouble('last_lat');
      double? lng = prefs.getDouble('last_lng');
      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_address', _direccionController.text);
    await prefs.setString('default_phone', _telefonoController.text);
    // Guardamos coordenadas para persistencia
    await prefs.setDouble('last_lat', _selectedLocation.latitude);
    await prefs.setDouble('last_lng', _selectedLocation.longitude);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Datos actualizados para tus envíos")),
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.verdeBosque,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle("Ubicación de Envío (Toca el mapa)"),
            
            // MAPA GRATUITO (OPEN STREET MAP)
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.verdeBosque, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                        // Actualizamos el texto con las coordenadas
                        _direccionController.text = "Ubicación en mapa (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
                      });
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
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            _buildTextField("Detalles de dirección (Calle, No, Colonia)", _direccionController, Icons.home),
            _buildTextField("Teléfono de contacto", _telefonoController, Icons.phone),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeBosque,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("GUARDAR DATOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),

            const Divider(height: 40),

            // SECCIÓN DE OPCIONES DE CUENTA Y PEDIDOS
            _buildSectionTitle("Gestión de Cuenta"),
            
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined, color: AppColors.verdeBosque),
                    title: const Text("Mis Pedidos"),
                    subtitle: const Text("Ver el historial y estado de mis compras"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const CustomerPedidos())
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: AppColors.verdeBosque),
                    title: const Text("Cambiar Contraseña"),
                    onTap: () { /* Lógica de pass */ },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context, 
                          MaterialPageRoute(builder: (context) => const LoginScreen()), 
                          (route) => false
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
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verdeBosque))
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
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}