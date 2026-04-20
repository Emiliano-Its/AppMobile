import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart'; // Librería gratuita
import 'package:latlong2/latlong.dart'; // Manejo de coordenadas
import '../main.dart'; 
import '../api_config.dart';

class CustomerCartScreen extends StatefulWidget {
  final Map<int, int> cart;
  final List<dynamic> allProducts;
  
  // Datos predeterminados que vienen de la cuenta o el perfil
  final String defaultAddress;
  final String defaultPhone;

  const CustomerCartScreen({
    super.key, 
    required this.cart, 
    required this.allProducts,
    this.defaultAddress = '',
    this.defaultPhone = '',
  });

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final List<String> _disponibilidades = [];
  bool _isSubmitting = false;

  // Variables para el mapa
  LatLng _selectedLocation = const LatLng(25.6866, -100.3161); // Ubicación inicial
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Sincronización de los campos de texto
    _direccionController.text = widget.defaultAddress;
    _telefonoController.text = widget.defaultPhone;
    _loadStoredLocation();
  }

  bool _isGeocodingAddress = false;

  // Carga las coordenadas guardadas previamente por el cliente
  Future<void> _loadStoredLocation() async {
    final prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('last_lat');
    double? lng = prefs.getDouble('last_lng');
    if (lat != null && lng != null) {
      setState(() {
        _selectedLocation = LatLng(lat, lng);
      });
    }
  }

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

  double _calculateTotal() {
    double total = 0;
    widget.cart.forEach((id, qty) {
      final product = widget.allProducts.firstWhere((p) => p['id'] == id);
      total += (double.parse(product['precio_venta'].toString()) * qty);
    });
    return total;
  }

  // Lógica para añadir fechas y horas de disponibilidad
  Future<void> _addDisponibilidad() async {
    final DateTimeRange? pickedDate = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: '¿Qué días puedes recibir el pedido?',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.verdeBosque,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          )
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return;

    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      helpText: '¿A partir de qué hora?',
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (startTime == null) return;

    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      helpText: '¿Hasta qué hora?',
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );

    if (endTime == null) return;

    setState(() {
      String fechaStr = pickedDate.start == pickedDate.end 
          ? "${pickedDate.start.day}/${pickedDate.start.month}"
          : "${pickedDate.start.day}/${pickedDate.start.month} al ${pickedDate.end.day}/${pickedDate.end.month}";
      
      String horaStr = "${startTime.format(context)} - ${endTime.format(context)}";
      
      _disponibilidades.add("$fechaStr ($horaStr)");
    });
  }

  // Proceso de confirmación y envío del pedido
  Future<void> _confirmOrder() async {
    if (widget.cart.isEmpty) {
      _showSnackBar("El carrito está vacío.");
      return;
    }
    if (_direccionController.text.trim().isEmpty) {
      _showSnackBar("Por favor, ingresa una dirección de envío");
      return;
    }
    if (_disponibilidades.isEmpty) {
      _showSnackBar("Por favor, añade al menos un horario de disponibilidad");
      return;
    }

    setState(() => _isSubmitting = true);
    final prefs = await SharedPreferences.getInstance();
    final String username = prefs.getString('username') ?? "Cliente App";
    final String token = prefs.getString('access_token') ?? '';

    final List<Map<String, dynamic>> details = [];
    widget.cart.forEach((id, qty) {
      final product = widget.allProducts.firstWhere((p) => p['id'] == id);
      details.add({
        "producto": id,
        "cantidad": qty,
        "precio_unitario": product['precio_venta']
      });
    });

    final orderData = {
      "tipo": "PEDIDO",
      "cliente_nombre": username,
      "direccion_envio": _direccionController.text.trim(),
      "telefono_contacto": _telefonoController.text.trim(),
      "fecha_entrega_estimada": _disponibilidades.join(" | "), 
      "total": _calculateTotal(),
      "estado": "PENDIENTE",
      "details": details
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sales),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showSuccessDialog();
      } else {
         _showSnackBar("Error al enviar el pedido: ${response.body}");
      }
    } catch (e) {
      _showSnackBar("Error de conexión con el servidor.");
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Finalizar Pedido", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. Resumen de Productos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCartList(),
            
            const Divider(height: 40),
            
            const Text("2. Ubicación de Entrega", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Mapa sincronizado
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.verdeBosque, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: 15.0,
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
                          width: 50, height: 50,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),

            // Indicador cuando está obteniendo la dirección
            if (_isGeocodingAddress)
              Row(
                children: [
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.verdeBosque),
                  ),
                  const SizedBox(width: 8),
                  Text("Obteniendo dirección...",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              )
            else
              Text("Toca el mapa para marcar tu ubicación",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),

            const SizedBox(height: 10),
            _buildInputContainer(
              controller: _direccionController,
              hint: "Calle, número, colonia...",
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 10),
            _buildInputContainer(
              controller: _telefonoController,
              hint: "Teléfono de contacto",
              icon: Icons.phone,
              isPhone: true,
            ),
            
            const SizedBox(height: 30),
            
            Row(
              children: [
                const Expanded(
                  child: Text("3. Horarios de entrega", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: _addDisponibilidad,
                  icon: const Icon(Icons.add_circle, color: AppColors.verdeBosque),
                  label: const Text("Añadir", style: TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildDisponibilidadList(),
          ],
        ),
      ),
      bottomNavigationBar: _buildConfirmBar(),
    );
  }

  Widget _buildCartList() {
    if (widget.cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: const Text("Tu carrito está vacío", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: widget.cart.entries.map((entry) {
          final product = widget.allProducts.firstWhere((p) => p['id'] == entry.key);
          return ListTile(
            title: Text(product['nombre'], style: const TextStyle(fontSize: 14)),
            trailing: Text("\$${(double.parse(product['precio_venta'].toString()) * entry.value).toStringAsFixed(2)}", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: Text("${entry.value}x", style: const TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputContainer({required TextEditingController controller, required String hint, required IconData icon, bool isPhone = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: TextField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.verdeBosque, size: 22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
    );
  }

  Widget _buildDisponibilidadList() {
    if (_disponibilidades.isEmpty) {
      return const Text("No has añadido horarios todavía.", style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Column(
      children: _disponibilidades.asMap().entries.map((entry) {
        return Card(
          elevation: 0,
          color: Colors.green.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.access_time, color: AppColors.verdeBosque),
            title: Text(entry.value, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => setState(() => _disponibilidades.removeAt(entry.key)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Final:", style: TextStyle(fontSize: 15, color: Colors.grey)),
              Text("\$${_calculateTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeBosque, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isSubmitting 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("CONFIRMAR Y ENVIAR PEDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 70),
            const SizedBox(height: 20),
            const Text("¡Pedido en Proceso!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Tu pedido se ha enviado correctamente.", textAlign: TextAlign.center),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                },
                child: const Text("Perfecto"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}