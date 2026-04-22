import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart'; // Importación agregada

class CustomerPedidos extends StatefulWidget {
  final VoidCallback? onGoToShop;

  const CustomerPedidos({super.key, this.onGoToShop});

  @override
  State<CustomerPedidos> createState() => _CustomerPedidosState();
}

class _CustomerPedidosState extends State<CustomerPedidos> {
  List<dynamic> _misPedidos = [];
  bool _isLoading = true;
  String _username = "";
  final Set<int> _archivados = {};

  @override
  void initState() {
    super.initState();
    _loadArchivados().then((_) => _fetchMisPedidos());
  }

  Future<void> _loadArchivados() async {
    final prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('user_id') ?? 0;
    final key = 'uid_${userId}__pedidos_archivados';
    final List<String> guardados = prefs.getStringList(key) ?? [];
    setState(() {
      _archivados.addAll(guardados.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1));
    });
  }

  Future<void> _saveArchivados() async {
    final prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('user_id') ?? 0;
    final key = 'uid_${userId}__pedidos_archivados';
    await prefs.setStringList(key, _archivados.map((e) => e.toString()).toList());
  }

Future<void> _fetchMisPedidos() async {
    if (mounted) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _username = (prefs.getString('username') ?? "").trim();
    // SACAMOS EL TOKEN PARA QUE EL SERVER NO NOS REBOTE
    final token = prefs.getString('access_token') ?? '';

    try {
      final url = Uri.parse('${ApiConfig.sales}?t=${DateTime.now().millisecondsSinceEpoch}');
      
      // AGREGAMOS EL AUTHORIZATION HEADER
      final response = await http.get(
        url, 
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _misPedidos = data.where((p) {
              return p['cliente_nombre'].toString().trim().toLowerCase() == _username.toLowerCase();
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          print("Error del servidor: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print("Error de conexión: $e");
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

  Future<void> _marcarMensajesLeidos(int ventaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      await http.post(
        Uri.parse('${ApiConfig.sales}$ventaId/marcar_mensajes_leidos/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      _fetchMisPedidos();
    } catch (_) {}
  }

  Future<void> _cancelarPedido(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('${ApiConfig.sales}$id/cancelar_pedido/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        _fetchMisPedidos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pedido cancelado"), backgroundColor: Colors.orange),
          );
        }
      } else {
        final err = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err['error'] ?? "No se pudo cancelar"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Archiva localmente (solo oculta en esta sesión, no borra del servidor)
  void _archivarPedido(int id) {
    setState(() => _archivados.add(id));
    _saveArchivados();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pedido removido de tu lista"),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _showCancelConfirm(dynamic pedido) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cancelar pedido?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Tu pedido será cancelado. Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cancelarPedido(pedido['id']);
            },
            child: const Text("CANCELAR PEDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showArchivarConfirm(dynamic pedido) {
    final String estado = (pedido['estado'] ?? '').toString().toUpperCase();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Quitar de tu lista?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          estado == 'ENTREGADO'
            ? "El pedido fue entregado. Se quitará de tu lista pero el historial se conserva."
            : "El pedido rechazado se quitará de tu lista.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _archivarPedido(pedido['id']);
            },
            child: const Text("QUITAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          : _misPedidos.where((p) => !_archivados.contains(p['id'])).isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchMisPedidos,
                  color: AppColors.verdeBosque,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(15),
                    itemCount: _misPedidos.where((p) => !_archivados.contains(p['id'])).length,
                    itemBuilder: (context, index) {
                      final visibles = _misPedidos
                          .where((p) => !_archivados.contains(p['id']))
                          .toList();
                      return _buildPedidoCard(visibles[index]);
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
              onPressed: () {
                // Si hay callback (viene del MainWrapper), lo usamos.
                // Si no, intentamos pop solo si hay pantalla previa.
                if (widget.onGoToShop != null) {
                  widget.onGoToShop!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
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
    final List mensajes = (pedido['mensajes'] ?? []) as List;
    final int noLeidos = mensajes.where((m) => m['leido'] == false).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          // Al abrir el tile marcamos los mensajes como leídos
          if (expanded && noLeidos > 0) {
            _marcarMensajesLeidos(pedido['id']);
          }
        },
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStatusColor(estado).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_bag, color: _getStatusColor(estado)),
            ),
            if (noLeidos > 0)
              Positioned(
                right: -2, top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$noLeidos', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
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

                // Botones de acción según estado
                if (['PENDIENTE', 'ACEPTADO'].contains(estado)) ...[
                  const Divider(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text("CANCELAR PEDIDO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _showCancelConfirm(pedido),
                    ),
                  ),
                ] else if (['RECHAZADO', 'ENTREGADO'].contains(estado)) ...[
                  const Divider(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        estado == 'ENTREGADO' ? "QUITAR DE MI LISTA" : "DESCARTAR",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _showArchivarConfirm(pedido),
                    ),
                  ),
                ],
                if (mensajes.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.message_rounded, size: 16, color: AppColors.verdeBosque),
                      const SizedBox(width: 6),
                      const Text("Mensajes de tu pedido:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...mensajes.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m['leido'] == false ? Colors.blue.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: m['leido'] == false ? Colors.blue.shade200 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          m['leido'] == false ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded,
                          size: 16,
                          color: m['leido'] == false ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(m['texto'] ?? '', style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
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