import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import './customer_pedidos.dart'; 
import './customer_cart_screen.dart';
import './admin_home.dart'; // Importante para la navegación de admin

class CustomerShopScreen extends StatefulWidget {
  const CustomerShopScreen({super.key});

  @override
  State<CustomerShopScreen> createState() => _CustomerShopScreenState();
}

class _CustomerShopScreenState extends State<CustomerShopScreen> {
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  Map<int, int> _cart = {}; 
  bool _isLoading = true;
  String _userName = "Cliente";
  bool _isAdmin = false; // Variable para controlar la visibilidad del panel admin

  final String _productsUrl = 'http://10.0.2.2:8000/api/FinalProduct/';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchProducts();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String rol = prefs.getString('user_rol') ?? "";
    setState(() {
      _userName = prefs.getString('username') ?? "Cliente";
      // Verificamos si el usuario tiene permisos de administrador
      _isAdmin = (rol == 'ADMIN' || rol == 'STAFF');
    });
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse(_productsUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _allProducts = data.where((p) => p['stock_actual'] > 0 && p['activo'] == true).toList();
          _filteredProducts = _allProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al obtener productos: $e");
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredProducts = _allProducts
          .where((p) => p['nombre'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addToCart(int id) => setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  
  void _removeFromCart(int id) {
    setState(() {
      if (_cart.containsKey(id) && _cart[id]! > 0) {
        _cart[id] = _cart[id]! - 1;
        if (_cart[id] == 0) _cart.remove(id);
      }
    });
  }

  int _totalItems() => _cart.values.fold(0, (sum, item) => sum + item);

  double _calculateTotal() {
    double total = 0;
    _cart.forEach((id, qty) {
      final product = _allProducts.firstWhere((p) => p['id'] == id);
      total += (double.parse(product['precio_venta'].toString()) * qty);
    });
    return total;
  }

  void _navigateToCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCartScreen(
          cart: _cart,
          allProducts: _allProducts,
        ),
      ),
    );
    // Al volver, podrías limpiar el carrito si el pedido fue exitoso
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Tostadería el Molino", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          _buildCartBadge(),
        ],
      ),
      drawer: _buildDrawer(), // Aquí implementamos la lógica de roles
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
                : _buildProductGrid(),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.verdeBosque),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: AppColors.verdeBosque),
            ),
            accountName: Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(_isAdmin ? "Administrador del Sistema" : "Cliente Comprador"),
          ),
          
          // --- OPCIÓN SOLO PARA ADMIN ---
          if (_isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              title: const Text("Panel de Inventario", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              subtitle: const Text("Regresar a gestión de productos"),
              onTap: () {
                Navigator.pop(context); // Cierra el Drawer
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (context) => const AdminInventoryHub())
                );
              },
            ),
            const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.shop_two, color: AppColors.verdeBosque),
            title: const Text("Tienda"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.assignment, color: AppColors.verdeBosque),
            title: const Text("Mis Pedidos"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const CustomerPedidos())
              );
            },
          ),
          const Spacer(), // Empuja el cierre de sesión al fondo
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Cerrar Sesión"),
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCartBadge() {
    return InkWell( // Hecho clickeable para navegar al carrito
      onTap: _cart.isNotEmpty ? _navigateToCart : null,
      child: Padding(
        padding: const EdgeInsets.only(right: 15, top: 5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 28, color: Colors.white),
            if (_cart.isNotEmpty)
              Positioned(
                right: 0,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text("${_totalItems()}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: AppColors.verdeBosque,
      child: TextField(
        onChanged: _filterSearch,
        decoration: InputDecoration(
          hintText: "¿Qué tostadas buscamos hoy?",
          prefixIcon: const Icon(Icons.search, color: AppColors.verdeBosque),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_filteredProducts.isEmpty) {
      return const Center(child: Text("No se encontraron productos disponibles."));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final qty = _cart[product['id']] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const Icon(Icons.bakery_dining_rounded, size: 55, color: Colors.orange),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("\$${product['precio_venta']}", style: const TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    qty == 0
                        ? SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product['id']),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque, shape: const StadiumBorder(), elevation: 0),
                              child: const Text("Agregar", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _qtyBtn(Icons.remove, () => _removeFromCart(product['id'])),
                              Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                              _qtyBtn(Icons.add, () => _addToCart(product['id'])),
                            ],
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

  Widget _qtyBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      height: 28, width: 28,
      decoration: BoxDecoration(border: Border.all(color: AppColors.verdeBosque), shape: BoxShape.circle),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: AppColors.verdeBosque),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      height: 95,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Total estimado", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text("\$${_calculateTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verdeBosque,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _navigateToCart, 
            child: const Text("VER CARRITO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}