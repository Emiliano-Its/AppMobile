class ApiConfig {
  // 1. IP de tu servidor Debian
  static const String serverIp = "192.168.100.13"; 
  static const String port = "8000";

  // --- NUEVA BASE PARA MEDIOS ---
  // Las imágenes NO están dentro de /api/, están en la raíz del servidor
  static const String serverBase = "http://$serverIp:$port";

  // 2. BASE URL para la API
  static const String baseUrl = "$serverBase/api";

  // --- ENDPOINTS ---
  static const String login = "$baseUrl/users/login/";
  static const String products = "$baseUrl/FinalProduct/";
  static const String searchByCode = "${products}buscar_por_codigo/";
  static const String rawMaterials = "$baseUrl/raw-materials/";
  static const String sales = "$baseUrl/sales/";

  // --- CONFIGURACIÓN DE CABECERAS ---
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // --- FUNCIÓN DE UTILIDAD PARA IMÁGENES ---
  // Esta función evita el error 404 al asegurar que la URL sea completa y correcta
  static String getImageUrl(String? urlPath) {
    if (urlPath == null || urlPath.isEmpty) return "";
    
    // Si Django ya manda la URL completa (con http), la usamos tal cual
    if (urlPath.startsWith('http')) return urlPath;
    
    // Si viene relativa (/media/productos/...), le pegamos la IP del servidor
    // Aseguramos que no haya doble diagonal si urlPath ya trae una al inicio
    final cleanPath = urlPath.startsWith('/') ? urlPath : '/$urlPath';
    return "$serverBase$cleanPath";
  }
}