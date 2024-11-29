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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(color: Colors.white), // Texto blanco en el AppBar
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white), // Iconos blancos en el AppBar
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(), // Indicador de carga
            );
          }

          final users = snapshot.data!.docs;

          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No hay usuarios registrados.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
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
                    'Ciudad: ${userData['Ciudad'] ?? 'Sin Ciudad'}\nTeléfono: ${userData['NumeroTelefono'] ?? 'Sin Teléfono'}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      _showUpdateUserDialog(user.id, userData);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
                    ),
                    child: const Text(
                      'Actualizar estado',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUpdateUserDialog(String userId, Map<String, dynamic> userData) {
    // Aquí puedes implementar un cuadro de diálogo o navegar a otra pantalla para actualizar al usuario.
    // Por ahora, solo imprimimos el ID del usuario.
    print('Actualizar usuario con ID: $userId');
    //Implementar lógica de actualización.
  }
}