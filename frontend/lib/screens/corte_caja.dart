import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_config.dart';

class CorteCajaScreen extends StatefulWidget {
  const CorteCajaScreen({super.key});

  @override
  State<CorteCajaScreen> createState() => _CorteCajaScreenState();
}

class _CorteCajaScreenState extends State<CorteCajaScreen> {
  List<dynamic> _allSales = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  // --- CAMBIO 1: Usamos la constante de ApiConfig ---
  final String _baseSalesUrl = ApiConfig.sales;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX', null); 
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse(_baseSalesUrl),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _allSales = json.decode(response.body);
        });
      }
    } catch (e) {
      _showSnackBar("Error al conectar con el servidor Debian", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ... (El resto de la lógica de filtrado y cálculo se mantiene igual) ...
  List<dynamic> get _filteredSales {
    return _allSales.where((sale) {
      DateTime saleDate = DateTime.parse(sale['fecha']);
      return saleDate.year == _selectedDate.year &&
             saleDate.month == _selectedDate.month &&
             saleDate.day == _selectedDate.day &&
             sale['tipo'] == 'LOCAL';
    }).toList();
  }

  double _calculateTotalByType(String typeLabel) {
    return _filteredSales.where((s) {
      if (typeLabel == 'MOSTRADOR') return s['cliente_nombre'] == 'Venta Mostrador';
      return s['cliente_nombre'] != 'Venta Mostrador';
    }).fold(0, (prev, s) => prev + double.parse(s['total'].toString()));
  }

  @override
  Widget build(BuildContext context) {
    double totalMostrador = _calculateTotalByType('MOSTRADOR');
    double totalEntregas = _calculateTotalByType('ENTREGAS');
    double totalGeneral = totalMostrador + totalEntregas;

    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Corte de Caja", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => _selectDate(context),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
        : Column(
            children: [
              _buildHeaderSummary(totalGeneral, totalMostrador, totalEntregas),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.grey, size: 20),
                    SizedBox(width: 10),
                    Text("DETALLE DE MOVIMIENTOS", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  ],
                ),
              ),
              Expanded(child: _buildSalesList()),
            ],
          ),
    );
  }

  Widget _buildHeaderSummary(double total, double mostrador, double entregas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: AppColors.verdeBosque,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Text(DateFormat('dd / MMMM / yyyy', 'es_MX').format(_selectedDate).toUpperCase(), 
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          const Text("EFECTIVO TOTAL EN CAJA", 
            style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1)),
          Text("\$${total.toStringAsFixed(2)}", 
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem("Mostrador", mostrador, Icons.storefront),
              _summaryItem("Entregas", entregas, Icons.delivery_dining),
            ],
          )
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double amount, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 28),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text("\$${amount.toStringAsFixed(2)}", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }

  Widget _buildSalesList() {
    final sales = _filteredSales.reversed.toList();
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text("No hay movimientos este día", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: sales.length,
      itemBuilder: (context, i) {
        final s = sales[i];
        bool isMostrador = s['cliente_nombre'] == 'Venta Mostrador';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: CircleAvatar(
              backgroundColor: isMostrador ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Icon(
                isMostrador ? Icons.account_balance_wallet : Icons.local_shipping,
                color: isMostrador ? Colors.blue : Colors.orange,
              ),
            ),
            title: Text(s['cliente_nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('hh:mm a').format(DateTime.parse(s['fecha']))),
            trailing: Text("\$${s['total']}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.verdeBosque)),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'), 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.verdeBosque, 
              onPrimary: Colors.white, 
              onSurface: AppColors.tituloNegro, 
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.verdeBosque),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnackBar(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }
}