import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyDuringTripScreen extends StatefulWidget {
  final String region;
  final String usuario;

  const EmergencyDuringTripScreen({super.key, required this.region, required this.usuario,});

  @override
  State<EmergencyDuringTripScreen> createState() =>
      _EmergencyDuringTripScreenState();
}

class _EmergencyDuringTripScreenState extends State<EmergencyDuringTripScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  final Logger _logger = Logger();
  List<Map<dynamic, dynamic>> _inProgressEmergencies = [];
  List<Map<dynamic, dynamic>> _resolvedEmergencies = [];
  String? _telefonoPasajero;
  String? _telefonoConductor;

  @override
  void initState() {
    super.initState();
    _fetchEmergencyTrips();
    _fetchPassengerPhone();
  }

  void _fetchEmergencyTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> inProgress = [];
        final List<Map<dynamic, dynamic>> resolved = [];

        data.entries.map((entry) {
          final Map<dynamic, dynamic> trip =
              Map<dynamic, dynamic>.from(entry.value as Map);
          trip['id'] = entry.key;
          return trip;
        }).where((trip) =>
            trip.containsKey('emergency_at') &&
            trip['emergency_at'] != null &&
            trip['city']?.toLowerCase() == widget.region.toLowerCase())
        .forEach((trip) {
          if (trip['emergency'] == true) {
            inProgress.add(trip);

            if (trip.containsKey('driver')) {
              _fetchDriverPhone(trip['driver']);
            }
            
          } else {
            resolved.add(trip);
          }
        });

        // Ordenar las listas
        inProgress.sort((a, b) {
          final createdAtA = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
          final createdAtB = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
          return createdAtA.compareTo(createdAtB);
        });

        resolved.sort((a, b) {
          final createdAtA = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
          final createdAtB = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
          return createdAtB.compareTo(createdAtA);
        });

        setState(() {
          _inProgressEmergencies = inProgress;
          _resolvedEmergencies = resolved;
        });
      } else {
        setState(() {
          _inProgressEmergencies = [];
          _resolvedEmergencies = [];
        });
      }
    }).onError((error) {
      _logger.e('Error fetching emergency trips: $error');
      setState(() {
        _inProgressEmergencies = [];
        _resolvedEmergencies = [];
      });
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    DateTime dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  void _handleEmergencySwitch(String tripId, bool currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar acción'),
        content: const Text(
            '¿Estás seguro de que quieres marcar esta emergencia como atendida?'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Botón rojo
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white), // Texto blanco
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _databaseReference
                    .child('trip_requests')
                    .child(tripId)
                    .update({'emergency': false});
                _logger.i('Emergencia atendida para el viaje $tripId.');
                _fetchEmergencyTrips(); // Refrescar la lista de emergencias
              } catch (error) {
                _logger.e('Error al actualizar emergencia: $error');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, // Botón verde
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white), // Texto blanco
            ),
          ),
        ],
      ),
    );
  }

  void _fetchPassengerPhone() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance.collection("Usuarios").doc(widget.usuario).get();

      if (userDoc.exists) {
        String telefonoPasajero = userDoc.data()?["NumeroTelefono"] ?? "Desconocido";
        print("Teléfono del pasajero: $telefonoPasajero");

        setState(() {
          _telefonoPasajero = telefonoPasajero;
        });
      } else {
        print("No se encontró el usuario en la base de datos.");
      }
    } catch (error) {
      print("Error al obtener el teléfono del pasajero: $error");
    }
  }

  void _fetchDriverPhone(String driverId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await FirebaseFirestore.instance.collection("Conductores").doc(driverId).get();

      if (driverDoc.exists) {
        String telefonoConductor = driverDoc.data()?["NumeroTelefono"] ?? "Desconocido";
        print("Teléfono del conductor: $telefonoConductor");

        setState(() {
          _telefonoConductor = telefonoConductor;
        });
      } else {
        print("No se encontró el conductor en la base de datos.");
      }
    } catch (error) {
      print("Error al obtener el teléfono del conductor: $error");
    }
  }

  Widget _buildEmergencyCard(Map<dynamic, dynamic> trip, bool isInProgress) {
    final emergencyLocation = trip['emergency_location'] as Map<dynamic, dynamic>?;
    final latitude = emergencyLocation?['latitude']?.toString() ?? 'N/A';
    final longitude = emergencyLocation?['longitude']?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ciudad: ${trip['city'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Conductor: ${trip['driver'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usuario: ${trip['userName'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup: ${trip['pickup']?['placeName'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Destino: ${trip['destination']?['placeName'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fecha de emergencia: ${_formatDateTime(trip['emergency_at'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Emergencia reportada en: Lat: $latitude, Long: $longitude',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Equipaje: ${trip['luggage'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pasajeros: ${trip['passengers'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mascotas: ${trip['pets'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sillas para bebés: ${trip['babySeats'] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teléfono del pasajero: $_telefonoPasajero',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teléfono Conductor: ${_telefonoConductor ?? "No disponible"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isInProgress ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      isInProgress ? 'En progreso' : 'Atendida',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isInProgress)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _handleEmergencySwitch(trip['id'], true),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergencias en Viajes',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[300],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          if (_inProgressEmergencies.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Emergencias en progreso',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _inProgressEmergencies.length,
                itemBuilder: (context, index) =>
                    _buildEmergencyCard(_inProgressEmergencies[index], true),
              ),
            ),
          ],
          if (_resolvedEmergencies.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Emergencias atendidas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _resolvedEmergencies.length,
                itemBuilder: (context, index) =>
                    _buildEmergencyCard(_resolvedEmergencies[index], false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}