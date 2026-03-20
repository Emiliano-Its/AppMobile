class ApiConfig {
  // 1. IP de tu servidor Debian
  // Asegúrate de que tu máquina Debian siga teniendo esta IP (ip a)
  static const String serverIp = "192.168.100.13"; 
  static const String port = "8000";

  // 2. BASE URL 
  // La dejamos sin el slash final para evitar la doble diagonal "//" al concatenar
  static const String baseUrl = "http://$serverIp:$port/api";

  // --- ENDPOINTS ---
  
  // Login (Ya te funcionaba con 200 OK)
  static const String login = "$baseUrl/users/login/";

  // Productos Finales (Tostadas)
  // IMPORTANTE: Debe coincidir con router.register(r'FinalProduct', ...) de tu urls.py
  static const String products = "$baseUrl/FinalProduct/";
  
  // Búsqueda por código para el escáner
  // Ruta final: http://192.168.100.13:8000/api/FinalProduct/buscar_por_codigo/
  static const String searchByCode = "${products}buscar_por_codigo/";

  // Materia Prima (Insumos)
  static const String rawMaterials = "$baseUrl/raw-materials/";

  // Ventas y Pedidos
  // Coincide con router.register(r'sales', ...) de tu urls.py
  static const String sales = "$baseUrl/sales/";

  // --- CONFIGURACIÓN DE CABECERAS ---
  // Centralizar esto evita errores de "Unsupported Media Type" en Django
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}