import 'package:flutter/material.dart';
import '../main.dart';
import './admin_final_products.dart';
import './admin_raw_material.dart';
import './sales_personal.dart'; 
import './customer_shop_screen.dart';
// --- IMPORTACIÓN NUEVA ---
import './admin_stats.dart'; 

class AdminInventoryHub extends StatelessWidget {
  const AdminInventoryHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Panel Administrativo", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
        automaticallyImplyLeading: false, 
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- NUEVA OPCIÓN: ESTADÍSTICAS ---
            _buildLargeOption(
              context,
              title: "Estadísticas y Optimización",
              subtitle: "Rendimiento, costos y utilidades netas",
              icon: Icons.bar_chart_rounded,
              color: Colors.teal.shade700, 
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminStatsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildLargeOption(
              context,
              title: "Materias Primas",
              subtitle: "Control de bultos, costos y stock actual",
              icon: Icons.inventory_2_outlined,
              color: AppColors.verdeBosque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RawMaterialScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildLargeOption(
              context,
              title: "Productos Finales",
              subtitle: "Maneja el catálogo de Tostadas y paquetes",
              icon: Icons.shopping_cart_checkout_rounded,
              color: const Color(0xFFE8A400), 
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinalProductsScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildLargeOption(
              context,
              title: "Ventas y Ordenes",
              subtitle: "Monitorea entregas y el historial de ventas",
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.blue.shade700, 
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesPersonalScreen()),
                );
              },
            ),
            const SizedBox(height: 20),

            _buildLargeOption(
              context,
              title: "Vista de Comprador",
              subtitle: "Acceso a la tienda pública",
              icon: Icons.storefront_rounded,
              color: Colors.purple.shade600, 
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerShopScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeOption(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF1A1A1A) // Color de título sólido
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}