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

  Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
          ? buildEmptyState(
            icon: Icons.directions_car_filled,
            title: 'Sin viajes finalizados',
            subtitle: 'Aquí se mostrarán los viajes completados recientemente.',
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
                            'Pasajero: ${trip['userName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Conductor: ${trip['driver'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          if (trip['TelefonoConductor'] != null && trip['TelefonoConductor'].toString().isNotEmpty)
                            Text(
                              'Teléfono Conductor: ${trip['TelefonoConductor']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          if (trip['TelefonoConductor'] != null && trip['TelefonoConductor'].toString().isNotEmpty)
                            const SizedBox(height: 8),

                          if (trip['driver2'] != null && trip['driver2'].toString().isNotEmpty) ...[
                            Text(
                              'Conductor Secundario: ${trip['driver2']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (trip['TelefonoConductor2'] != null && trip['TelefonoConductor2'].toString().isNotEmpty) ...[
                              Text(
                                'Teléfono Conductor Secundario: ${trip['TelefonoConductor2']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                          const Divider(thickness: 1.2, color: Colors.grey),
                          Text(
                            'Punto de partida: ${trip['pickup']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
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

                                 for (int i = 1; i <= 5; i++) {
                                  String stopKey = 'stop$i';
                                  if (trip.containsKey(stopKey)) {
                                    stops.add(
                                      Text(
                                        'Parada $i: ${trip[stopKey]['placeName'] ?? 'N/A'}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    );

                                    if (trip.containsKey('on_stop_way_${i}_at')) {
                                      stops.add(Text(
                                        '🚕 En camino a la parada: ${_formatDateTime(trip['on_stop_way_${i}_at'])}',
                                        style: const TextStyle(fontSize: 14, color: Colors.orange),
                                      ));
                                    }

                                    if (trip.containsKey('stop_reached_${i}_at')) {
                                      stops.add(Text(
                                        '📍 Llegada a parada: ${_formatDateTime(trip['stop_reached_${i}_at'])}',
                                        style: const TextStyle(fontSize: 14, color: Colors.blue),
                                      ));
                                    }
                                  }
                                }
                                return stops;
                              })(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Destino: ${trip['destination']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Divider(thickness: 1.2, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Estatus: ${trip['status']}',
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
                          const Divider(thickness: 1.2, color: Colors.grey),
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