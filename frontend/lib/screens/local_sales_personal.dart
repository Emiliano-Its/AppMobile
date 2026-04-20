import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart'; 
import 'package:mobile_scanner/mobile_scanner.dart';

class LocalSalesScreen extends StatefulWidget {
  const LocalSalesScreen({super.key});

  @override
  State<LocalSalesScreen> createState() => _LocalSalesScreenState();
}

class _LocalSalesScreenState extends State<LocalSalesScreen> {
  List<dynamic> _products = [];
  Map<int, int> _cart = {}; 
  bool _isLoading = false;
  String _searchQuery = "";

  // --- CAMBIO 1: Usamos las rutas dinámicas de ApiConfig ---
  final String _productsUrl = ApiConfig.products;
  final String _salesUrl = ApiConfig.sales;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse(_productsUrl),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      
      if (response.statusCode == 200) {
        setState(() => _products = json.decode(response.body));
      }
    } catch (e) {
      _showSnackBar("Error al conectar con el servidor", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ... (Lógica de carrito y total se mantienen igual) ...

  void _addToCart(dynamic prod) {
    int id = prod['id'];
    int stock = (prod['stock_actual'] ?? 0);
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

  // --- REGISTRO DE VENTA CORREGIDO ---
  Future<void> _registerSaleInDjango() async {
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
      "details": details, 
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse(_salesUrl),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
        body: json.encode(saleData),
      );

      if (response.statusCode == 201) {
        _showSnackBar("¡Venta registrada con éxito!", Colors.green);
        setState(() => _cart.clear());
        // Refrescamos productos para actualizar el stock localmente
        _fetchProducts(); 
      } else {
        debugPrint("Error de Django: ${response.body}");
        _showSnackBar("Error al guardar: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión con Debian: $e", Colors.red);
    }
  }

  // --- DIÁLOGO DE COBRO ---
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
              content: SingleChildScrollView( // <--- AGREGADO PARA EVITAR OVERFLOW
                child: Column(
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeBosque,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _cambio >= 0 ? () {
                    Navigator.pop(context); 
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

  @override
  Widget build(BuildContext context) {
    final filtered = _products.where((p) => 
      p['nombre'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
            title: const Text("Venta en Mostrador", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppColors.verdeBosque,
            iconTheme: const IconThemeData(color: Colors.white),
            // --- AGREGAMOS ESTO ---
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                onPressed: _escanearParaVenta,
                tooltip: "Escanear producto",
              ),
              const SizedBox(width: 10),
            ],
          ),

          
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar producto...",
                prefixIcon: const Icon(Icons.search, color: AppColors.verdeBosque),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
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
        childAspectRatio: 0.7, // Ajustado un poco para dar espacio a la imagen
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
          clipBehavior: Clip.antiAlias, // Para que la imagen respete los bordes curvos
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- SECCIÓN DE IMAGEN IMPLEMENTADA ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: p['imagen'] != null
                      ? Image.network(
                          ApiConfig.getImageUrl(p['imagen']),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : const Icon(Icons.bakery_dining, color: Colors.orange, size: 40),
                ),
              ),
              const SizedBox(height: 8),
              Text(p['nombre'], 
                style: const TextStyle(fontWeight: FontWeight.bold), 
                textAlign: TextAlign.center,
                maxLines: 1, overflow: TextOverflow.ellipsis
              ),
              Text("\$${p['precio_venta']}", 
                style: const TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold)),
              Text("Stock: ${p['stock_actual']}", 
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                    onPressed: () => _removeFromCart(id),
                  ),
                  Text("$qty", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.verdeBosque, size: 24),
                    onPressed: () => _addToCart(p),
                  ),
                ],
              ),
              const SizedBox(height: 5),
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

  Future<void> _escanearParaVenta() async {
  final MobileScannerController scannerController = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.normal,
  );

  final String? codigoDetectado = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("Escaneando para Venta", style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.verdeBosque,
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? rawValue = barcode.rawValue;
                  if (rawValue != null && (rawValue.length == 13 || rawValue.length == 8)) {
                    if (RegExp(r'^[0-9]+$').hasMatch(rawValue)) {
                      scannerController.dispose();
                      Navigator.pop(context, rawValue);
                      break;
                    }
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 280, height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  scannerController.dispose();

  if (codigoDetectado != null) {
    _procesarCodigoEscaneado(codigoDetectado);
  }
}

void _procesarCodigoEscaneado(String codigo) {
  try {
    // Buscamos el producto en la lista que ya tenemos cargada
    final producto = _products.firstWhere(
      (p) => p['codigo_barras'] == codigo,
      orElse: () => null,
    );

    if (producto != null) {
      _addToCart(producto);
      _showSnackBar("Agregado: ${producto['nombre']}", AppColors.verdeBosque);
    } else {
      _showSnackBar("Producto no registrado ($codigo)", Colors.orange);
    }
  } catch (e) {
    _showSnackBar("Error al procesar código", Colors.red);
  }
}
}