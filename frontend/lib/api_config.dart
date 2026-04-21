class ApiConfig {
  // 1. IP de tu servidor Debian (Asegúrate de que sea la correcta en tu red actual)
  static const String serverIp = "192.168.100.13"; 
  static const String port = "8000";

  // --- BASE PARA MEDIOS Y API ---
  static const String serverBase = "http://$serverIp:$port";
  static const String baseUrl = "$serverBase/api";

  // --- ENDPOINTS ---
  static const String login = "$baseUrl/users/login/";
  static const String products = "$baseUrl/FinalProduct/";
  static const String searchByCode = "${products}buscar_por_codigo/";
  static const String rawMaterials = "$baseUrl/raw-materials/";
  static const String inventoryMovements = "$baseUrl/inventory-movements/";
  static const String sales = "$baseUrl/sales/";
  
  // Endpoint para el cambio de contraseña (Seguridad)
  static const String changePassword = "$baseUrl/users/change-password/";
  static const String userProfile = "$baseUrl/users/profile/";

  // --- CONFIGURACIÓN DE CABECERAS ---
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // --- FUNCIÓN PARA GESTIONAR URL DE IMÁGENES ---
  static String getImageUrl(String? urlPath) {
    if (urlPath == null || urlPath.isEmpty) return "";
    
    // Si la URL ya es completa (empieza con http), se usa tal cual
    if (urlPath.startsWith('http')) return urlPath;
    
    // Si es una ruta relativa, se concatena con la base del servidor
    final cleanPath = urlPath.startsWith('/') ? urlPath : '/$urlPath';
    return "$serverBase$cleanPath";
  }
}