import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'update_user_screen.dart';
import 'create_user_screen.dart';

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
        // Filtra los usuarios según la región del operador
        _allUsers = snapshot.docs.where((doc) {
          final data = doc.data();
          return data['Ciudad']?.toLowerCase() == widget.region.toLowerCase();
        }).toList();
        _applySearch();
      });
    });
  }

  void _confirmAndDeleteUser(String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este usuario? Esta acción no se puede deshacer.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el cuadro de diálogo
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Botón rojo para "Cancelar"
              ),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteUser(userId);
                Navigator.of(context).pop(); // Cerrar el cuadro de diálogo tras confirmar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar para "Confirmar"
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteUser(String userId) {
    // Referencia al documento del usuario en Firestore
    FirebaseFirestore.instance.collection('Usuarios').doc(userId).delete().then((_) {
      // Mostrar un mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado exitosamente.')),
      );
    }).catchError((error) {
      // Mostrar un mensaje de error en caso de fallo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el usuario: $error')),
      );
      debugPrint('Error al eliminar el usuario: $error');
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
          'Gestión de Pasajeros',
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
                            'Usuario: ${user.id}\n'
                            'Ciudad: ${userData['Ciudad'] ?? 'Sin Ciudad'}\n'
                            'Teléfono: ${userData['NumeroTelefono'] ?? 'Sin Teléfono'}',
                          ),
                          trailing: Wrap(
                            spacing: 8, // Espaciado entre botones
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UpdateUserScreen(
                                        usuario: widget.usuario,
                                        userId: user.id,
                                        userData: userData,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
                                ),
                                child: const Text(
                                  'Actualizar estado',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _confirmAndDeleteUser(user.id); // Llamada a la lógica de eliminación
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red, // Botón rojo
                                ),
                                child: const Text(
                                  'Eliminar usuario',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'user_creation',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserCreationScreen(
                usuario: widget.usuario,
                isSupervisor: widget.isSupervisor,
                region: widget.region,
              ),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Usuario',
      ),
    );
  }
}