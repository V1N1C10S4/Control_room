import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'home_screen.dart';  // Asegúrate de importar la pantalla de solicitudes

class SelectDriverScreen extends StatefulWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor; // Añadir este campo

  const SelectDriverScreen({
    super.key, 
    required this.tripRequest,
    required this.isSupervisor, // Añadir como requerido
  });

  @override
  SelectDriverScreenState createState() => SelectDriverScreenState();
}

class SelectDriverScreenState extends State<SelectDriverScreen> {
  List<Map<String, dynamic>> _drivers = [];
  final Logger _logger = Logger();
  String? _userCity;

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
      });

    } catch (error) {
      _logger.e('Error fetching drivers: $error');
      setState(() {
        _drivers = [];
      });
    }
  }

  void _assignDriver(String driverId) async {
    try {
      // Actualizar el conductor en Firestore
      await FirebaseFirestore.instance.collection('Conductores').doc(driverId).update({
        'Viaje': true,
      });

      // Actualizar el estado del viaje y añadir el conductor en RealTime Database
      final DatabaseReference tripRequestRef = FirebaseDatabase.instance.ref().child('trip_requests').child(widget.tripRequest['id']);
      await tripRequestRef.update({
        'status': 'in progress',
        'driver': driverId,
      });

      _logger.i('Driver assigned successfully.');
      
      // Volver a la pantalla de solicitudes de viaje
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(
          usuario: widget.tripRequest['userId'],
          isSupervisor: widget.isSupervisor, // Pasar el valor de isSupervisor correctamente
        )),
        (Route<dynamic> route) => false,
      );

    } catch (error) {
      _logger.e('Error assigning driver or updating trip status: $error');
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
            Expanded(
              child: _drivers.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay conductores disponibles.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _drivers.length,
                      itemBuilder: (context, index) {
                        final driver = _drivers[index];
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
                              onPressed: () {
                                _assignDriver(driver['id']);
                              },
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
          ],
        ),
      ),
    );
  }
}