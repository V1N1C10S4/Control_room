import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
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
            trip['city']?.toLowerCase() == widget.region.toLowerCase()) // No excluir emergency_at
        .toList();

        // Ordenar los viajes terminados por el campo "finished_at"
        finishedTrips.sort((a, b) {
          final finishedAtA = a['finished_at'] != null ? DateTime.parse(a['finished_at']) : DateTime.now();
          final finishedAtB = b['finished_at'] != null ? DateTime.parse(b['finished_at']) : DateTime.now();
          return finishedAtB.compareTo(finishedAtA);
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

                // Formatear las fechas de los campos
                final String createdAt = _formatDateTime(trip['created_at']);
                final String startedAt = _formatDateTime(trip['started_at']);
                final String passengerReachedAt = _formatDateTime(trip['passenger_reached_at']);
                final String pickedUpPassengerAt = _formatDateTime(trip['picked_up_passenger_at']);
                final String finishedAt = _formatDateTime(trip['finished_at']);
                final String emergencyAt = _formatDateTime(trip['emergency_at']);

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
                            'Viaje #${_finishedTrips.length - index}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User: ${trip['userName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Driver: ${trip['driver'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pickup: ${trip['pickup']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),

                          // 🔹 Mostrar todas las paradas intermedias en orden
                          for (int i = 1; trip.containsKey('stop$i'); i++) 
                            Text(
                              'Stop $i: ${trip['stop$i']['placeName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16),
                            ),

                          const SizedBox(height: 8),
                          Text(
                            'Destination: ${trip['destination']['placeName'] ?? 'N/A'}',
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
                            'Sillas para bebés: ${trip['babySeats'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solicitado: $createdAt',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Conductor asignado: $startedAt',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Conductor en sitio: $passengerReachedAt',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Inicio de viaje: $pickedUpPassengerAt',
                            style: const TextStyle(fontSize: 16),
                          ),

                          // 🔹 Registrar los tiempos de cada parada
                          for (int i = 1; trip.containsKey('stop$i'); i++) ...[
                            if (trip.containsKey('stop${i}_reached_at'))
                              Text(
                                'Llegada a parada $i: ${_formatDateTime(trip['stop${i}_reached_at'])}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            if (trip.containsKey('stop${i}_waiting_at'))
                              Text(
                                'Esperando en la parada $i: ${_formatDateTime(trip['stop${i}_waiting_at'])}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            if (trip.containsKey('stop${i}_continue_at'))
                              Text(
                                'Viaje continúa desde parada $i: ${_formatDateTime(trip['stop${i}_continue_at'])}',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],

                          Text(
                            'Finalizado: $finishedAt',
                            style: const TextStyle(fontSize: 16),
                          ),

                          if (trip.containsKey('emergency_at') && trip['emergency_at'] != null)
                            Text(
                              'Emergencia: $emergencyAt',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
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