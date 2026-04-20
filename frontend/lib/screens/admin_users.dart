import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../api_config.dart';
import './customer_change_pwd.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _filterRol = 'TODOS';

  final List<String> _roles = ['TODOS', 'ADMIN', 'STAFF', 'CLIENTE'];

  // Colores por rol
  Color _getRolColor(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMIN':   return Colors.deepPurple.shade400;
      case 'STAFF':   return Colors.blueGrey.shade500;
      case 'CLIENTE': return AppColors.verdeBosque;
      default:        return Colors.grey;
    }
  }

  IconData _getRolIcon(String rol) {
    switch (rol.toUpperCase()) {
      case 'ADMIN':   return Icons.admin_panel_settings_rounded;
      case 'STAFF':   return Icons.badge_rounded;
      case 'CLIENTE': return Icons.person_rounded;
      default:        return Icons.help_outline;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {...ApiConfig.headers, 'Authorization': 'Token $token'};
  }

  // --- OBTENER TODOS LOS USUARIOS ---
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/list/'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        setState(() {
          _allUsers = json.decode(response.body);
          _applyFilter();
        });
      } else {
        _showSnackBar("Error al cargar usuarios: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredUsers = _filterRol == 'TODOS'
          ? List.from(_allUsers)
          : _allUsers.where((u) =>
              (u['rol'] ?? '').toString().toUpperCase() == _filterRol
            ).toList();
    });
  }

  void _filterSearch(String query) {
    setState(() {
      final base = _filterRol == 'TODOS'
          ? _allUsers
          : _allUsers.where((u) =>
              (u['rol'] ?? '').toString().toUpperCase() == _filterRol
            ).toList();
      _filteredUsers = base
          .where((u) =>
              (u['username'] ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (u['email'] ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // --- CAMBIAR ROL ---
  Future<void> _changeRol(dynamic user, String nuevoRol) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/${user['id']}/edit/'),
        headers: headers,
        body: jsonEncode({'rol': nuevoRol}),
      );
      if (response.statusCode == 200) {
        _showSnackBar(
          "Rol de ${user['username']} actualizado a $nuevoRol",
          AppColors.verdeBosque,
        );
        _fetchUsers();
      } else {
        _showSnackBar("No se pudo actualizar el rol", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  // --- ACTIVAR / DESACTIVAR CUENTA ---
  Future<void> _toggleActivo(dynamic user) async {
    final bool estaActivo = user['is_active'] ?? true;
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/users/${user['id']}/edit/'),
        headers: headers,
        body: jsonEncode({'is_active': !estaActivo}),
      );
      if (response.statusCode == 200) {
        _showSnackBar(
          estaActivo
              ? "${user['username']} desactivado"
              : "${user['username']} activado",
          estaActivo ? Colors.orange : AppColors.verdeBosque,
        );
        _fetchUsers();
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  // --- ELIMINAR CUENTA ---
  Future<void> _deleteUser(dynamic user) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/users/${user['id']}/edit/'),
        headers: headers,
      );
      if (response.statusCode == 204) {
        _showSnackBar("Cuenta de ${user['username']} eliminada", Colors.orange);
        _fetchUsers();
      } else {
        _showSnackBar("No se pudo eliminar la cuenta", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error de conexión", Colors.red);
    }
  }

  // --- DIÁLOGO DE EDICIÓN ---
  void _showEditDialog(dynamic user) {
    String rolSeleccionado = (user['rol'] ?? 'CLIENTE').toString().toUpperCase();
    final List<String> rolesDisponibles = ['ADMIN', 'STAFF', 'CLIENTE'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondoHueso,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 25, right: 25, top: 25,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getRolColor(rolSeleccionado).withOpacity(0.15),
                      radius: 26,
                      child: Icon(
                        _getRolIcon(rolSeleccionado),
                        color: _getRolColor(rolSeleccionado),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? '',
                            style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: AppColors.tituloNegro,
                            ),
                          ),
                          Text(
                            user['email'] ?? 'Sin correo',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                const Text(
                  "CAMBIAR ROL",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),

                // Selector de rol
                Row(
                  children: rolesDisponibles.map((rol) {
                    final bool selected = rolSeleccionado == rol;
                    final Color color = _getRolColor(rol);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => rolSeleccionado = rol),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? color.withOpacity(0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? color : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(_getRolIcon(rol), color: selected ? color : Colors.grey, size: 22),
                                const SizedBox(height: 5),
                                Text(
                                  rol,
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold,
                                    color: selected ? color : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Switch activo/inactivo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (user['is_active'] ?? true) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: (user['is_active'] ?? true) ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (user['is_active'] ?? true) ? "Cuenta activa" : "Cuenta desactivada",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Switch(
                        value: user['is_active'] ?? true,
                        activeColor: AppColors.verdeBosque,
                        onChanged: (_) {
                          Navigator.pop(context);
                          _toggleActivo(user);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Botón guardar rol
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verdeBosque,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (rolSeleccionado != (user['rol'] ?? '').toUpperCase()) {
                        _changeRol(user, rolSeleccionado);
                      }
                    },
                    child: const Text("GUARDAR CAMBIOS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 10),

                // Botón cambiar contraseña
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_reset_rounded, size: 20),
                    label: const Text("CAMBIAR CONTRASEÑA",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.verdeBosque,
                      side: const BorderSide(color: AppColors.verdeBosque),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CustomerChangePwdScreen()),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Botón eliminar cuenta
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded, size: 20),
                    label: const Text("ELIMINAR CUENTA",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmDialog(user);
                    },
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar cuenta?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: "Se eliminará permanentemente la cuenta de "),
              TextSpan(
                text: user['username'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ". Esta acción no se puede deshacer."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR",
                style: TextStyle(color: AppColors.verdeBosque)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(user);
            },
            child: const Text("ELIMINAR",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: const Text(
          "Gestión de Usuarios",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.verdeBosque,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con buscador y filtro
          Container(
            color: AppColors.verdeBosque,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
            child: Column(
              children: [
                // Buscador
                TextField(
                  onChanged: _filterSearch,
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre o correo...",
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.verdeBosque),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                // Filtro por rol
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles.map((rol) {
                      final bool selected = _filterRol == rol;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _filterRol = rol);
                            _applyFilter();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              rol,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.verdeBosque
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Contador
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Text(
                  "${_filteredUsers.length} usuario${_filteredUsers.length != 1 ? 's' : ''}",
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.verdeBosque))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off_rounded,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text("No hay usuarios",
                                style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        color: AppColors.verdeBosque,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 5),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(_filteredUsers[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final String rol =
        (user['rol'] ?? 'CLIENTE').toString().toUpperCase();
    final bool activo = user['is_active'] ?? true;
    final Color rolColor = _getRolColor(rol);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar con inicial
              CircleAvatar(
                radius: 24,
                backgroundColor: rolColor.withOpacity(0.12),
                child: Text(
                  (user['username'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: rolColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
                        Text(
                          user['username'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.tituloNegro,
                          ),
                        ),
                        if (!activo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "inactivo",
                              style: TextStyle(
                                  fontSize: 10, color: Colors.red.shade400),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user['email'] ?? 'Sin correo',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Badge de rol
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: rolColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getRolIcon(rol), size: 13, color: rolColor),
                    const SizedBox(width: 4),
                    Text(
                      rol,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rolColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade300, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}