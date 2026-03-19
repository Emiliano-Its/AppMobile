import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; 

class FinalProductsScreen extends StatefulWidget {
  const FinalProductsScreen({super.key});

  @override
  State<FinalProductsScreen> createState() => _FinalProductsScreenState();
}

class _FinalProductsScreenState extends State<FinalProductsScreen> {
  List<dynamic> _allProducts = []; 
  List<dynamic> _filteredProducts = []; 
  bool _isLoading = true;

  final String apiUrl = 'http://10.0.2.2:8000/api/FinalProduct/';

  @override
  void initState() {
    super.initState();
    _fetchProductos();
  }

  // --- 1. OBTENER PRODUCTOS (GET) ---
  Future<void> _fetchProductos() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        setState(() {
          _allProducts = json.decode(response.body);
          _filteredProducts = _allProducts; 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando productos: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. FILTRAR PRODUCTOS ---
  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts
          .where((p) => p['nombre'].toLowerCase().contains(query.toLowerCase()) || 
                        p['codigo_barras'].contains(query))
          .toList();
    });
  }

  // --- 3. GUARDAR O ACTUALIZAR (POST / PUT) ---
  Future<void> _saveProduct(String name, String code, String price, String stock, bool isEditing, {int? id}) async {
    final url = isEditing ? Uri.parse('$apiUrl$id/') : Uri.parse(apiUrl);
    
    final Map<String, dynamic> data = {
      "nombre": name,
      "codigo_barras": code,
      "precio_venta": price,
      "stock_actual": int.parse(stock),
      // Mantenemos el estado activo actual al editar
    };

    try {
      final response = isEditing 
          ? await http.put(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(data))
          : await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(data));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context); 
        _fetchProductos(); 
        _showSnackBar("¡Producto guardado!", Colors.green);
      } else {
        _showSnackBar("Error: ${response.body}", Colors.red);
      }
    } catch (e) {
      debugPrint("Error de red: $e");
    }
  }

  // --- 4. TOGGLE ACTIVO (BORRADO LÓGICO) ---
  Future<void> _toggleProductStatus(int id) async {
    try {
      // Llamamos a la acción personalizada que creamos en Django
      final response = await http.post(Uri.parse('$apiUrl$id/toggle_active/'));
      if (response.statusCode == 200) {
        _fetchProductos();
        _showSnackBar("Estado del producto actualizado", AppColors.verdeBosque);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- 5. ELIMINAR PERMANENTE (DELETE) ---
  Future<void> _deleteProduct(int id) async {
    try {
      final response = await http.delete(Uri.parse('$apiUrl$id/'));
      if (response.statusCode == 204) {
        _fetchProductos();
        _showSnackBar("Producto eliminado permanentemente", Colors.orange);
      } else {
        // Aquí capturamos el ProtectedError de Django
        _showSnackBar("No se puede borrar: El producto tiene ventas asociadas. Desactívalo en su lugar.", Colors.red);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- UTILIDADES DE UI ---
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar Producto"),
        content: Text("¿Qué deseas hacer con '$name'?\n\n'Borrar' eliminará todo rastro. 'Desactivar' lo ocultará de los clientes pero mantendrá tus registros."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(id);
            }, 
            child: const Text("BORRAR", style: TextStyle(color: Colors.red))
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
        title: const Text("Inventario Final", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
              : RefreshIndicator(
                  onRefresh: _fetchProductos,
                  child: _filteredProducts.isEmpty 
                    ? const Center(child: Text("No hay productos"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_filteredProducts[index]);
                        },
                      ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.verdeBosque,
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: AppColors.verdeBosque,
      child: TextField(
        onChanged: _filterProducts,
        decoration: InputDecoration(
          hintText: "Buscar por nombre o código...",
          prefixIcon: const Icon(Icons.search, color: AppColors.verdeBosque),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic item) {
    bool estaActivo = item['activo'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Opacity(
        opacity: estaActivo ? 1.0 : 0.6,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: estaActivo ? AppColors.verdeBosque.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            child: Icon(
              estaActivo ? Icons.bakery_dining : Icons.visibility_off_outlined, 
              color: estaActivo ? AppColors.verdeBosque : Colors.grey
            ),
          ),
          title: Text(
            item['nombre'], 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              decoration: estaActivo ? TextDecoration.none : TextDecoration.lineThrough
            )
          ),
          subtitle: Text("Stock: ${item['stock_actual']} | \$${item['precio_venta']}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón para Activar/Desactivar
              IconButton(
                icon: Icon(estaActivo ? Icons.check_circle : Icons.pause_circle_outline, 
                color: estaActivo ? Colors.green : Colors.orange),
                onPressed: () => _toggleProductStatus(item['id']),
                tooltip: "Pausar/Activar",
              ),
              // Botón para Borrar
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(item['id'], item['nombre']),
              ),
            ],
          ),
          onTap: () => _showFormDialog(producto: item),
        ),
      ),
    );
  }

  // --- Los métodos _showFormDialog y _buildInput se mantienen iguales ---
  void _showFormDialog({dynamic producto}) {
    final bool isEditing = producto != null;
    final nombreCtrl = TextEditingController(text: isEditing ? producto['nombre'] : '');
    final codigoCtrl = TextEditingController(text: isEditing ? producto['codigo_barras'] : '');
    final precioCtrl = TextEditingController(text: isEditing ? producto['precio_venta'].toString() : '');
    final stockCtrl = TextEditingController(text: isEditing ? producto['stock_actual'].toString() : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoHueso,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
          left: 25, right: 25, top: 25
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? "Editar Producto" : "Nuevo Producto Final", 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)
            ),
            const SizedBox(height: 20),
            _buildInput("Nombre del Producto", nombreCtrl),
            _buildInput("Código de Barras", codigoCtrl),
            Row(
              children: [
                Expanded(child: _buildInput("Precio", precioCtrl, isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildInput("Stock actual", stockCtrl, isNumber: true)),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeBosque, 
                  shape: const StadiumBorder()
                ),
                onPressed: () {
                  if (nombreCtrl.text.isNotEmpty && precioCtrl.text.isNotEmpty) {
                    _saveProduct(
                      nombreCtrl.text,
                      codigoCtrl.text,
                      precioCtrl.text,
                      stockCtrl.text,
                      isEditing,
                      id: isEditing ? producto['id'] : null,
                    );
                  } else {
                    _showSnackBar("Nombre y Precio son obligatorios", Colors.red);
                  }
                },
                child: Text(
                  isEditing ? "ACTUALIZAR" : "GUARDAR PRODUCTO", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(color: AppColors.verdeBosque),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.verdeBosque)),
        ),
      ),
    );
  }
}