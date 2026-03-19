import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Asegúrate de que AppColors esté aquí

class CustomerPedidos extends StatefulWidget {
  const CustomerPedidos({super.key});

  @override
  State<CustomerPedidos> createState() => _CustomerPedidosState();
}

class _CustomerPedidosState extends State<CustomerPedidos> {
  List<dynamic> _misPedidos = [];
  bool _isLoading = true;
  String _username = "";

  @override
  void initState() {
    super.initState();
    _fetchMisPedidos();
  }

  Future<void> _fetchMisPedidos() async {
    // 1. Mostramos carga para que el usuario sepa que algo está pasando
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    // Normalizamos el username para evitar errores de comparación
    _username = (prefs.getString('username') ?? "").trim();

    try {
      // Agregamos un timestamp o parámetro aleatorio para evitar que el 
      // navegador/emulador devuelva una respuesta vieja (caché)
      final url = Uri.parse('http://10.0.2.2:8000/api/sales/?t=${DateTime.now().millisecondsSinceEpoch}');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            // FILTRADO ROBUSTO: Convertimos ambos a mayúsculas y quitamos espacios
            _misPedidos = data.where((p) {
              String clienteJson = (p['cliente_nombre'] ?? "").toString().trim().toUpperCase();
              return clienteJson == _username.toUpperCase();
            }).toList();

            // Ordenamos por ID descendente (más nuevo arriba)
            _misPedidos.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando pedidos: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con el servidor")),
        );
      }
    }
  }

  Color _getStatusColor(String? estado) {
    // Mapeo exacto con los estados de tu Django
    switch (estado?.toUpperCase()) {
      case 'PENDIENTE': return Colors.orange;
      case 'ACEPTADO': return Colors.blue;
      case 'EN_CAMINO': return Colors.purple;
      case 'ENTREGADO': return Colors.green;
      case 'RECHAZADO': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Mis Pedidos", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMisPedidos, // Botón manual de refresco
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
          : _misPedidos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchMisPedidos, // Refrescar al deslizar hacia abajo
                  color: AppColors.verdeBosque,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // Importante para RefreshIndicator
                    padding: const EdgeInsets.all(15),
                    itemCount: _misPedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = _misPedidos[index];
                      return _buildPedidoCard(pedido);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView( // Permite el pull-to-refresh incluso cuando está vacío
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            const Text("Aún no tienes pedidos", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque),
              child: const Text("IR A LA TIENDA", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoCard(dynamic pedido) {
    final String estado = (pedido['estado'] ?? 'PENDIENTE').toString().toUpperCase();
    final String id = (pedido['id'] ?? '0').toString();
    final String total = (pedido['total'] ?? '0.00').toString();
    final String direccion = (pedido['direccion_envio'] ?? 'Sin dirección').toString();
    final String fechaDisponibilidad = (pedido['fecha_entrega_estimada'] ?? 'No definida').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 15), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(estado).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.shopping_bag, color: _getStatusColor(estado)),
        ),
        title: Text("Pedido #$id", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Total: \$$total"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _getStatusColor(estado),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            estado,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rowDetalle("Estado actual:", estado),
                const SizedBox(height: 8),
                const Text("Tus horarios de disponibilidad:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(fechaDisponibilidad, style: const TextStyle(fontSize: 13, color: AppColors.verdeBosque)),
                const Divider(height: 20),
                const Text("Productos solicitados:", style: TextStyle(fontWeight: FontWeight.bold)),
                
                // Mapeo de detalles del pedido
                if (pedido['details'] != null)
                  ...(pedido['details'] as List).map((det) => Padding(
                    padding: const EdgeInsets.only(left: 5, top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.verdeBosque),
                        const SizedBox(width: 8),
                        // Usamos producto_nombre que configuramos en el Serializer de Django
                        Expanded(
                          child: Text(
                            "${det['cantidad']}x ${det['producto_nombre'] ?? 'Producto'}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text("\$${det['precio_unitario']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )).toList()
                else
                  const Text("Cargando productos...", style: TextStyle(fontStyle: FontStyle.italic)),
                
                const Divider(height: 20),
                const Text("Dirección de envío:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(direccion, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _rowDetalle(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    );
  }
}