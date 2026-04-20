import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

// Pantallas ADMIN
import './admin_stats.dart';
import './admin_raw_material.dart';
import './admin_final_products.dart';
import './admin_home.dart';

// Pantallas STAFF
import './sales_personal.dart';
import './personal_account.dart';

// Pantallas CLIENTE
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
    final rol = (prefs.getString('user_rol') ?? 'CLIENTE').toUpperCase().trim();
    setState(() {
      _userRol = rol;
      _isLoading = false;

      // Cada rol arranca en su tab principal
      if (rol == 'ADMIN') {
        _currentIndex = 3; // Panel de control (admin_home)
      } else if (rol == 'STAFF') {
        _currentIndex = 0; // Ventas
      } else {
        _currentIndex = 0; // Tienda
      }
    });
  }

  // ── ADMIN: Stats / Productos / Insumos / Panel ──────────────────────────
  List<Widget> _getAdminScreens() => [
    const AdminStatsScreen(),
    const FinalProductsScreen(),
    const RawMaterialScreen(),
    const AdminInventoryHub(),
  ];

  List<BottomNavigationBarItem> _adminTabs() => const [
    BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded),     label: 'Stats'),
    BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded),   label: 'Productos'),
    BottomNavigationBarItem(icon: Icon(Icons.bakery_dining_rounded), label: 'Insumos'),
    BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Panel'),
  ];

  // ── STAFF: Ventas / Mi Perfil ───────────────────────────────────────────
  List<Widget> _getStaffScreens() => [
    const SalesPersonalScreen(),
    const PersonalAccountScreen(),
  ];

  List<BottomNavigationBarItem> _staffTabs() => const [
    BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded),  label: 'Ventas'),
    BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Mi Perfil'),
  ];

  // ── CLIENTE: Tienda / Pedidos / Perfil ──────────────────────────────────
  List<Widget> _getCustomerScreens() => [
    const CustomerShopScreen(),
    CustomerPedidos(
      onGoToShop: () => setState(() => _currentIndex = 0),
    ),
    const CustomerAccountScreen(),
  ];

  List<BottomNavigationBarItem> _customerTabs() => const [
    BottomNavigationBarItem(icon: Icon(Icons.store_rounded),         label: 'Tienda'),
    BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Pedidos'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.verdeBosque),
        ),
      );
    }

    final bool isAdmin  = _userRol == 'ADMIN';
    final bool isStaff  = _userRol == 'STAFF';

    final List<Widget> screens = isAdmin
        ? _getAdminScreens()
        : isStaff
            ? _getStaffScreens()
            : _getCustomerScreens();

    final List<BottomNavigationBarItem> tabs = isAdmin
        ? _adminTabs()
        : isStaff
            ? _staffTabs()
            : _customerTabs();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.verdeBosque,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        items: tabs,
      ),
    );
  }
}