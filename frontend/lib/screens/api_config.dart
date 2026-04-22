class ApiConfig {
  static const String serverIp = "appmobile-production.up.railway.app";
  static const String port = "443";
  static const String serverBase = "https://$serverIp";
  static const String baseUrl = "$serverBase/api";
  static const String login = "$baseUrl/users/login/";
  static const String products = "$baseUrl/FinalProduct/";
  static const String searchByCode = "${products}buscar_por_codigo/";
  static const String rawMaterials = "$baseUrl/raw-materials/";
  static const String inventoryMovements = "$baseUrl/inventory-movements/";
  static const String sales = "$baseUrl/sales/";
  static const String changePassword = "$baseUrl/users/change-password/";
  static const String userProfile = "$baseUrl/users/profile/";

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static String getImageUrl(String? urlPath) {
    if (urlPath == null || urlPath.isEmpty) return "";
    if (urlPath.startsWith('http')) {
      return "$urlPath?t=${DateTime.now().millisecondsSinceEpoch}";
    }
    final cleanPath = urlPath.startsWith('/') ? urlPath : '/$urlPath';
    return "$serverBase$cleanPath";
  }
}
