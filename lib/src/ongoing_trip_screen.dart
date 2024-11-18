import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class OngoingTripScreen extends StatefulWidget {
  final String usuario;
  final String region;
  const OngoingTripScreen({super.key, required this.usuario, required this.region});

  @override
  OngoingTripScreenState createState() => OngoingTripScreenState();
}

class OngoingTripScreenState extends State<OngoingTripScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _ongoingTrips = [];
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchOngoingTrips();
  }

  void _fetchOngoingTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> ongoingTrips = data.entries.map((entry) {
          final Map<dynamic, dynamic> trip = Map<dynamic, dynamic>.from(entry.value as Map);
          trip['id'] = entry.key;
          return trip;
        })
        .where((trip) =>
            (trip['status'] == 'started' ||
            trip['status'] == 'passenger reached' ||
            trip['status'] == 'picked up passenger') &&
            trip['city']?.toLowerCase() == widget.region.toLowerCase() &&
            !trip.containsKey('emergency_at')) // Excluir viajes con 'emergency_at'
        .toList();

        // Ordenar los viajes según el campo "started_at"
        ongoingTrips.sort((a, b) {
          final startedAtA = a['started_at'] != null ? DateTime.parse(a['started_at']) : DateTime.now();
          final startedAtB = b['started_at'] != null ? DateTime.parse(b['started_at']) : DateTime.now();
          return startedAtA.compareTo(startedAtB);
        });

        setState(() {
          _ongoingTrips = ongoingTrips;
        });
      } else {
        setState(() {
          _ongoingTrips = [];
        });
      }
    }).onError((error) {
      _logger.e('Error fetching ongoing trips: $error');
      setState(() {
        _ongoingTrips = [];
      });
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    DateTime dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viajes en Progreso', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(207, 215, 107, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: _ongoingTrips.isEmpty
          ? const Center(
              child: Text(
                'No hay viajes en progreso',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _ongoingTrips.length,
              itemBuilder: (context, index) {
                final trip = _ongoingTrips[index];

                // Formatear las fechas de started_at, passenger_reached_at, y picked_up_passenger_at
                final String startedAt = _formatDateTime(trip['started_at']);
                final String passengerReachedAt = _formatDateTime(trip['passenger_reached_at']);
                final String pickedUpPassengerAt = _formatDateTime(trip['picked_up_passenger_at']);

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
                            'Viaje #${_ongoingTrips.length - index}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User: ${trip['userName'] ?? 'N/A'}', // Usando userName
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Driver: ${trip['driver'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pickup: ${trip['pickup']['placeName'] ?? 'N/A'}', // Usando placeName
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Destination: ${trip['destination']['placeName'] ?? 'N/A'}', // Usando placeName
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${trip['status']}',
                            style: const TextStyle(fontSize: 16),
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
                            'Iniciado: $startedAt',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Pasajero alcanzado: $passengerReachedAt',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Pasajero recogido: $pickedUpPassengerAt',
                            style: const TextStyle(fontSize: 16),
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