import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart'; 
import '../api_config.dart';

class RawMaterialScreen extends StatefulWidget {
  const RawMaterialScreen({super.key});

  @override
  State<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends State<RawMaterialScreen> {
  List<dynamic> insumos = [];
  bool _isLoading = true;
  final String apiUrl = ApiConfig.rawMaterials;

  @override
  void initState() {
    super.initState();
    _fetchInsumos();
  }

  Future<void> _fetchInsumos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          insumos = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando insumos: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInsumo({
    required String name,
    required String code,
    required String qty,
    required String unit,
    required String price,
    required bool isEditing,
    int? id,
    bool fromScanner = false,
    double? stockAnterior, // para calcular el movimiento
    String? tipoMovimiento, // ENTRADA o SALIDA forzado (desde scanner)
  }) async {
    final url = isEditing ? Uri.parse('$apiUrl$id/') : Uri.parse(apiUrl);

    final Map<String, dynamic> data = {
      "nombre": name,
      "codigo_barras": code,
      "unidad_medida": unit,
      "stock_actual": double.parse(qty),
      "precio_ultimo_ingreso": double.parse(price),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final authHeaders = {...ApiConfig.headers, 'Authorization': 'Token $token'};

      final response = isEditing
          ? await http.put(url, headers: authHeaders, body: jsonEncode(data))
          : await http.post(url, headers: authHeaders, body: jsonEncode(data));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registrar movimiento si es una edición con cambio de stock
        if (isEditing && id != null && stockAnterior != null) {
          final double nuevoStock = double.parse(qty);
          final double diferencia = (nuevoStock - stockAnterior).abs();
          final String tipo = tipoMovimiento ??
              (nuevoStock >= stockAnterior ? 'ENTRADA' : 'SALIDA');

          if (diferencia > 0) {
            await http.post(
              Uri.parse(ApiConfig.inventoryMovements),
              headers: authHeaders,
              body: jsonEncode({
                'materia_prima': id,
                'tipo': tipo,
                'cantidad': diferencia,
                'comentario': tipo == 'ENTRADA'
                    ? 'Entrada registrada desde app'
                    : 'Salida registrada desde app',
              }),
            );
          }
        }

        if (mounted && !fromScanner) Navigator.pop(context);
        _fetchInsumos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text("¡Inventario actualizado!")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    }
  }

  void _openScanner(bool isEntrada) async {
    final MobileScannerController ctrl = MobileScannerController(
      formats: [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    final String? codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              isEntrada ? "Escanear Entrada" : "Escanear Salida",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.verdeBosque,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              MobileScanner(
                controller: ctrl,
                onDetect: (capture) {
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null) {
                    ctrl.dispose();
                    Navigator.pop(context, code);
                  }
                },
              ),
              // Recuadro de guía
              Center(
                child: Container(
                  width: 280,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              // Líneas de esquina decorativas
              Center(
                child: SizedBox(
                  width: 280,
                  height: 150,
                  child: Stack(
                    children: [
                      _corner(0, 0, true, true),
                      _corner(0, null, true, false),
                      _corner(null, 0, false, true),
                      _corner(null, null, false, false),
                    ],
                  ),
                ),
              ),
              const Positioned(
                bottom: 60,
                left: 0, right: 0,
                child: Text(
                  "Centra el código de barras en el recuadro",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    ctrl.dispose();

    if (!mounted) return;

    if (codigo == null) return;

    final insumo = insumos.firstWhere(
      (item) => item['codigo_barras'] == codigo,
      orElse: () => null,
    );

    if (insumo != null) {
      _showQuantityDialog(insumo, isEntrada);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text("No se encontró el código: $codigo"),
        ),
      );
    }
  }

  Widget _corner(double? top, double? bottom, bool left, bool alignLeft) {
    return Positioned(
      top: top, bottom: bottom,
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: top == 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            bottom: bottom == 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            left: alignLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            right: alignLeft ? BorderSide.none : const BorderSide(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }

  // --- 4. DIÁLOGO DE CANTIDAD ---
  void _showQuantityDialog(dynamic insumo, bool isEntrada) {
    final TextEditingController cantCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEntrada ? "Entrada: ${insumo['nombre']}" : "Salida: ${insumo['nombre']}"),
        content: TextField(
          controller: cantCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: "¿Qué cantidad?",
            suffixText: insumo['unidad_medida'],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isEntrada ? AppColors.verdeBosque : Colors.redAccent),
            onPressed: () {
              double cant = double.tryParse(cantCtrl.text) ?? 0;
              double stockActual = double.parse(insumo['stock_actual'].toString());
              double nuevoStock = isEntrada ? stockActual + cant : stockActual - cant;

              if (nuevoStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock insuficiente")));
                return;
              }

              Navigator.pop(context);
              _saveInsumo(
                name: insumo['nombre'],
                code: insumo['codigo_barras'],
                qty: _formatNum(nuevoStock),
                unit: insumo['unidad_medida'],
                price: _formatNum(insumo['precio_ultimo_ingreso']),
                isEditing: true,
                id: insumo['id'],
                fromScanner: true,
                stockAnterior: stockActual,
                tipoMovimiento: isEntrada ? 'ENTRADA' : 'SALIDA',
              );
            },
            child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Materia Prima", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
          : Column(
              children: [
                // Header con resumen
                Container(
                  color: AppColors.verdeBosque,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      _ResumenItem(
                        label: "Total insumos",
                        value: "${insumos.length}",
                        icon: Icons.inventory_2_rounded,
                      ),
                      _ResumenItem(
                        label: "Stock bajo",
                        value: "${insumos.where((i) => (double.tryParse(i['stock_actual'].toString()) ?? 0) < 5 && (double.tryParse(i['stock_actual'].toString()) ?? 0) > 0).length}",
                        icon: Icons.warning_rounded,
                      ),
                      _ResumenItem(
                        label: "Sin stock",
                        value: "${insumos.where((i) => (double.tryParse(i['stock_actual'].toString()) ?? 0) == 0).length}",
                        icon: Icons.remove_circle_rounded,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, left: 15, right: 15, top: 15),
                    itemCount: insumos.length,
                    itemBuilder: (context, index) => _buildInsumoCard(insumos[index]),
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton.extended(
              heroTag: "salida",
              onPressed: () => _openScanner(false),
              backgroundColor: Colors.redAccent,
              label: const Text("SALIDA", style: TextStyle(color: Colors.white)),
              icon: const Icon(Icons.remove_circle, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: "nuevo",
              onPressed: () => _showFormManual(),
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
            FloatingActionButton.extended(
              heroTag: "entrada",
              onPressed: () => _openScanner(true),
              backgroundColor: AppColors.verdeBosque,
              label: const Text("ENTRADA", style: TextStyle(color: Colors.white)),
              icon: const Icon(Icons.add_circle, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsumoCard(dynamic item) {
    final double stock = double.tryParse(item['stock_actual'].toString()) ?? 0;
    final bool stockBajo = stock > 0 && stock < 5;
    final bool sinStock  = stock == 0;
    final Color stockColor = sinStock ? Colors.red : stockBajo ? Colors.orange : AppColors.verdeBosque;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showFormManual(insumo: item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stockColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.grain_rounded, color: stockColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      "Último precio: \$${item['precio_ultimo_ingreso']} / ${item['unidad_medida']}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (sinStock || stockBajo) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warning_rounded, size: 12, color: stockColor),
                          const SizedBox(width: 4),
                          Text(
                            sinStock ? "Sin stock" : "Stock bajo",
                            style: TextStyle(fontSize: 11, color: stockColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stock == stock.truncateToDouble()
                        ? stock.toInt().toString()
                        : stock.toString(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stockColor),
                  ),
                  Text(item['unidad_medida'],
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. FORMULARIO MANUAL (CREAR O EDITAR) ---
  void _showFormManual({dynamic insumo}) {
    final bool isEditing = insumo != null;
    
    // Controladores con los datos si estamos editando
    final nombreCtrl = TextEditingController(text: isEditing ? insumo['nombre'] : '');
    final codigoCtrl = TextEditingController(text: isEditing ? insumo['codigo_barras'] : '');
    final cantidadCtrl = TextEditingController(text: isEditing ? _formatNum(insumo['stock_actual']) : '');
    final unidadCtrl = TextEditingController(text: isEditing ? insumo['unidad_medida'] : '');
    final precioCtrl = TextEditingController(text: isEditing ? _formatNum(insumo['precio_ultimo_ingreso']) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoHueso,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
          left: 25, right: 25, top: 25
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? "Editar Insumo" : "Nuevo Insumo", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)
                ),
                if (isEditing) const Icon(Icons.edit, color: AppColors.verdeBosque)
              ],
            ),
            const SizedBox(height: 20),
            _buildInput("Código de Barras", codigoCtrl),
            _buildInput("Nombre de la Materia Prima", nombreCtrl),
            Row(
              children: [
                Expanded(child: _buildInput("Stock Actual", cantidadCtrl, isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildInput("Unidad (kg, Bulto, L)", unidadCtrl)),
              ],
            ),
            _buildInput("Precio Último Ingreso", precioCtrl, isNumber: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeBosque, 
                  shape: const StadiumBorder()
                ),
                onPressed: () {
                  if (nombreCtrl.text.isNotEmpty && codigoCtrl.text.isNotEmpty) {
                    _saveInsumo(
                      name: nombreCtrl.text,
                      code: codigoCtrl.text,
                      qty: cantidadCtrl.text,
                      unit: unidadCtrl.text,
                      price: precioCtrl.text,
                      isEditing: isEditing,
                      id: isEditing ? insumo['id'] : null,
                      stockAnterior: isEditing
                          ? double.tryParse(insumo['stock_actual'].toString())
                          : null,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nombre y Código son obligatorios")),
                    );
                  }
                },
                child: Text(isEditing ? "ACTUALIZAR" : "GUARDAR INSUMO", 
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para los campos de texto
  Widget _buildInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.verdeBosque),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.verdeBosque)),
        ),
      ),
    );
  }
  // Muestra entero si no tiene decimales, decimal si los tiene
  String _formatNum(dynamic val) {
    final d = double.tryParse(val.toString()) ?? 0;
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
  }
}

class _ResumenItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ResumenItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}