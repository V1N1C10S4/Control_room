import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  final String usuario;
  final bool isSupervisor;
  final String region;

  const UserManagementScreen({
    Key? key,
    required this.usuario,
    required this.isSupervisor,
    required this.region,
  }) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<QueryDocumentSnapshot> _allUsers = [];
  List<QueryDocumentSnapshot> _filteredUsers = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() {
    FirebaseFirestore.instance.collection('Usuarios').snapshots().listen((snapshot) {
      setState(() {
        _allUsers = snapshot.docs;
        _applySearch();
      });
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = _allUsers;
    } else {
      _filteredUsers = _allUsers.where((user) {
        final userData = user.data() as Map<String, dynamic>;
        final userId = user.id.toLowerCase();
        final nombreUsuario = (userData['NombreUsuario'] ?? '').toString().toLowerCase();
        final ciudad = (userData['Ciudad'] ?? '').toString().toLowerCase();
        final numeroTelefono = (userData['NumeroTelefono'] ?? '').toString().toLowerCase();
        return userId.contains(_searchQuery) ||
            nombreUsuario.contains(_searchQuery) ||
            ciudad.contains(_searchQuery) ||
            numeroTelefono.contains(_searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar usuarios...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query.toLowerCase();
                  _applySearch();
                });
              },
            ),
          ),
          Expanded(
            child: _filteredUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron usuarios.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final userData = user.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['FotoPerfil'] != null
                                ? NetworkImage(userData['FotoPerfil'])
                                : null,
                            child: userData['FotoPerfil'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            userData['NombreUsuario'] ?? 'Sin Nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'UserId: ${user.id}\n'
                            'Ciudad: ${userData['Ciudad'] ?? 'Sin Ciudad'}\n'
                            'Teléfono: ${userData['NumeroTelefono'] ?? 'Sin Teléfono'}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _showUpdateUserDialog(user.id, userData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
                            ),
                            child: const Text(
                              'Actualizar estado',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showUpdateUserDialog(String userId, Map<String, dynamic> userData) {
    // Aquí puedes implementar un cuadro de diálogo o navegación para editar al usuario
    print('Actualizar usuario con ID: $userId');
    // Implementar lógica de actualización.
  }
}