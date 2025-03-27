import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class CancelledTripsScreen extends StatelessWidget {
  final String region;

  const CancelledTripsScreen({Key? key, required this.region}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchCancelledTrips() async {
    final DatabaseReference ref = FirebaseDatabase.instance.ref().child('trip_requests');
    final snapshot = await ref.orderByChild('status').equalTo('trip cancelled').get();

    if (snapshot.exists) {
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

      List<Map<String, dynamic>> trips = data.entries.map((entry) {
        final Map<String, dynamic> trip = Map<String, dynamic>.from(entry.value as Map);
        trip['id'] = entry.key;

        return {
          'id': trip['id'],
          'created_at': trip['created_at'] != null ? _formatDateTime(trip['created_at']) : 'NA',
          'pickup': trip['pickup']['placeName'] ?? 'NA',
          'destination': trip['destination']['placeName'] ?? 'NA',
          'driver': trip['driver'] ?? 'NA',
          'userName': trip['userName'] ?? 'NA',
          'luggage': trip['luggage']?.toString() ?? 'NA',
          'passengers': trip['passengers']?.toString() ?? 'NA',
          'pets': trip['pets']?.toString() ?? 'NA',
          'babySeats': trip['babySeats']?.toString() ?? 'NA',
          'started_at': trip['started_at'] != null ? _formatDateTime(trip['started_at']) : 'NA',
          'passenger_reached_at': trip['passenger_reached_at'] != null
              ? _formatDateTime(trip['passenger_reached_at'])
              : 'NA',
          'picked_up_passenger_at': trip['picked_up_passenger_at'] != null
              ? _formatDateTime(trip['picked_up_passenger_at'])
              : 'NA',
          'city': trip['city'] ?? 'NA',
          'emergency_at': trip['emergency_at'] != null ? _formatDateTime(trip['emergency_at']) : null, // Captura emergency_at si existe
          'telefonoPasajero': trip.containsKey('telefonoPasajero') && trip['telefonoPasajero'] != null && trip['telefonoPasajero'].toString().trim().isNotEmpty
            ? trip['telefonoPasajero']
            : "No disponible",
          'cancellation_reason': trip.containsKey('cancellation_reason') && trip['cancellation_reason'] != null && trip['cancellation_reason'].toString().trim().isNotEmpty
            ? trip['cancellation_reason']
            : "N/A", // Si no existe o está vacío, muestra 'N/A'
        };
      }).toList();

      // Filtrar por región y ordenar por `created_at`
      trips = trips
          .where((trip) => trip['city'] == region)
          .toList()
        ..sort((a, b) {
          final createdAtA = a['created_at'] != 'NA'
              ? DateFormat('dd/MM/yyyy HH:mm').parse(a['created_at'])
              : DateTime.now();
          final createdAtB = b['created_at'] != 'NA'
              ? DateFormat('dd/MM/yyyy HH:mm').parse(b['created_at'])
              : DateTime.now();
          return createdAtB.compareTo(createdAtA); // Ordenar de más reciente a más antiguo
        });

      return trips;
    }

    return [];
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
        title: const Text('Viajes Cancelados', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(255, 99, 71, 1), // Rojo tomate
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCancelledTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los datos', style: TextStyle(fontSize: 24, color: Colors.grey),));
          }

          final trips = snapshot.data!;
          if (trips.isEmpty) {
            return const Center(child: Text('No hay viajes cancelados en esta región', style: TextStyle(fontSize: 24, color: Colors.grey),));
          }

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                        'Solicitud #${trips.length - index}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Creado el: ${trip['created_at']}'),
                      Text('Punto de partida: ${trip['pickup']}'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🔹 Mostrar la parada única si existe
                          if (trip.containsKey('stop')) ...[
                            Text(
                              'Parada 1: ${trip['stop']['placeName'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (trip.containsKey('on_stop_way_at'))
                              Text(
                                '🚕 En camino a la parada: ${_formatDateTime(trip['on_stop_way_at'])}',
                                style: const TextStyle(fontSize: 14, color: Colors.blue),
                              ),
                            if (trip.containsKey('stop_reached_at'))
                              Text(
                                '📍 Llegada a parada: ${_formatDateTime(trip['stop_reached_at'])}',
                                style: const TextStyle(fontSize: 14, color: Colors.blue),
                              ),
                          ],

                          // 🔹 Si no existe "stop", mostrar "stop1", "stop2", etc.
                          ...(() {
                            List<Widget> stops = [];
                            int stopIndex = trip.containsKey('stop') ? 2 : 1; // Si hay "stop", empezamos en Parada 2

                            for (int i = 1; i <= 5; i++) {
                              String stopKey = 'stop$i';
                              if (trip.containsKey(stopKey)) {
                                stops.add(
                                  Text(
                                    'Parada $stopIndex: ${trip[stopKey]['placeName'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                );

                                // 🔹 Mostrar los tiempos relacionados con la parada
                                if (trip.containsKey('stop${i}_reached_at'))
                                  stops.add(Text(
                                    '📍 Llegada a parada: ${_formatDateTime(trip['stop${i}_reached_at'])}',
                                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                                  ));

                                if (trip.containsKey('stop${i}_waiting_at'))
                                  stops.add(Text(
                                    '⏳ En espera en parada: ${_formatDateTime(trip['stop${i}_waiting_at'])}',
                                    style: const TextStyle(fontSize: 14, color: Colors.orange),
                                  ));

                                if (trip.containsKey('stop${i}_continue_at'))
                                  stops.add(Text(
                                    '🚗 Continuando viaje desde parada: ${_formatDateTime(trip['stop${i}_continue_at'])}',
                                    style: const TextStyle(fontSize: 14, color: Colors.green),
                                  ));

                                stopIndex++; // Incrementamos el índice correctamente
                              }
                            }
                            return stops;
                          })(),
                        ],
                      ),
                      Text('Destino: ${trip['destination']}'),
                      Text('Conductor: ${trip['driver']}'),

                      if (trip['TelefonoConductor'] != null && trip['TelefonoConductor'].toString().trim().isNotEmpty)
                        ...[
                          Text('Teléfono Conductor: ${trip['TelefonoConductor']}'),
                        ],

                      if (trip['driver2'] != null && trip['driver2'].toString().trim().isNotEmpty)
                        ...[
                          Text('Conductor Secundario: ${trip['driver2']}'),
                          if (trip['TelefonoConductor2'] != null && trip['TelefonoConductor2'].toString().trim().isNotEmpty)
                            ...[
                              Text('Teléfono Conductor Secundario: ${trip['TelefonoConductor2']}'),
                            ],
                        ],
                      Text('Pasajero: ${trip['userName']}'),
                      Text('Teléfono del pasajero: ${trip['telefonoPasajero']}'),
                      Text('Equipaje: ${trip['luggage']}'),
                      Text('Pasajeros: ${trip['passengers']}'),
                      Text('Mascotas: ${trip['pets']}'),
                      Text('Sillas para bebés: ${trip['babySeats']}'),
                      Text('Conductor asignado: ${trip['started_at']}'),
                      Text('Conductor en sitio: ${trip['passenger_reached_at']}'),
                      Text('Inicio de viaje: ${trip['picked_up_passenger_at']}'),
                      if (trip['emergency_at'] != null)
                        Text(
                          'Emergencia: ${trip['emergency_at']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        'Motivo de cancelación: ${trip['cancellation_reason']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
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