import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Para AppColors y fondoHueso
import 'local_sales_personal.dart'; 
import 'corte_caja.dart';

class SalesPersonalScreen extends StatefulWidget {
  const SalesPersonalScreen({super.key});

  @override
  State<SalesPersonalScreen> createState() => _SalesPersonalScreenState();
}

class _SalesPersonalScreenState extends State<SalesPersonalScreen> {
  List<dynamic> _pendingOrders = [];
  List<dynamic> _inProcessOrders = [];
  bool _isLoading = false;

  final String _baseSalesUrl = 'http://10.0.2.2:8000/api/sales/';

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchPendingOrders(),
        _fetchInProcessOrders(),
      ]);
    } catch (e) {
      _showSnackBar("Error al actualizar datos", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPendingOrders() async {
    final response = await http.get(Uri.parse('${_baseSalesUrl}?type=PEDIDO'));
    if (response.statusCode == 200) {
      setState(() => _pendingOrders = json.decode(response.body));
    }
  }

  Future<void> _fetchInProcessOrders() async {
    final response = await http.get(Uri.parse('${_baseSalesUrl}?type=ENTREGA'));
    if (response.statusCode == 200) {
      setState(() => _inProcessOrders = json.decode(response.body));
    }
  }

  // Aceptar pedido (Pasa de PENDIENTE a ENTREGA y descuenta stock)
  Future<void> _processOrder(dynamic order) async {
    final int id = order['id'];
    try {
      final response = await http.post(Uri.parse('$_baseSalesUrl$id/aceptar_pedido/'));
      if (response.statusCode == 200) {
        _refreshAll();
        _showSnackBar("¡Pedido enviado a entrega!", Colors.green);
      } else {
        final error = json.decode(response.body);
        _showSnackBar("Error: ${error['error']}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  // Cobrar pedido (Pasa de ENTREGA a LOCAL)
  Future<void> _cobrarPedidoEntrega(int id) async {
    try {
      final response = await http.post(Uri.parse('$_baseSalesUrl$id/cobrar_entrega/'));
      if (response.statusCode == 200) {
        _refreshAll();
        _showSnackBar("¡Pedido cobrado con éxito!", Colors.green);
      } else {
        _showSnackBar("Error al cobrar pedido", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  Future<void> _deleteOrder(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseSalesUrl$id/'));
      if (response.statusCode == 204) {
        _refreshAll();
        _showSnackBar("Pedido eliminado", Colors.orange);
      }
    } catch (e) {
      debugPrint("Error al eliminar: $e");
    }
  }

  // --- DIÁLOGOS ---

  void _showConfirmOrderDialog(dynamic order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirmar Envío: ${order['cliente_nombre']}", 
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Al confirmar, se descontará el stock."),
              const Divider(),
              _buildOrderSummary(order),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque),
            onPressed: () {
              Navigator.pop(context);
              _processOrder(order);
            },
            child: const Text("ENVIAR A RUTA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Diálogo de Cobro para Entregas (Similar al POS Local)
  void _showCashPaymentDialog(dynamic order) {
    final double total = double.parse(order['total'].toString());
    final TextEditingController _pagoController = TextEditingController();
    double _cambio = -total;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Cobrar Entrega: ${order['cliente_nombre']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("\$${total.toStringAsFixed(2)}", 
                style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
              const SizedBox(height: 15),
              TextField(
                controller: _pagoController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Pago en Efectivo",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onChanged: (val) {
                  double pago = double.tryParse(val) ?? 0;
                  setDialogState(() => _cambio = pago - total);
                },
              ),
              const SizedBox(height: 15),
              Text(_cambio >= 0 ? "Cambio: \$${_cambio.toStringAsFixed(2)}" : "Faltan: \$${_cambio.abs().toStringAsFixed(2)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cambio >= 0 ? Colors.green : Colors.red)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque),
              onPressed: _cambio >= 0 ? () {
                Navigator.pop(context);
                _cobrarPedidoEntrega(order['id']);
              } : null,
              child: const Text("FINALIZAR Y COBRAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- INTERFAZ ---

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.fondoHueso,
        appBar: AppBar(
          title: const Text("Panel de Ventas", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.verdeBosque,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: "Pendientes"),
              Tab(icon: Icon(Icons.delivery_dining), text: "En Entrega"),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildQuickActions(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
                : TabBarView(
                    children: [
                      RefreshIndicator(onRefresh: _refreshAll, child: _buildOrdersList(_pendingOrders, isPending: true)),
                      RefreshIndicator(onRefresh: _refreshAll, child: _buildOrdersList(_inProcessOrders, isPending: false)),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.verdeBosque,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionCard(
            icon: Icons.add_shopping_cart, 
            label: "Venta Local", 
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LocalSalesScreen()))
                .then((_) => _refreshAll());
            }
          ),
          _actionCard(
            icon: Icons.history, 
            label: "Corte de Caja", 
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CorteCajaScreen()),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<dynamic> orders, {required bool isPending}) {
    if (orders.isEmpty) {
      return Center(child: Text(isPending ? "No hay pedidos pendientes." : "No hay entregas en curso."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isPending ? Colors.orangeAccent : Colors.blueAccent,
              child: Icon(isPending ? Icons.receipt_long : Icons.local_shipping, color: Colors.white),
            ),
            title: Text(order['cliente_nombre'] ?? "Cliente", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Total: \$${order['total']} | ID: #${order['id']}"),
            trailing: isPending 
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(order['id'], order['cliente_nombre'] ?? "Cliente"),
                )
              : IconButton(
                  icon: const Icon(Icons.monetization_on, color: Colors.green),
                  onPressed: () => _showCashPaymentDialog(order),
                ),
            children: [
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildOrderSummary(order),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending ? AppColors.verdeBosque : Colors.green[700],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isPending ? Icons.check_circle : Icons.payments, color: Colors.white),
                  label: Text(isPending ? "ACEPTAR PEDIDO" : "COBRAR ENTREGA", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => isPending ? _showConfirmOrderDialog(order) : _showCashPaymentDialog(order),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(dynamic order) {
    final List details = order['details'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Detalles del Pedido:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 5),
        ...details.map((d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${d['cantidad']}x ${d['product_name'] ?? 'Producto'}", style: const TextStyle(fontSize: 13)),
              Text("\$${(double.parse(d['precio_unitario'].toString()) * d['cantidad']).toStringAsFixed(2)}"),
            ],
          ),
        )).toList(),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, content: Text(message), duration: const Duration(seconds: 2)));
  }

  void _confirmDelete(int id, String cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Rechazar Pedido?"),
        content: Text("Se eliminará el pedido de $cliente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER")),
          TextButton(onPressed: () { Navigator.pop(context); _deleteOrder(id); }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}