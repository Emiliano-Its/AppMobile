import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart'; // Importación agregada

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
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _username = (prefs.getString('username') ?? "").trim();

    try {
      // --- CAMBIO 1: Usamos ApiConfig.sales y agregamos el timestamp para evitar caché ---
      final url = Uri.parse('${ApiConfig.sales}?t=${DateTime.now().millisecondsSinceEpoch}');
      
      // --- CAMBIO 2: Usamos las cabeceras centralizadas ---
      final response = await http.get(url, headers: ApiConfig.headers);
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            // Filtrado por el nombre de usuario guardado en el teléfono
            _misPedidos = data.where((p) {
              String clienteJson = (p['cliente_nombre'] ?? "").toString().trim().toUpperCase();
              return clienteJson == _username.toUpperCase();
            }).toList();

            _misPedidos.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando pedidos desde Debian: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con el servidor de la tostadería")),
        );
      }
    }
  }

  Color _getStatusColor(String? estado) {
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchMisPedidos, 
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
          : _misPedidos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchMisPedidos,
                  color: AppColors.verdeBosque,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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
    return SingleChildScrollView( 
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            const Text("Aún no tienes pedidos registrados", 
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeBosque,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              child: const Text("VOLVER A LA TIENDA", style: TextStyle(color: Colors.white)),
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
        subtitle: Text("Total a pagar: \$$total"),
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
                const Text("Resumen de productos:", style: TextStyle(fontWeight: FontWeight.bold)),
                
                if (pedido['details'] != null)
                  ...(pedido['details'] as List).map((det) => Padding(
                    padding: const EdgeInsets.only(left: 5, top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.verdeBosque),
                        const SizedBox(width: 8),
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
                  const Text("No se encontraron detalles de productos.", style: TextStyle(fontStyle: FontStyle.italic)),
                
                const Divider(height: 20),
                const Text("Dirección de entrega:", style: TextStyle(fontWeight: FontWeight.bold)),
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