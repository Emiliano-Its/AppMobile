import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart'; 
import '../api_config.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class FinalProductsScreen extends StatefulWidget {
  const FinalProductsScreen({super.key});

  @override
  State<FinalProductsScreen> createState() => _FinalProductsScreenState();
}

class _FinalProductsScreenState extends State<FinalProductsScreen> {
  List<dynamic> _allProducts = []; 
  List<dynamic> _filteredProducts = []; 
  bool _isLoading = true;

  // --- CORRECCIÓN 1: Usamos la constante centralizada ---
  final String apiUrl = ApiConfig.products;

  @override
  void initState() {
    super.initState();
    _fetchProductos();
  }

  // --- ESCANEAR PARA SUMAR (CORREGIDO CON FILTRO DE ESTABILIDAD) ---
Future<void> _abrirEscanerParaSumar() async {
  final MobileScannerController scannerController = MobileScannerController(
    formats: [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final String? codigoDetectado = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("Escaneando Producto", style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.verdeBosque,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? rawValue = barcode.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    Navigator.pop(context, rawValue);
                    break;
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 280, height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const Positioned(
              bottom: 80, left: 0, right: 0,
              child: Text(
                "Enfoca el código de barras dentro del rectángulo",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // Dispose SIEMPRE aquí, una sola vez
  scannerController.dispose();

  if (!mounted) return;

  if (codigoDetectado != null) {
    _buscarYSumarStock(codigoDetectado);
  }
}
  // --- CORRECCIÓN 2: Búsqueda usando ApiConfig.searchByCode ---
Future<void> _buscarYSumarStock(String codigo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('access_token') ?? '';
    final response = await http.get(
      Uri.parse('${ApiConfig.searchByCode}?codigo=$codigo'),
      headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      // SI EXISTE: Directo a sumar stock
      final producto = json.decode(response.body);
      _mostrarDialogoSuma(producto);
    } else {
      // SI NO EXISTE: Preguntamos antes de abrir el formulario
      _mostrarDialogoConfirmarRegistro(codigo);
    }
  } catch (e) {
    _showSnackBar("Error de conexión con el servidor", Colors.red);
  }
}

// NUEVO: Diálogo de interrupción para preguntar al usuario
void _mostrarDialogoConfirmarRegistro(String codigo) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          // Usamos Flexible para que el título no cause overflow si es largo
          Flexible(
            child: Text(
              "Producto Nuevo",
              style: TextStyle(color: AppColors.verdeBosque, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      // --- LA SOLUCIÓN AL OVERFLOW ESTÁ AQUÍ ---
      content: SingleChildScrollView( 
        child: Column(
          mainAxisSize: MainAxisSize.min, // Importante para diálogos
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Este producto no existe en la base de datos:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                codigo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  letterSpacing: 1.5,
                  color: Colors.black87
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text("¿Deseas registrarlo ahora para gestionar su stock?"),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.verdeBosque,
            shape: const StadiumBorder(),
            elevation: 2,
          ),
          onPressed: () {
            Navigator.pop(context);
            _showFormDialog(nuevoCodigoEscanedado: codigo);
          },
          child: const Text("SÍ, REGISTRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

  void _mostrarDialogoSuma(dynamic producto) {
    final cantidadCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Sumar stock: ${producto['nombre']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Stock actual: ${producto['stock_actual']}"),
            const SizedBox(height: 15),
            TextField(
              controller: cantidadCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Cantidad a agregar",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.verdeBosque),
            onPressed: () {
              int cantidadASumar = int.tryParse(cantidadCtrl.text) ?? 0;
              int stockAnterior = int.parse(producto['stock_actual'].toString());
              int nuevoStockTotal = stockAnterior + cantidadASumar;
              
              Navigator.pop(context);

              _saveProduct(
                producto['nombre'],
                producto['codigo_barras'],
                producto['precio_venta'].toString(),
                nuevoStockTotal.toString(),
                true, // isEditing
                producto['activo'] ?? true, // <--- PASAMOS SU ESTADO ACTUAL
                id: producto['id']
              );
            },
            child: const Text("SUMAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- OBTENER PRODUCTOS ---
  Future<void> _fetchProductos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _allProducts = json.decode(response.body);
          _filteredProducts = _allProducts; 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando productos: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts
          .where((p) => p['nombre'].toLowerCase().contains(query.toLowerCase()) || 
                        p['codigo_barras'].contains(query))
          .toList();
    });
  }

  // --- CORRECCIÓN 3: Guardar con Headers y URL corregida ---
// --- MODIFICACIÓN: Agregamos el parámetro bool isActive ---
Future<void> _saveProduct(String name, String code, String price, String stock, bool isEditing, bool isActive, {int? id, bool deleteImage = false}) async {
  setState(() => _isLoading = true);

  final url = isEditing ? Uri.parse('$apiUrl$id/') : Uri.parse(apiUrl);
  var request = http.MultipartRequest(isEditing ? 'PUT' : 'POST', url);

  final prefs = await SharedPreferences.getInstance();
  final String token = prefs.getString('access_token') ?? '';
  request.headers.addAll({
    ...ApiConfig.headers,
    'Authorization': 'Token $token',
  });

  request.fields['nombre'] = name;
  request.fields['codigo_barras'] = code;
  request.fields['precio_venta'] = price;
  request.fields['stock_actual'] = stock;
  request.fields['activo'] = isActive.toString();

  if (_imageFile != null) {
    // Subir nueva imagen
    request.files.add(await http.MultipartFile.fromPath(
      'imagen',
      _imageFile!.path,
      contentType: MediaType('image', 'jpeg'),
    ));
  } else if (deleteImage && isEditing) {
    // Indicarle a Django que borre la imagen existente
    request.fields['imagen'] = '';
  }

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      _fetchProductos();
      _showSnackBar("¡Producto guardado con éxito!", Colors.green);
      _imageFile = null;
    } else {
      _showSnackBar("Error en el servidor: ${response.body}", Colors.red);
    }
  } catch (e) {
    _showSnackBar("Error de red al conectar con servidor", Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}

  // --- TOGGLE ACTIVO ---
  Future<void> _toggleProductStatus(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.post(
        Uri.parse('$apiUrl$id/toggle_active/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 200) {
        _fetchProductos();
        _showSnackBar("Estado del producto actualizado", AppColors.verdeBosque);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- ELIMINAR PERMANENTE ---
  Future<void> _deleteProduct(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('access_token') ?? '';
      final response = await http.delete(
        Uri.parse('$apiUrl$id/'),
        headers: {...ApiConfig.headers, 'Authorization': 'Token $token'},
      );
      if (response.statusCode == 204) {
        _fetchProductos();
        _showSnackBar("Producto eliminado permanentemente", Colors.orange);
      } else {
        _showSnackBar("No se puede borrar: Registro protegido.", Colors.red);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- UI SNACKBAR Y DIÁLOGOS ---
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar Producto"),
        content: Text("¿Deseas eliminar '$name'? Esta acción es irreversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(id);
            }, 
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))
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
        title: const Text("Inventario Final", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.verdeBosque,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
            onPressed: _abrirEscanerParaSumar,
            tooltip: "Escanear para sumar stock",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.verdeBosque))
              : RefreshIndicator(
                  onRefresh: _fetchProductos,
                  child: _filteredProducts.isEmpty 
                    ? const Center(child: Text("No hay productos registrados"))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(_filteredProducts[index]);
                        },
                      ),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.verdeBosque,
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: AppColors.verdeBosque,
      child: TextField(
        onChanged: _filterProducts,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: "Nombre o código...",
          prefixIcon: const Icon(Icons.search, color: AppColors.verdeBosque),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic item) {
    final bool estaActivo = item['activo'] ?? true;
    final int stock = item['stock_actual'] ?? 0;
    final bool stockBajo = stock > 0 && stock < 5;
    final bool sinStock  = stock == 0;
    final Color stockColor = sinStock ? Colors.red : stockBajo ? Colors.orange : AppColors.verdeBosque;

    return Opacity(
      opacity: estaActivo ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFormDialog(producto: item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Imagen o ícono
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60, height: 60,
                    color: Colors.grey.shade100,
                    child: item['imagen_url'] != null
                        ? Image.network(
                            ApiConfig.getImageUrl(item['imagen_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.bakery_dining_rounded, size: 30, color: Colors.orange),
                          )
                        : const Icon(Icons.bakery_dining_rounded, size: 30, color: Colors.orange),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item['nombre'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (!estaActivo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("pausado", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("\$${item['precio_venta']}",
                        style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.verdeBosque, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 13, color: stockColor),
                          const SizedBox(width: 4),
                          Text("$stock uds",
                            style: TextStyle(fontSize: 12, color: stockColor, fontWeight: FontWeight.w500)),
                          if (sinStock || stockBajo) ...[
                            const SizedBox(width: 6),
                            Text(sinStock ? "· Sin stock" : "· Stock bajo",
                              style: TextStyle(fontSize: 11, color: stockColor)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Acciones
                Column(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        estaActivo ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                        color: estaActivo ? Colors.orange : Colors.green,
                        size: 26,
                      ),
                      onPressed: () => _toggleProductStatus(item['id']),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      onPressed: () => _confirmDelete(item['id'], item['nombre']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 // Añadimos el parámetro opcional 'nuevoCodigoEscanedado'
void _showFormDialog({dynamic producto, String? nuevoCodigoEscanedado}) {
  final bool isEditing = producto != null;
  

  if (!isEditing) _imageFile = null;
  bool deleteImage = false;

  final nombreCtrl = TextEditingController(text: isEditing ? producto['nombre'] : '');
  final codigoCtrl = TextEditingController(
    text: isEditing ? producto['codigo_barras'] : (nuevoCodigoEscanedado ?? '')
  );
  final precioCtrl = TextEditingController(text: isEditing ? producto['precio_venta'].toString() : '');
  final stockCtrl = TextEditingController(text: isEditing ? producto['stock_actual'].toString() : '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.fondoHueso,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
          left: 25, right: 25, top: 25
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "Editar Producto" : "Nuevo Producto", 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.verdeBosque)
              ),
              const SizedBox(height: 20),

              // --- SECCIÓN DE IMAGEN ---
              StatefulBuilder(
                builder: (context, setImageState) {
                  final bool tieneImagen = _imageFile != null ||
                      (isEditing && producto['imagen_url'] != null && !deleteImage);
                  return Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await _pickImage();
                              setImageState(() { deleteImage = false; });
                              setModalState(() {});
                            },
                            child: Container(
                              height: 130, width: 130,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.verdeBosque.withOpacity(0.3), width: 2),
                              ),
                              child: _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                                    )
                                  : (isEditing && producto['imagen_url'] != null && !deleteImage)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Image.network(
                                            ApiConfig.getImageUrl(producto['imagen_url']),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                          ),
                                        )
                                      : const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo, size: 40, color: AppColors.verdeBosque),
                                            SizedBox(height: 5),
                                            Text("Subir foto", style: TextStyle(fontSize: 12, color: AppColors.verdeBosque)),
                                          ],
                                        ),
                            ),
                          ),
                          // Botón X para borrar imagen
                          if (tieneImagen)
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setImageState(() {
                                    _imageFile = null;
                                    deleteImage = true;
                                  });
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (tieneImagen)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text("Toca para cambiar · X para borrar",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 25),

              // --- CAMPOS DE TEXTO ---
              _buildInput("Nombre del producto", nombreCtrl),
              _buildInput("Código de Barras", codigoCtrl), 
              Row(
                children: [
                  Expanded(child: _buildInput("Precio", precioCtrl, isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildInput("Stock Inicial", stockCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 30),

              // --- BOTÓN DE ACCIÓN ---
              // --- BOTÓN DE ACCIÓN DENTRO DEL FORMULARIO ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeBosque, 
                    shape: const StadiumBorder()
                  ),
                  onPressed: () {
                    if (nombreCtrl.text.isNotEmpty && precioCtrl.text.isNotEmpty) {
                      _saveProduct(
                        nombreCtrl.text,
                        codigoCtrl.text,
                        precioCtrl.text,
                        stockCtrl.text,
                        isEditing,
                        isEditing ? (producto['activo'] ?? true) : true,
                        id: isEditing ? producto['id'] : null,
                        deleteImage: deleteImage,
                      );
                      Navigator.pop(context);
                    } else {
                      _showSnackBar("Nombre y precio son obligatorios", Colors.red);
                    }
                  },
                  child: Text(
                    isEditing ? "ACTUALIZAR DATOS" : "REGISTRAR EN BASE DE DATOS", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
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

  File? _imageFile; 
final ImagePicker _picker = ImagePicker();

Future<void> _pickImage() async {
  final XFile? pickedFile = await _picker.pickImage(
    source: ImageSource.gallery, 
    imageQuality: 50, 
  );

  if (pickedFile != null) {
    setState(() {
      _imageFile = File(pickedFile.path);
    });
  }
}
}