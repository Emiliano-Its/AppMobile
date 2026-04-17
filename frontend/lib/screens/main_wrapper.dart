import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importaciones de tus constantes y pantallas
import '../main.dart'; 
import './admin_stats.dart';
import './admin_raw_material.dart';
import './admin_final_products.dart'; 
import './admin_home.dart'; 
import './customer_shop_screen.dart';
import './customer_account.dart';
import './customer_pedidos.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  String _userRol = 'CLIENTE'; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRol = (prefs.getString('user_rol') ?? 'CLIENTE').toUpperCase().trim();
      _isLoading = false;
      
      // Si es ADMIN o STAFF, por defecto iniciamos en la pestaña del Panel (Home)
      if (_userRol == 'ADMIN' || _userRol == 'STAFF') {
        _currentIndex = 3; 
      }
    });
  }

  // --- PANTALLAS PARA ADMIN ---
  List<Widget> _getAdminScreens() {
    return [
      const AdminStatsScreen(),         // Tab 0
      const FinalProductsScreen(),      // Tab 1
      const RawMaterialScreen(),        // Tab 2
      const AdminInventoryHub(),        // Tab 3 (El admin_home con los botones grandes)
    ];
  }

  // --- PANTALLAS PARA CLIENTE ---
  List<Widget> _getCustomerScreens() {
    return [
      const CustomerShopScreen(),       // Tab 0
      const CustomerPedidos(),          // Tab 1 (Nombre corregido)
      const CustomerAccountScreen(),    // Tab 2
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.verdeBosque)),
      );
    }

    bool isAdmin = (_userRol == 'ADMIN' || _userRol == 'STAFF');
    final screens = isAdmin ? _getAdminScreens() : _getCustomerScreens();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.verdeBosque,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        // Generamos los items de la barra según el rol
        items: isAdmin ? _adminTabs() : _customerTabs(),
      ),
    );
  }

  // --- TABS DEL ADMIN ---
  List<BottomNavigationBarItem> _adminTabs() {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Stats'),
      BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Productos'),
      BottomNavigationBarItem(icon: Icon(Icons.bakery_dining), label: 'Insumos'),
      BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Home'),
    ];
  }

  // --- TABS DEL CLIENTE ---
  List<BottomNavigationBarItem> _customerTabs() {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'Tienda'),
      BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Pedidos'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
    ];
  }
}