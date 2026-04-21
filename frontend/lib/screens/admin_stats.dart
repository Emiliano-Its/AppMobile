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
  String _periodo = 'mes'; // semana | mes | año

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
        Uri.parse('${ApiConfig.baseUrl}/stats/?periodo=$_periodo'),
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

  String get _periodoLabel {
    switch (_periodo) {
      case 'semana': return 'últimos 7 días';
      case 'año':    return 'este año';
      default:       return 'últimos 30 días';
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
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _fetchStats),
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
    final List ventasDia    = d['ventas_por_dia'] ?? [];
    final List topProductos = d['top_productos'] ?? [];
    final List stockBajo    = d['stock_bajo'] ?? [];
    final List materias     = d['materias_primas'] ?? [];
    final List rendimiento  = d['rendimiento_mp'] ?? [];

    final int completados = d['completados'] ?? 0;
    final int pendientes  = d['pendientes']  ?? 0;
    final int cancelados  = d['cancelados']  ?? 0;
    final int enCamino    = d['en_camino']   ?? 0;
    final int totalPed    = completados + pendientes + cancelados + enCamino;

    return RefreshIndicator(
      onRefresh: _fetchStats,
      color: primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── FILTRO DE PERÍODO ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: ['semana', 'mes', 'año'].map((p) {
                  final sel = _periodo == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () { setState(() => _periodo = p); _fetchStats(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p[0].toUpperCase() + p.substring(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: sel ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── TARJETAS FINANCIERAS ──────────────────────────────────────
            _SectionTitle("Resumen financiero · $_periodoLabel"),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MetricCard(label: "Hoy",    value: "\$${_fmt(d['total_hoy'])}",     icon: Icons.today_rounded,            color: Colors.teal)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: "Período", value: "\$${_fmt(d['total_periodo'])}", icon: Icons.calendar_month_rounded,   color: primary)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _MetricCard(label: "Ticket prom.", value: "\$${_fmt(d['ticket_prom'])}", icon: Icons.receipt_rounded,       color: Colors.orange.shade700)),
              const SizedBox(width: 10),
              Expanded(child: _MetricCard(label: "Clientes únicos", value: "${d['total_clientes'] ?? 0}", icon: Icons.people_rounded,     color: Colors.deepPurple)),
            ]),

            const SizedBox(height: 24),

            // ── ESTADO DE PEDIDOS ─────────────────────────────────────────
            _SectionTitle("Estado de pedidos · $_periodoLabel"),
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
                      _StatusBadge(label: "Pendientes", count: pendientes,  color: Colors.orange),
                      _StatusBadge(label: "En camino",  count: enCamino,    color: Colors.blue),
                      _StatusBadge(label: "Cancelados", count: cancelados,  color: Colors.red),
                    ],
                  ),
                  if (totalPed > 0) ...[
                    const SizedBox(height: 16),
                    _BarRow("Entregados", completados, totalPed, Colors.green),
                    const SizedBox(height: 8),
                    _BarRow("Pendientes", pendientes,  totalPed, Colors.orange),
                    const SizedBox(height: 8),
                    _BarRow("En camino",  enCamino,    totalPed, Colors.blue),
                    const SizedBox(height: 8),
                    _BarRow("Cancelados", cancelados,  totalPed, Colors.red),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── TOP PRODUCTOS ─────────────────────────────────────────────
            if (topProductos.isNotEmpty) ...[
              _SectionTitle("Top productos · $_periodoLabel"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: topProductos.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final double maxV = (topProductos.first['total_vendido'] as num).toDouble();
                    final double v    = (p['total_vendido'] as num).toDouble();
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
                              value: maxV > 0 ? v / maxV : 0,
                              backgroundColor: Colors.grey.shade100,
                              color: primary, minHeight: 6,
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

            // ── GRÁFICA VENTAS 7 DÍAS ─────────────────────────────────────
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

            // ── CLIENTE FRECUENTE ─────────────────────────────────────────
            if (d['cliente_top'] != null) ...[
              const _SectionTitle("Cliente más frecuente"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['cliente_top']['cliente_nombre'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text("${d['cliente_top']['pedidos']} pedidos en el período",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── ALERTA STOCK BAJO ─────────────────────────────────────────
            if (stockBajo.isNotEmpty) ...[
              const _SectionTitle("Alerta de stock"),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: stockBajo.map((p) {
                    final int s = (p['stock_actual'] as num).toInt();
                    final bool agotado = s == 0;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: agotado ? Colors.red.shade50 : Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning_rounded,
                          color: agotado ? Colors.red : Colors.orange, size: 20),
                      ),
                      title: Text(p['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: agotado ? Colors.red.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("$s uds",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                            color: agotado ? Colors.red.shade800 : Colors.orange.shade800)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── INVENTARIO MATERIA PRIMA ──────────────────────────────────
            const _SectionTitle("Inventario de materia prima"),
            const SizedBox(height: 10),
            materias.isEmpty
                ? _emptyCard("Sin materias primas registradas")
                : Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: materias.asMap().entries.map((e) {
                        final m = e.value;
                        final num s = m['stock_actual'] as num;
                        final bool sinStock  = s == 0;
                        final bool bajo = s > 0 && s < 5;
                        final Color c = sinStock ? Colors.red : bajo ? Colors.orange : primary;
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.grain_rounded, color: c, size: 20),
                          ),
                          title: Text(m['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text("\$${m['precio_ultimo_ingreso']} / ${m['unidad_medida']}",
                            style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("$s", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: c)),
                              Text(m['unidad_medida'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

            const SizedBox(height: 24),

            // ── RENDIMIENTO POR MATERIA PRIMA ─────────────────────────────
            _SectionTitle("Rendimiento de materia prima · $_periodoLabel"),
            const SizedBox(height: 6),
            Text(
              "Ingresos generados por unidad de insumo utilizada",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            rendimiento.isEmpty
                ? _emptyCard("Sin datos de materia prima registrados")
                : Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: rendimiento.map((r) {
                        final double? rendVal = r['rendimiento_por_unidad'] != null
                            ? (r['rendimiento_por_unidad'] as num).toDouble()
                            : null;
                        final bool tieneSalidas = (r['salidas'] as num) > 0;
                        final String rendStr = rendVal != null
                            ? "\$$rendVal / ${r['unidad']}"
                            : tieneSalidas ? "Sin ventas en período" : "Sin salidas registradas";
                        final Color rendColor = rendVal == null
                            ? Colors.grey
                            : rendVal >= 100 ? Colors.green
                            : rendVal >= 50  ? Colors.orange
                            : Colors.red;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(r['nombre'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: rendColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(rendStr,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rendColor)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _MiniStat(label: "Entradas", value: "${r['entradas']} ${r['unidad']}"),
                                  _MiniStat(label: "Salidas",  value: "${r['salidas']} ${r['unidad']}"),
                                  _MiniStat(label: "Stock",    value: "${r['stock_actual']} ${r['unidad']}"),
                                  _MiniStat(label: "Inversión", value: "\$${r['costo_entrada'] ?? 0}"),
                                ],
                              ),
                              if (rendimiento.last != r) ...[
                                const SizedBox(height: 12),
                                Divider(color: Colors.grey.shade100, height: 1),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

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
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) {
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
      minY: 0, maxY: maxY > 0 ? maxY * 1.2 : 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots, isCurved: true, color: primary, barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4, color: primary, strokeWidth: 2, strokeColor: Colors.white),
          ),
          belowBarData: BarAreaData(show: true, color: primary.withOpacity(0.08)),
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
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
              backgroundColor: Colors.grey.shade100,
              color: color, minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)));
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

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
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
  Widget build(BuildContext context) => Column(
    children: [
      Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D2D2D)),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ],
    ),
  );
}