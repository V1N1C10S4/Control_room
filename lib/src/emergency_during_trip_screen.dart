import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class EmergencyDuringTripScreen extends StatefulWidget {
  final String region;

  const EmergencyDuringTripScreen({super.key, required this.region});

  @override
  State<EmergencyDuringTripScreen> createState() =>
      _EmergencyDuringTripScreenState();
}

class _EmergencyDuringTripScreenState extends State<EmergencyDuringTripScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  final Logger _logger = Logger();
  List<Map<dynamic, dynamic>> _emergencyTrips = [];

  @override
  void initState() {
    super.initState();
    _fetchEmergencyTrips();
  }

  void _fetchEmergencyTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> emergencyTrips = data.entries
            .map((entry) {
              final Map<dynamic, dynamic> trip =
                  Map<dynamic, dynamic>.from(entry.value as Map);
              trip['id'] = entry.key;
              return trip;
            })
            .where((trip) =>
                trip.containsKey('emergency_at') &&
                trip['emergency_at'] != null &&
                trip['city']?.toLowerCase() == widget.region.toLowerCase())
            .toList();

        setState(() {
          _emergencyTrips = emergencyTrips;
        });
      } else {
        setState(() {
          _emergencyTrips = [];
        });
      }
    }).onError((error) {
      _logger.e('Error fetching emergency trips: $error');
      setState(() {
        _emergencyTrips = [];
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencias en Viajes'),
        backgroundColor: Colors.red[300],
      ),
      body: _emergencyTrips.isEmpty
          ? const Center(
              child: Text(
                'No hay emergencias registradas',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _emergencyTrips.length,
              itemBuilder: (context, index) {
                final trip = _emergencyTrips[index];
                final bool emergencyInProgress = trip['emergency'] == true;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: emergencyInProgress
                                      ? Colors.red
                                      : Colors.green,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  emergencyInProgress
                                      ? 'En progreso'
                                      : 'Atendida',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (emergencyInProgress)
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  onPressed: () => _handleEmergencySwitch(
                                      trip['id'], emergencyInProgress),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}