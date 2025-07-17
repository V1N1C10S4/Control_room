import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'update_driver_screen.dart';
import 'create_driver_screen.dart'; // Nueva pantalla para crear conductores

class DriverManagementScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const DriverManagementScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  List<QueryDocumentSnapshot> _allDrivers = [];
  List<QueryDocumentSnapshot> _filteredDrivers = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  void _fetchDrivers() {
    FirebaseFirestore.instance.collection('Conductores').snapshots().listen((snapshot) {
      setState(() {
        _allDrivers = snapshot.docs.where((driver) {
          // Filtra los conductores por la misma región del operador
          final driverData = driver.data();
          final ciudad = (driverData['Ciudad'] ?? '').toString().toLowerCase();
          return ciudad == widget.region.toLowerCase();
        }).toList();
        _applySearch();
      });
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredDrivers = _allDrivers;
    } else {
      _filteredDrivers = _allDrivers.where((driver) {
        final driverData = driver.data() as Map<String, dynamic>;
        final driverId = driver.id.toLowerCase();
        final nombreConductor = (driverData['NombreConductor'] ?? '').toString().toLowerCase();
        final ciudad = (driverData['Ciudad'] ?? '').toString().toLowerCase();
        final numeroTelefono = (driverData['NumeroTelefono'] ?? '').toString().toLowerCase();
        return driverId.contains(_searchQuery) ||
            nombreConductor.contains(_searchQuery) ||
            ciudad.contains(_searchQuery) ||
            numeroTelefono.contains(_searchQuery);
      }).toList();
    }
  }

  void _confirmAndDeleteDriver(String driverKey) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este conductor? Esta acción no se puede deshacer.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el cuadro de diálogo
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteDriver(driverKey);
                Navigator.of(context).pop(); // Cerrar el cuadro de diálogo tras confirmar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _deleteDriver(String driverKey) {
    FirebaseFirestore.instance.collection('Conductores').doc(driverKey).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conductor eliminado exitosamente.')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar el conductor: $error')),
      );
      debugPrint('Error al eliminar el conductor: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Conductores',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar conductores...',
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
            child: _filteredDrivers.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron conductores.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredDrivers.length,
                    itemBuilder: (context, index) {
                      final driver = _filteredDrivers[index];
                      final driverData = driver.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: driverData['FotoPerfil'] != null
                                ? NetworkImage(driverData['FotoPerfil'])
                                : null,
                            child: driverData['FotoPerfil'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            driverData['NombreConductor'] ?? 'Sin Nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Driver ID: ${driver.id}\n'
                            'Ciudad: ${driverData['Ciudad'] ?? 'Sin Ciudad'}\n'
                            'Teléfono: ${driverData['NumeroTelefono'] ?? 'Sin Teléfono'}',
                          ),
                          trailing: Wrap(
                            spacing: 8, // Espaciado entre botones
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UpdateDriverScreen(
                                        usuario: widget.usuario,
                                        driverKey: driver.id,
                                        driverData: driverData,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
                                ),
                                child: const Text(
                                  'Actualizar estado',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _confirmAndDeleteDriver(driver.id);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text(
                                  'Eliminar conductor',
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
        heroTag: 'driver_creation',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateDriverScreen(usuario: widget.usuario, region: widget.region),
            ),
          );
        },
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Conductor',
      ),
    );
  }
}