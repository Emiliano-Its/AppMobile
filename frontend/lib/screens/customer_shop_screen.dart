import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart';  
import './customer_cart_screen.dart';
import './admin_home.dart';

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
  bool _isAdmin = false; 

  final String _productsUrl = ApiConfig.products;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchProducts();
  }

  String _currentUser = '';

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String rol = prefs.getString('user_rol') ?? '';
    final String nuevoUser = prefs.getString('username') ?? 'Cliente';
    setState(() {
      // Si cambió el usuario, limpiar el carrito
      if (_currentUser.isNotEmpty && _currentUser != nuevoUser) {
        _cart.clear();
      }
      _currentUser = nuevoUser;
      _userName = nuevoUser;
      _isAdmin = (rol == 'ADMIN' || rol == 'STAFF');
    });
  }

  Future<void> _fetchProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse(_productsUrl),
        headers: {
          ...ApiConfig.headers,
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _allProducts = data.where((p) => 
            (p['stock_actual'] ?? 0) > 0 && p['activo'] == true
          ).toList();
          _filteredProducts = _allProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al obtener productos: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final prefs = await SharedPreferences.getInstance();
    final int userId = prefs.getInt('user_id') ?? 0;
    final prefix = userId > 0 ? 'uid_${userId}__' : '';
    String direccion = prefs.getString('${prefix}default_address') ?? '';
    String telefono  = prefs.getString('${prefix}default_phone') ?? '';

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCartScreen(
          cart: _cart,
          allProducts: _allProducts,
          defaultAddress: direccion,
          defaultPhone: telefono,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        leading: _isAdmin 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Intentamos hacer pop, si no puede (porque es la raíz), 
                // lo mandamos manualmente al Home de Admin.
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminInventoryHub()),
                    (route) => false,
                  );
                }
              },
            )
          : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tostadería 20 de Noviembre",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
            Text(
              "Hola, $_userName",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          _buildCartBadge(),
        ],
      ),


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

  Widget _buildCartBadge() {
    return InkWell(
      onTap: _navigateToCart, 
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
                  child: Text("${_totalItems()}", 
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
          hintText: "¿Qué se te antoja hoy?",
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
      return const Center(child: Text("No hay productos disponibles."));
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
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: product['imagen_url'] != null
                        ? Image.network(
                            ApiConfig.getImageUrl(product['imagen_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          )
                        : const Icon(Icons.bakery_dining_rounded, size: 55, color: Colors.orange),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['nombre'], 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("\$${product['precio_venta']}", 
                      style: const TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    qty == 0
                        ? SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.verdeBosque, 
                                shape: const StadiumBorder(), elevation: 0),
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
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Total de tu pedido", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
                "\$${_calculateTotal().toStringAsFixed(2)}", 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.verdeBosque),
              ),
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
            child: const Text("VER MI CARRITO", 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}