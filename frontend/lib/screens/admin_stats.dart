import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  static const Color primary = Color(0xFF2D6A4F);
  static const Color hueso   = Color(0xFFF3F3ED);

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/stats/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        setState(() { _data = json.decode(response.body); _isLoading = false; });
      } else {
        setState(() { _error = 'Error ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Sin conexión al servidor'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hueso,
      appBar: AppBar(
        title: const Text("Estadísticas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchStats,
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Reintentar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final List ventasDia = d['ventas_por_dia'] ?? [];
    final List topProductos = d['top_productos'] ?? [];
    final List stockBajo = d['stock_bajo'] ?? [];
    final String consejo = d['consejo'] ?? '';
    final int completados = d['completados'] ?? 0;
    final int cancelados  = d['cancelados'] ?? 0;
    final int pendientes  = d['pendientes'] ?? 0;
    final total = completados + cancelados + pendientes;
    final List materias = d['materias_primas'] ?? [];
    final List rendimiento = d['rendimiento_mes'] ?? [];
    final List produccionSemanal = d['produccion_semanal'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── CONSEJO DEL DÍA ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Consejo del día",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(consejo,
                          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── TARJETAS FINANCIERAS ─────────────────────────────────────
            const _SectionTitle("Resumen financiero"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricCard(label: "Hoy",    value: "\$${_fmt(d['total_hoy'])}", icon: Icons.today_rounded,         color: Colors.teal)),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(label: "Semana", value: "\$${_fmt(d['total_semana'])}", icon: Icons.date_range_rounded, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MetricCard(label: "Mes",    value: "\$${_fmt(d['total_mes'])}", icon: Icons.calendar_month_rounded, color: primary)),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(label: "Ticket prom.", value: "\$${_fmt(d['ticket_prom'])}", icon: Icons.receipt_rounded, color: Colors.orange.shade700)),
              ],
            ),

            const SizedBox(height: 24),

            // ── GRÁFICA DE VENTAS 7 DÍAS ─────────────────────────────────
            const _SectionTitle("Ventas últimos 7 días"),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: SizedBox(
                height: 180,
                child: ventasDia.isEmpty
                    ? const Center(child: Text("Sin datos", style: TextStyle(color: Colors.grey)))
                    : LineChart(_buildLineData(ventasDia)),
              ),
            ),

            const SizedBox(height: 24),

            // ── ESTADO DE PEDIDOS ────────────────────────────────────────
            const _SectionTitle("Estado de pedidos — últimos 30 días"),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatusBadge(label: "Entregados", count: completados, color: Colors.green),
                      _StatusBadge(label: "Cancelados", count: cancelados,  color: Colors.red),
                      _StatusBadge(label: "Pendientes", count: pendientes,  color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (total > 0) ...[
                    _BarRow("Entregados", completados, total, Colors.green),
                    const SizedBox(height: 8),
                    _BarRow("Cancelados",  cancelados,  total, Colors.red),
                    const SizedBox(height: 8),
                    _BarRow("Pendientes",  pendientes,  total, Colors.orange),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── TOP PRODUCTOS ────────────────────────────────────────────
            if (topProductos.isNotEmpty) ...[
              const _SectionTitle("Top productos — últimos 30 días"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: topProductos.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final maxVenta = (topProductos.first['total_vendido'] as num).toDouble();
                    final vendido  = (p['total_vendido'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                                child: Center(child: Text('${i+1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(p['producto__nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                              Text("${p['total_vendido']} uds", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxVenta > 0 ? vendido / maxVenta : 0,
                              backgroundColor: Colors.grey.shade100,
                              color: primary,
                              minHeight: 6,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Text("\$${_fmt(p['ingreso'])}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ),
                          if (i < topProductos.length - 1) Divider(height: 1, color: Colors.grey.shade100),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── CLIENTES ─────────────────────────────────────────────────
            const _SectionTitle("Clientes"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: "Clientes únicos",
                    value: "${d['total_clientes'] ?? 0}",
                    icon: Icons.people_rounded,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: "Cliente frecuente",
                    value: d['cliente_top'] != null
                        ? (d['cliente_top']['cliente_nombre'] ?? '-')
                        : '-',
                    icon: Icons.star_rounded,
                    color: Colors.amber.shade700,
                    smallText: true,
                  ),
                ),
              ],
            ),

            // ── STOCK BAJO ───────────────────────────────────────────────
            if (stockBajo.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionTitle("Alerta de stock"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: stockBajo.map((p) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (p['stock_actual'] as num) == 0 ? Colors.red.shade50 : Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_rounded,
                        color: (p['stock_actual'] as num) == 0 ? Colors.red : Colors.orange,
                        size: 20),
                    ),
                    title: Text(p['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (p['stock_actual'] as num) == 0 ? Colors.red.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${p['stock_actual']} uds",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: (p['stock_actual'] as num) == 0 ? Colors.red.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── MATERIA PRIMA: INVENTARIO ACTUAL ─────────────────────────
            const _SectionTitle("Inventario de materia prima"),
            const SizedBox(height: 10),
            if (materias.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Center(child: Text("Sin registros de materia prima", style: TextStyle(color: Colors.grey))),
              )
            else
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: materias.asMap().entries.map((e) {
                    final m = e.value;
                    final double stock = (m['stock_actual'] as num).toDouble();
                    final double precio = (m['precio_ultimo_ingreso'] as num).toDouble();
                    final bool sinStock = stock == 0;
                    final bool stockBajoFlag = stock > 0 && stock < 10;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sinStock ? Colors.red.shade50 : stockBajoFlag ? Colors.orange.shade50 : Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.grain_rounded,
                          size: 18,
                          color: sinStock ? Colors.red : stockBajoFlag ? Colors.orange : Colors.green.shade700,
                        ),
                      ),
                      title: Text(m['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text("Último precio: \$${precio.toStringAsFixed(2)} / ${m['unidad_medida']}", style: const TextStyle(fontSize: 12)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${stock.toStringAsFixed(1)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: sinStock ? Colors.red : primary)),
                          Text(m['unidad_medida'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 24),

            // ── RENDIMIENTO DE PRODUCCIÓN ─────────────────────────────────
            if (rendimiento.isNotEmpty) ...[
              const _SectionTitle("Rendimiento de producción — 30 días"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: rendimiento.map((r) {
                    final double rend = (r['rendimiento_prom'] as num?)?.toDouble() ?? 0;
                    final int paquetes = (r['total_paquetes'] as num?)?.toInt() ?? 0;
                    final double insumo = (r['total_insumo'] as num?)?.toDouble() ?? 0;
                    final double costo = (r['costo_total'] as num?)?.toDouble() ?? 0;
                    final Color rendColor = rend >= 3 ? Colors.green : rend >= 2 ? Colors.orange : Colors.red;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r['materia_prima__nombre'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: rendColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${rend.toStringAsFixed(2)} paq/${r['materia_prima__unidad_medida']}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: rendColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _MiniStat(label: "Paquetes", value: "$paquetes"),
                            _MiniStat(label: "Insumo usado", value: "${insumo.toStringAsFixed(1)} ${r['materia_prima__unidad_medida']}"),
                            _MiniStat(label: "Costo insumo", value: "\$${costo.toStringAsFixed(0)}"),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (rendimiento.last != r) Divider(color: Colors.grey.shade100),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── PRODUCCIÓN SEMANAL ────────────────────────────────────────
            if (produccionSemanal.isNotEmpty) ...[
              const _SectionTitle("Producción — últimas 4 semanas"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                child: SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      barGroups: produccionSemanal.asMap().entries.map((e) {
                        final paq = (e.value['paquetes'] as num).toDouble();
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: paq,
                              color: primary,
                              width: 28,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= produccionSemanal.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(produccionSemanal[idx]['semana'],
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineData(List ventasDia) {
    final spots = ventasDia.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['total'] as num).toDouble())
    ).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx < 0 || idx >= ventasDia.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(ventasDia[idx]['dia'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY > 0 ? maxY * 1.2 : 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primary,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4, color: primary, strokeWidth: 2, strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: primary.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    final d = double.tryParse(val.toString()) ?? 0;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}k';
    return d.toStringAsFixed(0);
  }

  Widget _BarRow(String label, int value, int total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade100,
              color: color,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool smallText;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                  style: TextStyle(
                    fontSize: smallText ? 13 : 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D2D2D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D2D2D)),
            textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}