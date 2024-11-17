import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'trip_details_screen.dart'; // Importa la pantalla de detalles del viaje
import 'package:intl/intl.dart';

class FinishedTripScreen extends StatefulWidget {
  final String usuario;
  final String region;
  const FinishedTripScreen({super.key, required this.usuario, required this.region});

  @override
  FinishedTripScreenState createState() => FinishedTripScreenState();
}

class FinishedTripScreenState extends State<FinishedTripScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _finishedTrips = [];
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchFinishedTrips();
  }

  void _fetchFinishedTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> finishedTrips = data.entries.map((entry) {
          final Map<dynamic, dynamic> trip = Map<dynamic, dynamic>.from(entry.value as Map);
          trip['id'] = entry.key;
          return trip;
        })
        .where((trip) =>
            trip['status'] == 'trip finished' &&
            trip['city']?.toLowerCase() == widget.region.toLowerCase() &&
            !trip.containsKey('emergency_at')) // Excluir viajes con 'emergency_at'
        .toList();

        // Ordenar los viajes terminados por el campo "finished_at"
        finishedTrips.sort((a, b) {
          final finishedAtA = a['finished_at'] != null ? DateTime.parse(a['finished_at']) : DateTime.now();
          final finishedAtB = b['finished_at'] != null ? DateTime.parse(b['finished_at']) : DateTime.now();
          return finishedAtA.compareTo(finishedAtB);
        });

        setState(() {
          _finishedTrips = finishedTrips;
        });
      } else {
        setState(() {
          _finishedTrips = [];
        });
      }
    }).onError((error) {
      _logger.e('Error fetching finished trips: $error');
      setState(() {
        _finishedTrips = [];
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
        title: const Text('Viajes Terminados', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(158, 212, 176, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: _finishedTrips.isEmpty
          ? const Center(
              child: Text(
                'No hay viajes terminados',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _finishedTrips.length,
              itemBuilder: (context, index) {
                final trip = _finishedTrips[index];

                // Formatear las fechas de los campos created_at, started_at, passenger_reached_at, picked_up_passenger_at y finished_at
                final String createdAt = _formatDateTime(trip['created_at']);
                final String startedAt = _formatDateTime(trip['started_at']);
                final String passengerReachedAt = _formatDateTime(trip['passenger_reached_at']);
                final String pickedUpPassengerAt = _formatDateTime(trip['picked_up_passenger_at']);
                final String finishedAt = _formatDateTime(trip['finished_at']);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Viaje #${_finishedTrips.length - index}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'User: ${trip['userId']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'Driver: ${trip['driver']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pickup: ${trip['pickup']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Destination: ${trip['destination']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: ${trip['status']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Solicitado: $createdAt',
                                  style: const TextStyle(fontSize: 16),
                                ),
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
                                Text(
                                  'Finalizado: $finishedAt',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TripDetailsScreen(trip: trip, appBarColor: const Color.fromRGBO(158, 212, 176, 1)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(158, 212, 176, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Detalles', style: TextStyle(color: Colors.white)),
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