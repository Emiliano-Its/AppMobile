import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart'; // Librería solicitada
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

  // --- 1. OBTENER INSUMOS DESDE DEBIAN ---
  Future<void> _fetchInsumos() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
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

  // --- 2. GUARDAR O ACTUALIZAR (API CALL) ---
  Future<void> _saveInsumo({
    required String name,
    required String code,
    required String qty,
    required String unit,
    required String price,
    required bool isEditing,
    int? id,
    bool fromScanner = false,
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
      final response = isEditing
          ? await http.put(url, headers: ApiConfig.headers, body: jsonEncode(data))
          : await http.post(url, headers: ApiConfig.headers, body: jsonEncode(data));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted && !fromScanner) Navigator.pop(context); 
        _fetchInsumos(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("¡Inventario actualizado!")),
        );
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    }
  }

  // --- 3. LÓGICA DE ESCANEO CON MOBILE_SCANNER ---
  void _openScanner(bool isEntrada) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(isEntrada ? "Escanear Entrada" : "Escanear Salida", style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.verdeBosque,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  // Cerramos la cámara
                  Navigator.pop(context);
                  // Procesamos el código encontrado
                  _procesarEscaneo(code, isEntrada);
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _procesarEscaneo(String code, bool isEntrada) {
    final insumo = insumos.firstWhere(
      (item) => item['codigo_barras'] == code,
      orElse: () => null,
    );

    if (insumo != null) {
      _showQuantityDialog(insumo, isEntrada);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.orange, content: Text("No se encontró el código: $code")),
      );
    }
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
                qty: nuevoStock.toString(),
                unit: insumo['unidad_medida'],
                price: insumo['precio_ultimo_ingreso'].toString(),
                isEditing: true,
                id: insumo['id'],
                fromScanner: true,
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
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, left: 15, right: 15, top: 15),
              itemCount: insumos.length,
              itemBuilder: (context, index) => _buildInsumoCard(insumos[index]),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Stock: ${item['stock_actual']} ${item['unidad_medida']}"),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showFormManual(insumo: item),
      ),
    );
  }

  // --- 5. FORMULARIO MANUAL (CREAR O EDITAR) ---
  void _showFormManual({dynamic insumo}) {
    final bool isEditing = insumo != null;
    
    // Controladores con los datos si estamos editando
    final nombreCtrl = TextEditingController(text: isEditing ? insumo['nombre'] : '');
    final codigoCtrl = TextEditingController(text: isEditing ? insumo['codigo_barras'] : '');
    final cantidadCtrl = TextEditingController(text: isEditing ? insumo['stock_actual'].toString() : '');
    final unidadCtrl = TextEditingController(text: isEditing ? insumo['unidad_medida'] : '');
    final precioCtrl = TextEditingController(text: isEditing ? insumo['precio_ultimo_ingreso'].toString() : '');

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
}