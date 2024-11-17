import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class EmergencyDuringTripScreen extends StatefulWidget {
  final String region; // Región del control room

  const EmergencyDuringTripScreen({super.key, required this.region});

  @override
  State<EmergencyDuringTripScreen> createState() => _EmergencyDuringTripScreenState();
}

class _EmergencyDuringTripScreenState extends State<EmergencyDuringTripScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
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
        final List<Map<dynamic, dynamic>> emergencyTrips = data.entries.map((entry) {
          final Map<dynamic, dynamic> trip = Map<dynamic, dynamic>.from(entry.value as Map);
          trip['id'] = entry.key;
          return trip;
        }).where((trip) =>
            trip['emergency'] == true &&
            trip['emergency_at'] != null &&
            trip['city']?.toLowerCase() == widget.region.toLowerCase())
          .toList();

        // Ordenar los viajes según "emergency_at"
        emergencyTrips.sort((a, b) {
          final emergencyAtA = DateTime.parse(a['emergency_at']);
          final emergencyAtB = DateTime.parse(b['emergency_at']);
          return emergencyAtA.compareTo(emergencyAtB);
        });

        setState(() {
          _emergencyTrips = emergencyTrips;
        });
      } else {
        setState(() {
          _emergencyTrips = [];
        });
      }
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    final dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergencias en Progreso',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[400],
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: _emergencyTrips.isEmpty
          ? const Center(
              child: Text(
                'No hay emergencias reportadas',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _emergencyTrips.length,
              itemBuilder: (context, index) {
                final trip = _emergencyTrips[index];
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Conductor: ${trip['driver'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Usuario: ${trip['userName'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Punto de partida: ${trip['pickup']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Destino: ${trip['destination']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Equipaje: ${trip['luggage']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Pasajeros: ${trip['passengers']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Mascotas: ${trip['pets']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Hora de emergencia: ${_formatDateTime(trip['emergency_at'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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