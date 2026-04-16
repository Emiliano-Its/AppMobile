import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  // Colores de tu marca (Verde Bosque y Hueso)
  static const Color primaryColor = Color(0xFF2D5A27); 
  static const Color accentColor = Color(0xFFF5F5DC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Estadísticas de Optimización"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Rendimiento de Producción"),
            const Text("Paquetes obtenidos por kilo de maíz", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildLineChart(),
            const SizedBox(height: 30),
            
            _buildSectionTitle("Utilidad vs Inversión"),
            const SizedBox(height: 20),
            _buildBarChart(),
            const SizedBox(height: 30),
            
            _buildSectionTitle("Resumen de Eficiencia"),
            _buildSummaryCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
    );
  }

  // GRÁFICA DE LÍNEA: Rendimiento (Optimización)
  Widget _buildLineChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 2.1), // Día 1: 2.1 paquetes/kg
                const FlSpot(1, 2.4),
                const FlSpot(2, 2.2),
                const FlSpot(3, 2.8), // Día 4: Mejora en producción
              ],
              isCurved: true,
              color: primaryColor,
              barWidth: 4,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  // GRÁFICA DE BARRAS: Ventas vs Costo de Insumos
  Widget _buildBarChart() {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: [
            _makeGroupData(0, 1000, 400), // Ene: Venta 1000, Costo 400
            _makeGroupData(1, 1200, 500), // Feb
            _makeGroupData(2, 900, 350),  // Mar
          ],
          titlesData: const FlTitlesData(show: false),
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: primaryColor, width: 15),
        BarChartRodData(toY: y2, color: Colors.redAccent, width: 15),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _statCard("Eficiencia", "+12%", Icons.trending_up, Colors.green),
        _statCard("Merma", "2.5 kg", Icons.restore_from_trash, Colors.orange),
        _statCard("Costo Prom.", "\$14.50", Icons.attach_money, Colors.blue),
        _statCard("Producción", "450 pq", Icons.inventory_2, primaryColor),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}