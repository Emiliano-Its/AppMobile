import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../main.dart'; 
import '../api_config.dart';
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

  // --- CAMBIO 1: Usamos la URL base desde ApiConfig ---
  final String _baseSalesUrl = ApiConfig.sales;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      await Future.wait([
        _fetchPendingOrders(token),
        _fetchInProcessOrders(token),
      ]);
    } catch (e) {
      _showSnackBar("Error al actualizar datos desde el servidor", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPendingOrders(String token) async {
    final response = await http.get(
      Uri.parse('$_baseSalesUrl?tipo=PEDIDO'),
      headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() => _pendingOrders = data
          .where((o) => (o['estado'] ?? '').toString().toUpperCase() != 'RECHAZADO')
          .toList());
    }
  }

  Future<void> _fetchInProcessOrders(String token) async {
    final response = await http.get(
      Uri.parse('$_baseSalesUrl?tipo=ENTREGA'),
      headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() => _inProcessOrders = data
          .where((o) => (o['estado'] ?? '').toString().toUpperCase() != 'RECHAZADO')
          .toList());
    }
  }

  // Aceptar pedido (Pasa de PENDIENTE a ENTREGA y descuenta stock)
  Future<void> _processOrder(dynamic order) async {
    final int id = order['id'];
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseSalesUrl$id/aceptar_pedido/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      
      if (response.statusCode == 200) {
        _refreshAll();
        _showSnackBar("¡Pedido enviado a ruta de entrega!", Colors.green);
      } else {
        final error = json.decode(response.body);
        _showSnackBar("Error: ${error['error']}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión con Debian", Colors.red);
    }
  }

  // Cobrar pedido (Pasa de ENTREGA a LOCAL/FINALIZADO)
  Future<void> _cobrarPedidoEntrega(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseSalesUrl$id/cobrar_entrega/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      
      if (response.statusCode == 200) {
        _refreshAll();
        _showSnackBar("¡Pedido cobrado con éxito!", Colors.green);
      } else {
        _showSnackBar("Error al procesar el cobro", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión con el servidor", Colors.red);
    }
  }

  Future<void> _deleteOrder(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.delete(
        Uri.parse('$_baseSalesUrl$id/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 204) {
        _refreshAll();
        _showSnackBar("Pedido eliminado correctamente", Colors.orange);
      }
    } catch (e) {
      debugPrint("Error al eliminar pedido: $e");
    }
  }

  Future<void> _cancelarPedido(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseSalesUrl$id/cancelar_pedido/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        _refreshAll();
        _showSnackBar("Pedido cancelado y stock restaurado", Colors.orange);
      } else {
        final err = json.decode(response.body);
        _showSnackBar(err['error'] ?? "No se pudo cancelar", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  Future<void> _enviarMensaje(int id, String texto) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('$_baseSalesUrl$id/enviar_mensaje/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
        body: jsonEncode({'texto': texto}),
      );
      if (response.statusCode == 201) {
        _refreshAll();
        _showSnackBar("Mensaje enviado al cliente", AppColors.verdeBosque);
      } else {
        _showSnackBar("No se pudo enviar el mensaje", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  void _showMensajeDialog(dynamic order) {
    final TextEditingController _msgCtrl = TextEditingController();
    final List mensajes = order['mensajes'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoHueso,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.message_rounded, color: AppColors.verdeBosque),
                const SizedBox(width: 10),
                Text(
                  "Mensajes — ${order['cliente_nombre'] ?? 'Cliente'}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mensajes.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mensajes.length,
                  itemBuilder: (context, i) {
                    final m = mensajes[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(m['texto'] ?? '', style: const TextStyle(fontSize: 13)),
                    );
                  },
                ),
              )
            else
              Text("Sin mensajes previos.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 15),
            TextField(
              controller: _msgCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Escribe un mensaje para el cliente...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: const Text("ENVIAR MENSAJE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeBosque,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_msgCtrl.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    _enviarMensaje(order['id'], _msgCtrl.text.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(dynamic order) {
    final bool yaAceptado = order['tipo'] == 'ENTREGA';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cancelar pedido?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          yaAceptado
            ? "Este pedido ya fue aceptado y su stock descontado. Al cancelar, el stock se restaurará automáticamente."
            : "Se cancelará el pedido de ${order['cliente_nombre'] ?? 'Cliente'} y se marcará como rechazado.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cancelarPedido(order['id']);
            },
            child: const Text("CANCELAR PEDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS DE UI (Diálogos y Widgets se mantienen igual) ---

  void _showConfirmOrderDialog(dynamic order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text("Confirmar Envío: ${order['cliente_nombre']}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Al confirmar, se descontará el stock de las tostadas."),
                const Divider(),
                // isPending: false para mostrar dirección, teléfono y horarios
                _buildOrderSummary(order, isPending: false),
              ],
            ),
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          title: Text("Cobrar Entrega: ${order['cliente_nombre']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("\$${total.toStringAsFixed(2)}", 
                  style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
                const SizedBox(height: 15),
                TextField(
                  controller: _pagoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Monto recibido",
                    prefixText: "\$ ",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onChanged: (val) {
                    double pago = double.tryParse(val) ?? 0;
                    setDialogState(() => _cambio = pago - total);
                  },
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _cambio >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_cambio >= 0 ? "Cambio:" : "Faltan:"),
                      Text("\$${_cambio.abs().toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _cambio >= 0 ? Colors.green : Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque),
              onPressed: _cambio >= 0 ? () {
                Navigator.pop(context);
                _cobrarPedidoEntrega(order['id']);
              } : null,
              child: const Text("FINALIZAR COBRO", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.fondoHueso,
        appBar: AppBar(
          title: const Text("Panel de Ventas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppColors.verdeBosque,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
            icon: Icons.route_rounded,
            label: "Ruta de Hoy",
            onTap: () {
              if (_inProcessOrders.isEmpty) {
                _showSnackBar("No hay entregas en curso", Colors.orange);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RutaEntregasScreen(pedidos: _inProcessOrders)),
                );
              }
            },
          ),
          _actionCard(
            icon: Icons.history, 
            label: "Corte de Caja", 
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CorteCajaScreen()));
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
        width: 100,
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
                child: _buildOrderSummary(order, isPending: isPending),
              ),
              // Botón de ver en mapa solo para entregas con coordenadas
              if (!isPending && order['lat_entrega'] != null && order['lng_entrega'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text("VER EN MAPA", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RutaEntregasScreen(pedidos: _inProcessOrders),
                      ),
                    ),
                  ),
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
              ),
              // Botones de mensaje y cancelar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message_rounded, size: 16),
                        label: const Text("MENSAJE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.verdeBosque,
                          side: const BorderSide(color: AppColors.verdeBosque),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _showMensajeDialog(order),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const Text("CANCELAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _showCancelDialog(order),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderSummary(dynamic order, {bool isPending = true}) {
    final List details = order['details'] ?? [];
    final String direccion = (order['direccion_envio'] ?? '').toString();
    final String telefono = (order['telefono_contacto'] ?? '').toString();
    final String horarios = (order['fecha_entrega_estimada'] ?? 'No especificado').toString();

    // Verificar si el pedido está fuera de su ventana de horario
    bool fueraDeHorario = false;
    if (!isPending && horarios.isNotEmpty && horarios != 'No especificado') {
      fueraDeHorario = _estaFueraDeHorario(horarios);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alerta de horario si aplica
        if (fueraDeHorario)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Pedido fuera del horario disponible del cliente",
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // Info del pedido — siempre visible (pendiente y en entrega)
        if (direccion.isNotEmpty)
          _infoRow(Icons.location_on_rounded, Colors.red, "Dirección", direccion),
        if (direccion.isNotEmpty) const SizedBox(height: 6),
        if (telefono.isNotEmpty)
          _infoRow(Icons.phone_rounded, Colors.green, "Teléfono", telefono),
        if (telefono.isNotEmpty) const SizedBox(height: 6),
        _infoRow(Icons.access_time_rounded, Colors.blueAccent, "Horarios disponibles", horarios),
        const Divider(height: 20),

        const Text("Productos:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 5),
        ...details.map((d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${d['cantidad']}x ${d['producto_nombre'] ?? 'Producto'}", style: const TextStyle(fontSize: 13)),
              Text("\$${(double.parse(d['precio_unitario'].toString()) * d['cantidad']).toStringAsFixed(2)}"),
            ],
          ),
        )).toList(),
      ],
    );
  }

  // Verifica si ahora mismo estamos fuera de los horarios del cliente
  bool _estaFueraDeHorario(String horarios) {
    try {
      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      // Formato: "1/5 (9:00 AM - 6:00 PM) | 2/5 (10:00 AM - 5:00 PM)"
      for (final bloque in horarios.split('|')) {
        final match = RegExp(r'\((\d+):(\d+)\s*(AM|PM)\s*-\s*(\d+):(\d+)\s*(AM|PM)\)').firstMatch(bloque);
        if (match != null) {
          int hStart = int.parse(match.group(1)!);
          final mStart = int.parse(match.group(2)!);
          final ampmStart = match.group(3)!;
          int hEnd = int.parse(match.group(4)!);
          final mEnd = int.parse(match.group(5)!);
          final ampmEnd = match.group(6)!;

          if (ampmStart == 'PM' && hStart != 12) hStart += 12;
          if (ampmStart == 'AM' && hStart == 12) hStart = 0;
          if (ampmEnd == 'PM' && hEnd != 12) hEnd += 12;
          if (ampmEnd == 'AM' && hEnd == 12) hEnd = 0;

          final startMin = hStart * 60 + mStart;
          final endMin = hEnd * 60 + mEnd;

          if (nowMinutes >= startMin && nowMinutes <= endMin) return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
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
        content: Text("Se eliminará el pedido de $cliente de forma permanente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER")),
          TextButton(onPressed: () { Navigator.pop(context); _deleteOrder(id); }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ── PANTALLA DE RUTA DE ENTREGAS ─────────────────────────────────────────────
class RutaEntregasScreen extends StatefulWidget {
  final List<dynamic> pedidos;
  const RutaEntregasScreen({super.key, required this.pedidos});

  @override
  State<RutaEntregasScreen> createState() => _RutaEntregasScreenState();
}

class _RutaEntregasScreenState extends State<RutaEntregasScreen> {
  late List<dynamic> _rutaOrdenada;
  final MapController _mapController = MapController();

  // Punto de origen: la tostadería (coordenadas desde ApiConfig o fijas)
  static const LatLng _origen = LatLng(25.6866, -100.3161);

  @override
  void initState() {
    super.initState();
    _rutaOrdenada = _optimizarRuta(widget.pedidos);
  }

  // Algoritmo greedy: nearest neighbor desde el origen
  List<dynamic> _optimizarRuta(List<dynamic> pedidos) {
    final conCoords = pedidos.where((p) =>
      p['lat_entrega'] != null && p['lng_entrega'] != null
    ).toList();
    final sinCoords = pedidos.where((p) =>
      p['lat_entrega'] == null || p['lng_entrega'] == null
    ).toList();

    if (conCoords.isEmpty) return sinCoords;

    final List<dynamic> ruta = [];
    final pendientes = List<dynamic>.from(conCoords);
    LatLng actual = _origen;

    while (pendientes.isNotEmpty) {
      // Encuentra el más cercano al punto actual
      double minDist = double.infinity;
      dynamic masC = pendientes.first;
      for (final p in pendientes) {
        final dist = _distancia(actual, LatLng(
          double.parse(p['lat_entrega'].toString()),
          double.parse(p['lng_entrega'].toString()),
        ));
        if (dist < minDist) {
          minDist = dist;
          masC = p;
        }
      }
      ruta.add(masC);
      pendientes.remove(masC);
      actual = LatLng(
        double.parse(masC['lat_entrega'].toString()),
        double.parse(masC['lng_entrega'].toString()),
      );
    }

    // Los pedidos sin coordenadas van al final
    return [...ruta, ...sinCoords];
  }

  // Distancia euclidiana simple (suficiente para ordenar localmente)
  double _distancia(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return dLat * dLat + dLng * dLng;
  }

  Color _alertColor(dynamic p) {
    final horarios = (p['fecha_entrega_estimada'] ?? '').toString();
    if (horarios.isEmpty) return Colors.grey;
    try {
      final now = TimeOfDay.now();
      final nowMin = now.hour * 60 + now.minute;
      for (final bloque in horarios.split('|')) {
        final m = RegExp(r'\((\d+):(\d+)\s*(AM|PM)\s*-\s*(\d+):(\d+)\s*(AM|PM)\)').firstMatch(bloque);
        if (m != null) {
          int hs = int.parse(m.group(1)!); final ms = int.parse(m.group(2)!); final as_ = m.group(3)!;
          int he = int.parse(m.group(4)!); final me = int.parse(m.group(5)!); final ae = m.group(6)!;
          if (as_ == 'PM' && hs != 12) hs += 12;
          if (as_ == 'AM' && hs == 12) hs = 0;
          if (ae == 'PM' && he != 12) he += 12;
          if (ae == 'AM' && he == 12) he = 0;
          if (nowMin >= hs * 60 + ms && nowMin <= he * 60 + me) return Colors.green;
        }
      }
      return Colors.orange;
    } catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    final conCoords = _rutaOrdenada.where((p) =>
      p['lat_entrega'] != null && p['lng_entrega'] != null
    ).toList();

    final markers = <Marker>[
      // Marcador de origen (tostadería)
      Marker(
        point: _origen,
        width: 44, height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.verdeBosque,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 22),
        ),
      ),
      // Marcadores de entregas numerados
      ...conCoords.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final color = _alertColor(p);
        return Marker(
          point: LatLng(
            double.parse(p['lat_entrega'].toString()),
            double.parse(p['lng_entrega'].toString()),
          ),
          width: 36, height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        );
      }),
    ];

    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Ruta de Entregas",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Mapa
          SizedBox(
            height: 280,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: conCoords.isNotEmpty
                  ? LatLng(
                      double.parse(conCoords.first['lat_entrega'].toString()),
                      double.parse(conCoords.first['lng_entrega'].toString()),
                    )
                  : _origen,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tostaderia.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Leyenda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                _leyenda(Colors.green, "Dentro de horario"),
                const SizedBox(width: 16),
                _leyenda(Colors.orange, "Fuera de horario"),
                const SizedBox(width: 16),
                _leyenda(Colors.grey, "Sin horario"),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Text("ORDEN DE PARADAS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
              ],
            ),
          ),

          // Lista ordenada
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _rutaOrdenada.length,
              itemBuilder: (context, i) {
                final p = _rutaOrdenada[i];
                final tieneCoords = p['lat_entrega'] != null && p['lng_entrega'] != null;
                final color = tieneCoords ? _alertColor(p) : Colors.grey;
                final horarios = (p['fecha_entrega_estimada'] ?? 'Sin horario').toString();
                final direccion = (p['direccion_envio'] ?? 'Sin dirección').toString();
                final telefono = (p['telefono_contacto'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Número de parada
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: tieneCoords ? color : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              tieneCoords ? '${i + 1}' : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['cliente_nombre'] ?? 'Cliente',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.location_on_rounded, size: 13, color: Colors.red),
                                const SizedBox(width: 4),
                                Expanded(child: Text(direccion, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ]),
                              if (telefono.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.phone_rounded, size: 13, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(telefono, style: const TextStyle(fontSize: 12)),
                                ]),
                              ],
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(Icons.access_time_rounded, size: 13, color: color),
                                const SizedBox(width: 4),
                                Expanded(child: Text(horarios, style: TextStyle(fontSize: 12, color: color), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ]),
                              if (!tieneCoords)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text("Sin coordenadas — al final de la ruta",
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                                ),
                            ],
                          ),
                        ),
                        Text("\$${p['total']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}