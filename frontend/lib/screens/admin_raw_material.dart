import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart'; 
import '../api_config.dart'; // Importación agregada

class RawMaterialScreen extends StatefulWidget {
  const RawMaterialScreen({super.key});

  @override
  State<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends State<RawMaterialScreen> {
  List<dynamic> insumos = [];
  bool _isLoading = true;

  // --- CAMBIO 1: Usamos la constante centralizada ---
  final String apiUrl = ApiConfig.rawMaterials;

  @override
  void initState() {
    super.initState();
    _fetchInsumos();
  }

  // --- 1. OBTENER INSUMOS (GET) ---
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

  // --- 2. GUARDAR O ACTUALIZAR (POST / PUT) ---
  Future<void> _saveInsumo({
    required String name,
    required String code,
    required String qty,
    required String unit,
    required String price,
    required bool isEditing,
    int? id,
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
      // --- CAMBIO 2: Usamos ApiConfig.headers para el Content-Type ---
      final response = isEditing
          ? await http.put(url, headers: ApiConfig.headers, body: jsonEncode(data))
          : await http.post(url, headers: ApiConfig.headers, body: jsonEncode(data));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.pop(context); 
        _fetchInsumos(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("¡Insumo guardado con éxito!")),
        );
      } else {
        debugPrint("Error de Django (400): ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: ${response.body}")),
        );
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoHueso,
      appBar: AppBar(
        title: const Text("Gestión de Materia Prima", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
          : RefreshIndicator(
              onRefresh: _fetchInsumos,
              child: insumos.isEmpty 
                ? const Center(child: Text("No hay insumos registrados"))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: insumos.length,
                    itemBuilder: (context, index) {
                      final item = insumos[index];
                      return _buildInsumoCard(item);
                    },
                  ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.verdeBosque,
        onPressed: () => _showFormInsumo(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInsumoCard(dynamic item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: AppColors.fondoHueso,
          child: const Icon(Icons.inventory_2, color: AppColors.verdeBosque),
        ),
        title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Stock: ${item['stock_actual']} ${item['unidad_medida']}\nCódigo: ${item['codigo_barras']}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("\$${item['precio_ultimo_ingreso']}", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.verdeBosque)),
            const Text("por unidad", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        onTap: () => _showFormInsumo(insumo: item),
      ),
    );
  }

  void _showFormInsumo({dynamic insumo}) {
    final bool isEditing = insumo != null;
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
            Text(
              isEditing ? "Editar Insumo" : "Nuevo Insumo", 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)
            ),
            const SizedBox(height: 20),
            _buildInput("Código de Barras", codigoCtrl),
            _buildInput("Nombre de la Materia Prima", nombreCtrl),
            Row(
              children: [
                Expanded(child: _buildInput("Stock Actual", cantidadCtrl, isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildInput("Unidad (kg, Bulto)", unidadCtrl)),
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

  Widget _buildInput(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.verdeBosque),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.verdeBosque)),
        ),
      ),
    );
  }
}