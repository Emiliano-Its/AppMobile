// lib/screens/admin/admin_inventory_hub.dart
import 'package:flutter/material.dart';
import '../main.dart';
import './admin_final_products.dart';
import './admin_raw_material.dart';
import './sales_personal.dart'; 
import './customer_shop_screen.dart';

class AdminInventoryHub extends StatelessWidget {
  const AdminInventoryHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Bienvenido, Administrador.", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
        // --- ESTA ES LA CORRECCIÓN ---
        automaticallyImplyLeading: false, // Esto quita la flecha de regreso "fantasma"
        // -----------------------------
        actions: [
          // Opcional: Podrías añadir un botón de cerrar sesión aquí también
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
            _buildLargeOption(
              context,
              title: "Materias Primas",
              subtitle: "Setup supplies, costs, and providers",
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
              subtitle: "Maneja el catálogo de Productos finales",
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
              subtitle: "Monitorea las órdenes y el historial de Ventas",
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
              subtitle: "Ve lo que tus clientes ven",
              icon: Icons.storefront_rounded,
              color: Colors.purple.shade600, 
              onTap: () {
                // Usamos pushReplacement para que al ir a la tienda 
                // no se quede la pantalla de admin "atrás"
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
                      color: AppColors.tituloNegro
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