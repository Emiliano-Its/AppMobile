import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart'; // Importación agregada para centralizar la IP

class CustomerCartScreen extends StatefulWidget {
  final Map<int, int> cart;
  final List<dynamic> allProducts;

  const CustomerCartScreen({
    super.key, 
    required this.cart, 
    required this.allProducts
  });

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  final TextEditingController _direccionController = TextEditingController();
  final List<String> _disponibilidades = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _direccionController.text = ""; 
  }

  double _calculateTotal() {
    double total = 0;
    widget.cart.forEach((id, qty) {
      final product = widget.allProducts.firstWhere((p) => p['id'] == id);
      total += (double.parse(product['precio_venta'].toString()) * qty);
    });
    return total;
  }

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

  // --- FUNCIÓN DE CONFIRMACIÓN CORREGIDA ---
  Future<void> _confirmOrder() async {
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
      "fecha_entrega_estimada": _disponibilidades.join(" | "), 
      "total": _calculateTotal(),
      "estado": "PENDIENTE",
      "details": details
    };

    try {
      // CAMBIO: Usamos ApiConfig.sales y ApiConfig.headers
      final response = await http.post(
        Uri.parse(ApiConfig.sales),
        headers: ApiConfig.headers,
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showSuccessDialog();
      } else {
         _showSnackBar("Error al enviar el pedido: ${response.body}");
      }
    } catch (e) {
      _showSnackBar("Error de conexión con el servidor Debian.");
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ... (El resto del código de la interfaz UI se mantiene igual) ...

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
            
            const Text("2. Dirección de Entrega", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildAddressInput(),
            
            const SizedBox(height: 30),
            
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("3. ¿Cuándo podemos entregarte?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("Puedes marcar varios días o rangos.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _addDisponibilidad,
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.verdeBosque, size: 20),
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

  Widget _buildAddressInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
      ),
      child: TextField(
        controller: _direccionController,
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: "Calle, Número, Colonia...",
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Icon(Icons.location_on, color: AppColors.verdeBosque, size: 28),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildDisponibilidadList() {
    if (_disponibilidades.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_available, color: Colors.grey, size: 40),
            SizedBox(height: 10),
            Text("Añade tus horarios disponibles arriba", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    return Column(
      children: _disponibilidades.asMap().entries.map((entry) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: Colors.green.shade50.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade100)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: const Icon(Icons.access_time_filled, color: AppColors.verdeBosque, size: 28),
            title: Text(entry.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Final a Pagar:", style: TextStyle(fontSize: 15, color: Colors.grey)),
              Text("\$${_calculateTotal().toStringAsFixed(2)}", 
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
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
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text("CONFIRMAR Y ENVIAR PEDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
            const Text("Tu pedido se ha enviado, y se confirmará pronto", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text("Perfecto", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}