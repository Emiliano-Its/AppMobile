import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import './sales_personal.dart'; 
import './customer_shop_screen.dart';
import './login.dart';
import './admin_users.dart'; // Nueva pantalla de gestión de usuarios

class AdminInventoryHub extends StatefulWidget {
  const AdminInventoryHub({super.key});

  @override
  State<AdminInventoryHub> createState() => _AdminInventoryHubState();
}

class _AdminInventoryHubState extends State<AdminInventoryHub> {
  String _adminName = "Administrador";

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminName = prefs.getString('username') ?? "Administrador";
    });
  }

  // --- FUNCIÓN CORREGIDA PARA CERRAR SESIÓN ---
  void _cerrarSesion(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Esto elimina todas las pantallas previas de la memoria
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Panel de Control", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildPremiumCard(
                    context,
                    title: "Gestión de Ventas",
                    subtitle: "Historial, seguimiento y estados de pedidos activos.",
                    icon: Icons.assignment_turned_in_rounded,
                    colorAccent: Colors.blueGrey.shade600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SalesPersonalScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPremiumCard(
                    context,
                    title: "Vista de Tienda",
                    subtitle: "Previsualiza el catálogo tal como lo ven tus clientes.",
                    icon: Icons.storefront_rounded, 
                    colorAccent: Colors.blue.shade600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CustomerShopScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPremiumCard(
                    context,
                    title: "Gestión de Usuarios",
                    subtitle: "Ver, editar roles y administrar cuentas registradas.",
                    icon: Icons.manage_accounts_rounded,
                    colorAccent: Colors.deepPurple.shade400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  _buildLogoutButton(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
      decoration: const BoxDecoration(
        color: AppColors.verdeBosque,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const CircleAvatar(
              radius: 35,
              backgroundColor: AppColors.fondoHueso,
              child: Icon(Icons.bakery_dining_rounded, size: 40, color: AppColors.verdeBosque),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bienvenido de vuelta,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _adminName, 
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: const Text("Nivel: Admin", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color colorAccent,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: colorAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, color: colorAccent, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                      const SizedBox(height: 5),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded, size: 24),
        label: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.red.shade50,
        ),
        onPressed: () => _cerrarSesion(context),
      ),
    );
  }
}