import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'update_driver_screen.dart'; // Asegúrate de importar la pantalla UpdateDriverScreen

class DriverManagementScreen extends StatefulWidget {
  final String usuario;
  const DriverManagementScreen({super.key, required this.usuario});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de conductores',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ), // Verde militar
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('Conductores').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los conductores'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay conductores disponibles'));
          }

          final conductores = snapshot.data!.docs;

          return ListView.builder(
            itemCount: conductores.length,
            itemBuilder: (context, index) {
              final conductor = conductores[index].data() as Map<String, dynamic>;
              final driverKey = conductores[index].id; // Obtiene el ID del documento del conductor
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(conductor['FotoPerfil']),
                    ),
                    title: Text(
                      'Nombre conductor: ${conductor['NombreConductor']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ubicación: ${conductor['Ciudad']}'),
                        Text('Info. del vehículo: ${conductor['InfoVehiculo']}'),
                        Text('Placas: ${conductor['Placas']}'),
                        Text('Estatus: ${conductor['Estatus']}'),
                        Text('Número de Teléfono: ${conductor['NumeroTelefono']}'),
                        Text('Nombre de Supervisor: ${conductor['NombreSupervisor']}'),
                        Text('Número de Supervisor: ${conductor['NumeroSupervisor']}'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UpdateDriverScreen(
                              usuario: widget.usuario,
                              driverKey: driverKey,
                              driverData: conductor,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Actualizar estado',
                        style: TextStyle(color: Colors.white),
                      ),
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
}