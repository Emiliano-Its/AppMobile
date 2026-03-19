import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; // Asegúrate de que AppColors esté definido aquí

class LocalSalesScreen extends StatefulWidget {
  const LocalSalesScreen({super.key});

  @override
  State<LocalSalesScreen> createState() => _LocalSalesScreenState();
}

class _LocalSalesScreenState extends State<LocalSalesScreen> {
  List<dynamic> _products = [];
  Map<int, int> _cart = {}; // ID del producto -> Cantidad
  bool _isLoading = false;
  String _searchQuery = "";

  // Ajusta estas URLs según tu IP local o servidor
  final String _productsUrl = 'http://10.0.2.2:8000/api/FinalProduct/';
  final String _salesUrl = 'http://10.0.2.2:8000/api/sales/';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_productsUrl));
      if (response.statusCode == 200) {
        setState(() => _products = json.decode(response.body));
      }
    } catch (e) {
      _showSnackBar("Error al conectar con el servidor", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DEL CARRITO ---
  void _addToCart(dynamic prod) {
    int id = prod['id'];
    int stock = prod['stock_actual'];
    int currentQty = _cart[id] ?? 0;

    if (currentQty < stock) {
      setState(() => _cart[id] = currentQty + 1);
    } else {
      _showSnackBar("Sin stock suficiente de ${prod['nombre']}", Colors.orange);
    }
  }

  void _removeFromCart(int id) {
    if (_cart.containsKey(id)) {
      setState(() {
        if (_cart[id]! > 1) {
          _cart[id] = _cart[id]! - 1;
        } else {
          _cart.remove(id);
        }
      });
    }
  }

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((id, qty) {
      final prod = _products.firstWhere((p) => p['id'] == id);
      total += double.parse(prod['precio_venta'].toString()) * qty;
    });
    return total;
  }

  // --- DIÁLOGO DE COBRO (ESTILO PUNTO DE VENTA) ---
  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;

    final double total = _calculateTotal();
    final TextEditingController _pagoController = TextEditingController();
    double _cambio = -total;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.payments, color: AppColors.verdeBosque),
                  SizedBox(width: 10),
                  Text("Finalizar Cobro", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("TOTAL A PAGAR:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("\$${total.toStringAsFixed(2)}", 
                    style: const TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pagoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "¿Con cuánto pagan?",
                      prefixText: "\$ ",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (val) {
                      double pago = double.tryParse(val) ?? 0;
                      setDialogState(() {
                        _cambio = pago - total;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _cambio >= 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _cambio >= 0 ? Colors.green : Colors.red),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_cambio >= 0 ? "CAMBIO:" : "FALTAN:", 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("\$${_cambio.abs().toStringAsFixed(2)}", 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, 
                          color: _cambio >= 0 ? Colors.green[700] : Colors.red[700])),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeBosque,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _cambio >= 0 ? () {
                    Navigator.pop(context); // Cierra diálogo
                    _registerSaleInDjango(); 
                  } : null,
                  child: const Text("REGISTRAR VENTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ENVÍO A DJANGO ---
  Future<void> _registerSaleInDjango() async {
    // Estructura de detalles para el SaleSerializer
    List details = _cart.entries.map((e) {
      final prod = _products.firstWhere((p) => p['id'] == e.key);
      return {
        "producto": e.key,
        "cantidad": e.value,
        "precio_unitario": prod['precio_venta'].toString()
      };
    }).toList();

    final Map<String, dynamic> saleData = {
      "tipo": "LOCAL",
      "cliente_nombre": "Venta Mostrador",
      "total": _calculateTotal().toStringAsFixed(2),
      "details": details, // Nota: Asegúrate que el serializer use 'details' o 'detalles'
    };

    try {
      final response = await http.post(
        Uri.parse(_salesUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode(saleData),
      );

      if (response.statusCode == 201) {
        _showSnackBar("¡Venta registrada con éxito!", Colors.green);
        setState(() => _cart.clear());
        if (mounted) Navigator.pop(context); // Regresa al panel principal
      } else {
        // Imprime el error exacto de Django en la terminal de Flutter
        print("Error de Django: ${response.body}");
        _showSnackBar("Error al guardar: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión: $e", Colors.red);
    }
  }

  // --- INTERFAZ ---
  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) => 
      p['nombre'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Venta Local"),
        backgroundColor: AppColors.verdeBosque,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar producto...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildProductGrid(filtered),
          ),
          if (_cart.isNotEmpty) _buildCheckoutBar(),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List products) {
    if (products.isEmpty) return const Center(child: Text("No se encontraron productos"));

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10
      ),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        final int id = p['id'];
        final int qty = _cart[id] ?? 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fastfood, color: Colors.orange, size: 40),
              const SizedBox(height: 10),
              Text(p['nombre'], style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text("\$${p['precio_venta']}", style: const TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold)),
              Text("Stock: ${p['stock_actual']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => _removeFromCart(id),
                  ),
                  Text("$qty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.verdeBosque),
                    onPressed: () => _addToCart(p),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TOTAL:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("\$${_calculateTotal().toStringAsFixed(2)}", 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeBosque,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: _showCheckoutDialog,
              child: const Text("COBRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, duration: const Duration(seconds: 2))
    );
  }
}