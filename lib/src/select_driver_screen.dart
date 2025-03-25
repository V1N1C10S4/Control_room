import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'home_screen.dart'; // Asegúrate de importar la pantalla de solicitudes

class SelectDriverScreen extends StatefulWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor;
  final String region;

  const SelectDriverScreen({
    super.key,
    required this.tripRequest,
    required this.isSupervisor,
    required this.region,
  });

  @override
  SelectDriverScreenState createState() => SelectDriverScreenState();
}

class SelectDriverScreenState extends State<SelectDriverScreen> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  final Logger _logger = Logger();
  String? _userCity;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedDriver;
  Map<String, dynamic>? _selectedDriver2;
  bool _isSelectingSecondDriver = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCityAndDrivers();
  }

  Future<void> _fetchUserCityAndDrivers() async {
    _logger.i('Fetching city for user: ${widget.tripRequest['userId']}');
    try {
      // Fetch user city
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(widget.tripRequest['userId'])
          .get();

      if (userDoc.exists) {
        _userCity = userDoc.data()?['Ciudad']?.toLowerCase();
        _logger.i('User city: $_userCity');
        _fetchAvailableDrivers();
      } else {
        _logger.w('User document does not exist');
      }
    } catch (error) {
      _logger.e('Error fetching user city: $error');
    }
  }

  Future<void> _fetchAvailableDrivers() async {
    if (_userCity == null) {
      _logger.w('User city is null, skipping driver fetch');
      return;
    }

    _logger.i('Fetching available drivers');
    try {
      QuerySnapshot<Map<String, dynamic>> driversSnapshot = await FirebaseFirestore.instance
          .collection('Conductores')
          .where('Estatus', isEqualTo: 'disponible')
          .where('Viaje', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> drivers = driversSnapshot.docs.map((doc) {
        Map<String, dynamic> driver = doc.data();
        driver['id'] = doc.id;
        return driver;
      }).where((driver) => driver['Ciudad']?.toLowerCase() == _userCity).toList();

      _logger.i('Available drivers: ${drivers.map((d) => d['NombreConductor']).toList()}');

      setState(() {
        _drivers = drivers;
        _filteredDrivers = drivers; // Inicializa la lista filtrada
      });
    } catch (error) {
      _logger.e('Error fetching drivers: $error');
      setState(() {
        _drivers = [];
        _filteredDrivers = [];
      });
    }
  }

  void _filterDrivers(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredDrivers = _drivers.where((driver) {
        final city = driver['Ciudad']?.toLowerCase() ?? '';
        final plates = driver['Placas']?.toLowerCase() ?? '';
        final vehicleInfo = driver['InfoVehiculo']?.toLowerCase() ?? '';
        final driverName = driver['NombreConductor']?.toLowerCase() ?? '';
        return city.contains(lowerCaseQuery) ||
            plates.contains(lowerCaseQuery) ||
            vehicleInfo.contains(lowerCaseQuery) ||
            driverName.contains(lowerCaseQuery);
      }).toList();
    });
  }

  void _assignDriver(String driverId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await FirebaseFirestore.instance.collection('Conductores').doc(driverId).get();

      if (!driverDoc.exists) {
        _logger.e('Error: El documento del conductor no existe.');
        return;
      }

      Map<String, dynamic>? driverData = driverDoc.data();
      driverData?['id'] = driverId;
      String telefonoConductor = driverData?["NumeroTelefono"] ?? "No disponible";

      setState(() {
        if (_selectedDriver == null) {
          _selectedDriver = {
            "id": driverId,
            "NombreConductor": driverData?["NombreConductor"] ?? "Desconocido",
            "TelefonoConductor": telefonoConductor,
          };
        } else if (_selectedDriver2 == null && _selectedDriver!["id"] != driverId) {
          _selectedDriver2 = {
            "id": driverId,
            "NombreConductor": driverData?["NombreConductor"] ?? "Desconocido",
            "TelefonoConductor": telefonoConductor,
          };
          _isSelectingSecondDriver = false;
        }
      });

      _logger.i('Conductor seleccionado: ${driverData?["NombreConductor"]}');
    } catch (error) {
      _logger.e('Error al seleccionar conductor: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Solicitud #${widget.tripRequest['id']}: Selección de conductor',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conductores disponibles:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, ciudad, vehículo o placas...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onChanged: (value) {
                  _filterDrivers(value);
                },
              ),
            ),
            Expanded(
              child: _filteredDrivers.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay conductores disponibles.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredDrivers.length,
                      itemBuilder: (context, index) {
                        final driver = _filteredDrivers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(driver['FotoPerfil']),
                            ),
                            title: Text(
                              'Nombre conductor: ${driver['NombreConductor']}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Ubicación: ${driver['Ciudad']}  Info. del vehículo: ${driver['InfoVehiculo']}  Placas: ${driver['Placas']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: ElevatedButton(
                              onPressed: (_selectedDriver == null ||
                                          (_isSelectingSecondDriver &&
                                          _selectedDriver2 == null &&
                                          _selectedDriver!["id"] != driver['id']))
                                  ? () => _assignDriver(driver['id'])
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                              child: const Text(
                                'Asignar conductor',
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selectedDriver != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(
                    'Conductor seleccionado: ${_selectedDriver!["NombreConductor"]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Teléfono: ${_selectedDriver!["TelefonoConductor"]}'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_selectedDriver2 != null) ...[
              const SizedBox(height: 10),
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: Text(
                    'Segundo conductor: ${_selectedDriver2!["NombreConductor"]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Teléfono: ${_selectedDriver2!["TelefonoConductor"]}'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_selectedDriver != null) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDriver = null;
                    _selectedDriver2 = null; // Se resetea también el segundo conductor
                    _filteredDrivers = List.from(_drivers); // Reactivar la lista de conductores
                    _isSelectingSecondDriver = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  "Cancelar selección",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_selectedDriver != null && _selectedDriver2 == null && !_isSelectingSecondDriver) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                  "Añadir otro conductor",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  setState(() {
                    _isSelectingSecondDriver = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectedDriver == null ? null : () async {
                try {
                  // 🔹 Actualizar Firestore para marcar a los conductores como ocupados
                  await FirebaseFirestore.instance.collection('Conductores')
                      .doc(_selectedDriver!["id"]).update({'Viaje': true});

                  if (_selectedDriver2 != null) {
                    await FirebaseFirestore.instance.collection('Conductores')
                        .doc(_selectedDriver2!["id"]).update({'Viaje': true});
                  }

                  // 🔹 Actualizar Firebase Realtime Database con los conductores seleccionados
                  final DatabaseReference tripRequestRef = FirebaseDatabase.instance
                      .ref().child('trip_requests').child(widget.tripRequest['id']);

                  Map<String, dynamic> updateData = {
                    'status': 'in progress',
                    'driver': _selectedDriver!["id"],
                    'TelefonoConductor': _selectedDriver!["TelefonoConductor"],
                  };

                  if (_selectedDriver2 != null) {
                    updateData["driver2"] = _selectedDriver2!["id"];
                    updateData["TelefonoConductor2"] = _selectedDriver2!["TelefonoConductor"];
                  }

                  await tripRequestRef.update(updateData);

                  _logger.i('Conductores asignados correctamente.');

                  // 🔹 Navegar a HomeScreen después de confirmar la asignación
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        usuario: widget.tripRequest['userId'],
                        isSupervisor: widget.isSupervisor,
                        region: widget.region,
                      ),
                    ),
                    (Route<dynamic> route) => false,
                  );
                } catch (error) {
                  _logger.e('Error al asignar los conductores: $error');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              ),
              child: const Text(
                'Asignar y Continuar',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}