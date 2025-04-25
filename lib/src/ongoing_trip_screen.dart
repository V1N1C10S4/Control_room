import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            trip['status'] == 'picked up passenger' ||
            trip['status'] == 'stop_reached' ||
            trip['status'] == 'on_stop_way') &&
            trip['city']?.toLowerCase() == widget.region.toLowerCase())
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

  void _showCancelDialog(String tripId) {
    TextEditingController reasonController = TextEditingController();
    bool isConfirmButtonEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              title: const Text(
                'Cancelar Viaje',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // 80% del ancho de la pantalla
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingrese el motivo de cancelación:',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      onChanged: (text) {
                        setState(() {
                          isConfirmButtonEnabled = text.trim().isNotEmpty;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        hintText: 'Escriba el motivo aquí...',
                        filled: true,
                        fillColor: Colors.grey[200], // Color de fondo claro
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: isConfirmButtonEnabled
                      ? () {
                          Navigator.pop(context);
                          _cancelTrip(tripId, reasonController.text.trim());
                        }
                      : null,
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _cancelTrip(String tripId, String reason) async {
    try {
      final tripRef = _databaseReference.child('trip_requests').child(tripId);

      // Obtener datos actuales del viaje para saber qué conductores actualizar
      final tripSnapshot = await tripRef.get();
      final tripData = tripSnapshot.value as Map?;

      if (tripData != null) {
        final String? driverId = tripData['driver'];
        final String? driver2Id = tripData['driver2']; // Opcional

        // 🔄 Actualizar Firestore para liberar a los conductores
        final conductoresRef = FirebaseFirestore.instance.collection('Conductores');
        if (driverId != null) {
          await conductoresRef.doc(driverId).update({'Viaje': false});
        }
        if (driver2Id != null) {
          await conductoresRef.doc(driver2Id).update({'Viaje': false});
        }
      }

      // ✅ Cancelar viaje en Realtime Database
      await tripRef.update({
        'status': 'trip cancelled',
        'cancellation_reason': reason,
        'reviewed': false,
      });

      // 🧹 Quitar de la lista local
      setState(() {
        _ongoingTrips.removeWhere((trip) => trip['id'] == tripId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El viaje ha sido cancelado correctamente.'),
          backgroundColor: Colors.green,
        ),
      );

      _logger.i('Viaje $tripId cancelado con motivo: $reason');
    } catch (error) {
      _logger.e('Error al cancelar el viaje $tripId: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar el viaje. Inténtelo de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                          const SizedBox(height: 8),
                          if (trip['driver2'] != null && trip['driver2'].toString().isNotEmpty) ...[
                            Text(
                              'Conductor Secundario: ${trip['driver2']}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (trip['TelefonoConductor2'] != null && trip['TelefonoConductor2'].toString().isNotEmpty)
                              Text(
                                'Teléfono Conductor Secundario: ${trip['TelefonoConductor2']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                          const Divider(thickness: 1.2, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Punto de partida: ${trip['pickup']['placeName'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mostrar la parada única si existe
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
                              // Si no existe "stop", buscar "stop1", "stop2", etc.
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
                          const SizedBox(height: 8),
                          const Divider(thickness: 1.2, color: Colors.grey),
                          Text(
                            'Estatus: ${trip['status']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Divider(thickness: 1.2, color: Colors.grey),
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
                          if (trip.containsKey('emergency_at')) ...[
                            const SizedBox(height: 8),
                            Text(
                              '🚨 Emergencia reportada: ${_formatDateTime(trip['emergency_at'])}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          Text(
                            'Conductor asignado: ${_formatDateTime(trip['started_at'])}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Conductor en sitio: ${_formatDateTime(trip['passenger_reached_at'])}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'En camino a destino final: ${_formatDateTime(trip['picked_up_passenger_at'])}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          // Espacio adicional antes del botón
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showCancelDialog(trip['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text('Cancelar Viaje', style: TextStyle(color: Colors.white)),
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