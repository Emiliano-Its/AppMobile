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
  static const Color primary  = Color(0xFF2D6A4F);
  static const Color accent   = Color(0xFF52B788);
  static const Color hueso    = Color(0xFFF3F3ED);
  static const Color darkCard = Color(0xFF1B4332);

  // Período global para fetch
  String _periodoVentas   = 'semana';
  String _periodoPedidos  = 'mes';
  String _periodoProductos = 'mes';

  // Solo se hace un fetch cuando cambia cualquiera — el backend usa el período más amplio
  // y Flutter filtra localmente cuando sea necesario. Por simplicidad fetcheamos por el
  // período de ventas que es la sección principal.
  bool _isLoading = true;
  String? _error;

  // Mantenemos caché de los 3 períodos
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _fetchStats(_periodoVentas);
    _fetchStats(_periodoPedidos);
    _fetchStats(_periodoProductos);
  }

  bool _cacheValido(String periodo) {
    if (!_cache.containsKey(periodo)) return false;
    final ts = _cacheTime[periodo];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _cacheTTL;
  }

  Future<void> _fetchStats(String periodo) async {
    if (_cacheValido(periodo)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/stats/?periodo=$periodo'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _cache[periodo] = json.decode(response.body);
          _cacheTime[periodo] = DateTime.now();
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() { _error = 'Error ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Sin conexión'; _isLoading = false; });
    }
  }

  Future<void> _refreshAll() async {
    setState(() { _cache.clear(); _cacheTime.clear(); _isLoading = true; });
    await Future.wait([
      _fetchStats(_periodoVentas),
      _fetchStats(_periodoPedidos),
      _fetchStats(_periodoProductos),
    ]);
  }

  void _setPeriodo(String tipo, String valor) {
    setState(() {
      if (tipo == 'ventas')    _periodoVentas   = valor;
      if (tipo == 'pedidos')   _periodoPedidos  = valor;
      if (tipo == 'productos') _periodoProductos = valor;
    });
    _fetchStats(valor);
  }

  Map<String, dynamic>? _d(String periodo) => _cache[periodo];

  String _label(String p) {
    switch (p) {
      case 'semana': return '7 días';
      case 'año':    return 'Este año';
      default:       return '30 días';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hueso,
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
            onPressed: _refreshAll,
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text("Reintentar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── APP BAR HERO ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: darkCard,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                onPressed: _refreshAll,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [darkCard, primary],
                  ),
                ),
                child: Stack(
                  children: [
                    // Círculos decorativos
                    Positioned(top: -20, right: -20,
                      child: Container(width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withOpacity(0.15),
                        ),
                      ),
                    ),
                    Positioned(bottom: -30, left: 40,
                      child: Container(width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Tostadería",
                                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                                  Text("Panel de estadísticas",
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── VENTAS (PRIMERA SECCIÓN) ──────────────────────────────
                _buildSectionHeader("Ventas", _periodoVentas, 'ventas'),
                const SizedBox(height: 10),
                _buildVentasHero(),
                const SizedBox(height: 10),
                _buildGraficaVentas(),

                const SizedBox(height: 28),

                // ── ESTADO DE PEDIDOS ─────────────────────────────────────
                _buildSectionHeader("Estado de pedidos", _periodoPedidos, 'pedidos'),
                const SizedBox(height: 10),
                _buildPedidos(),

                const SizedBox(height: 28),

                // ── PRODUCTOS MÁS VENDIDOS ────────────────────────────────
                _buildSectionHeader("Productos más vendidos", _periodoProductos, 'productos'),
                const SizedBox(height: 10),
                _buildTopProductos(),

                const SizedBox(height: 28),

                // ── CLIENTE FRECUENTE ─────────────────────────────────────
                ..._buildClienteFrecuente(),

                // ── ALERTA STOCK ──────────────────────────────────────────
                ..._buildStockBajo(),

                // ── INVENTARIO MP ─────────────────────────────────────────
                const _SectionLabel("Inventario de materia prima"),
                const SizedBox(height: 10),
                _buildInventarioMP(),

                const SizedBox(height: 28),

                // ── RENDIMIENTO MP ────────────────────────────────────────
                _buildSectionHeader("Rendimiento de materia prima", _periodoProductos, 'productos'),
                const SizedBox(height: 6),
                Text("Ingresos generados por unidad de insumo utilizada",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 10),
                _buildRendimiento(),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER CON FILTRO INLINE ──────────────────────────────────────
  Widget _buildSectionHeader(String titulo, String periodoActual, String tipo) {
    return Row(
      children: [
        Expanded(
          child: Text(titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B4332))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['semana', 'mes', 'año'].map((p) {
              final sel = periodoActual == p;
              return GestureDetector(
                onTap: () => _setPeriodo(tipo, p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    p[0].toUpperCase() + p.substring(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sel ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── VENTAS HERO ────────────────────────────────────────────────────────────
  Widget _buildVentasHero() {
    final d = _d(_periodoVentas);
    if (d == null) return _loadingCard();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkCard, primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total · ${_label(_periodoVentas)}",
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("\$${_fmt(d['total_periodo'])}",
                      style: const TextStyle(color: Colors.white, fontSize: 36,
                        fontWeight: FontWeight.bold, letterSpacing: -1)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: "Hoy", value: "\$${_fmt(d['total_hoy'])}"),
              _HeroStatDivider(),
              _HeroStat(label: "Ticket prom.", value: "\$${_fmt(d['ticket_prom'])}"),
              _HeroStatDivider(),
              _HeroStat(label: "Clientes", value: "${d['total_clientes'] ?? 0}"),
            ],
          ),
        ],
      ),
    );
  }

  // ── GRÁFICA DE VENTAS ──────────────────────────────────────────────────────
  Widget _buildGraficaVentas() {
    final d = _d(_periodoVentas);
    if (d == null) return _loadingCard();
    final List ventasDia = d['ventas_por_dia'] ?? [];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text("Últimos 7 días",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B4332))),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ventasDia.isEmpty
                ? Center(child: Text("Sin datos", style: TextStyle(color: Colors.grey.shade400)))
                : LineChart(_buildLineData(ventasDia)),
          ),
        ],
      ),
    );
  }

  // ── PEDIDOS ────────────────────────────────────────────────────────────────
  Widget _buildPedidos() {
    final d = _d(_periodoPedidos);
    if (d == null) return _loadingCard();
    final int completados = d['completados'] ?? 0;
    final int pendientes  = d['pendientes']  ?? 0;
    final int cancelados  = d['cancelados']  ?? 0;
    final int enCamino    = d['en_camino']   ?? 0;
    final int total = completados + pendientes + cancelados + enCamino;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PedidoBadge(label: "Entregados", count: completados, color: const Color(0xFF40916C)),
              _PedidoBadge(label: "Pendientes", count: pendientes,  color: const Color(0xFFE76F51)),
              _PedidoBadge(label: "En camino",  count: enCamino,    color: const Color(0xFF4895EF)),
              _PedidoBadge(label: "Cancelados", count: cancelados,  color: const Color(0xFFE63946)),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 20),
            _buildBarRow("Entregados", completados, total, const Color(0xFF40916C)),
            const SizedBox(height: 10),
            _buildBarRow("Pendientes", pendientes,  total, const Color(0xFFE76F51)),
            const SizedBox(height: 10),
            _buildBarRow("En camino",  enCamino,    total, const Color(0xFF4895EF)),
            const SizedBox(height: 10),
            _buildBarRow("Cancelados", cancelados,  total, const Color(0xFFE63946)),
          ],
        ],
      ),
    );
  }

  // ── TOP PRODUCTOS ──────────────────────────────────────────────────────────
  Widget _buildTopProductos() {
    final d = _d(_periodoProductos);
    if (d == null) return _loadingCard();
    final List top = d['top_productos'] ?? [];
    if (top.isEmpty) return _emptyCard("Sin ventas en este período");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: top.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final double maxV = (top.first['total_vendido'] as num).toDouble();
          final double v    = (p['total_vendido'] as num).toDouble();
          final List<Color> rankColors = [
            const Color(0xFFFFB703),
            Colors.grey.shade400,
            const Color(0xFFCD7F32),
            primary.withOpacity(0.6),
            primary.withOpacity(0.4),
          ];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: rankColors[i].withOpacity(0.15), shape: BoxShape.circle),
                      child: Center(child: Text('${i+1}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColors[i]))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p['producto__nombre'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                    Text("${p['total_vendido']} uds",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV > 0 ? v / maxV : 0,
                    backgroundColor: Colors.grey.shade100,
                    color: rankColors[i],
                    minHeight: 7,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 14),
                  child: Text("\$${_fmt(p['ingreso'])}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ),
                if (i < top.length - 1) Divider(height: 1, color: Colors.grey.shade100),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── CLIENTE FRECUENTE ──────────────────────────────────────────────────────
  List<Widget> _buildClienteFrecuente() {
    final d = _d(_periodoProductos);
    if (d == null || d['cliente_top'] == null) return [];
    final c = d['cliente_top'];
    return [
      const _SectionLabel("Cliente más frecuente"),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.star_rounded, color: Colors.amber, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['cliente_nombre'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("${c['pedidos']} pedidos en el período",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
    ];
  }

  // ── STOCK BAJO ─────────────────────────────────────────────────────────────
  List<Widget> _buildStockBajo() {
    final d = _d(_periodoVentas);
    if (d == null) return [];
    final List stock = d['stock_bajo'] ?? [];
    if (stock.isEmpty) return [];
    return [
      const _SectionLabel("⚠ Alerta de stock"),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: stock.map((p) {
            final int s = (p['stock_actual'] as num).toInt();
            final bool agotado = s == 0;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: agotado ? Colors.red.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded,
                  color: agotado ? Colors.red : Colors.orange, size: 20),
              ),
              title: Text(p['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: agotado ? Colors.red.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$s uds",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                    color: agotado ? Colors.red.shade700 : Colors.orange.shade700)),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 28),
    ];
  }

  // ── INVENTARIO MP ──────────────────────────────────────────────────────────
  Widget _buildInventarioMP() {
    final d = _d(_periodoVentas);
    if (d == null) return _loadingCard();
    final List materias = d['materias_primas'] ?? [];
    if (materias.isEmpty) return _emptyCard("Sin materias primas registradas");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: materias.asMap().entries.map((e) {
          final m = e.value;
          final num s = m['stock_actual'] as num;
          final bool sinStock = s == 0;
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
                Text(m['unidad_medida'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── RENDIMIENTO MP ─────────────────────────────────────────────────────────
  Widget _buildRendimiento() {
    final d = _d(_periodoProductos);
    if (d == null) return _loadingCard();
    final List rend = d['rendimiento_mp'] ?? [];
    if (rend.isEmpty) return _emptyCard("Sin datos de movimientos en este período");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: rend.map((r) {
          final double? rendVal = r['rendimiento_por_unidad'] != null
              ? (r['rendimiento_por_unidad'] as num).toDouble() : null;
          final bool tieneSalidas = (r['salidas'] as num) > 0;
          final String rendStr = rendVal != null
              ? "\$$rendVal / ${r['unidad']}"
              : tieneSalidas ? "Sin ventas en período" : "Sin salidas registradas";
          final Color rendColor = rendVal == null ? Colors.grey
              : rendVal >= 100 ? const Color(0xFF40916C)
              : rendVal >= 50  ? const Color(0xFFE76F51)
              : const Color(0xFFE63946);
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
                Row(children: [
                  _MiniStat(label: "Entradas", value: "${r['entradas']} ${r['unidad']}"),
                  _MiniStat(label: "Salidas",  value: "${r['salidas']} ${r['unidad']}"),
                  _MiniStat(label: "Stock",    value: "${r['stock_actual']} ${r['unidad']}"),
                  _MiniStat(label: "Inversión", value: "\$${r['costo_entrada'] ?? 0}"),
                ]),
                if (rend.last != r) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade100, height: 1),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  LineChartData _buildLineData(List ventasDia) {
    final spots = ventasDia.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['total'] as num).toDouble())
    ).toList();
    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return LineChartData(
      gridData: FlGridData(
        show: true, drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (val, _) => Text(
              "\$${_fmt(val)}",
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
          ),
        ),
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
                child: Text(ventasDia[idx]['dia'],
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY > 0 ? maxY * 1.25 : 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: primary,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, pct, bar, idx) {
              final isMax = spot.y == maxY && maxY > 0;
              return FlDotCirclePainter(
                radius: isMax ? 6 : 3.5,
                color: isMax ? accent : primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [primary.withOpacity(0.18), primary.withOpacity(0.0)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarRow(String label, int value, int total, Color color) {
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? value / total : 0,
              backgroundColor: Colors.grey.shade100,
              color: color, minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 24,
          child: Text('$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _loadingCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2)),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(msg, textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    );
  }

  String _fmt(dynamic val) {
    if (val == null) return '0';
    final d = double.tryParse(val.toString()) ?? 0;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}k';
    return d.toStringAsFixed(0);
  }
}

// ── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B4332)));
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}

class _HeroStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 28, color: Colors.white.withOpacity(0.15),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}

class _PedidoBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _PedidoBadge({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B4332)),
        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
    ]),
  );
}