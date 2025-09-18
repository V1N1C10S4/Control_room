import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'route_change_review_screen.dart';
import 'generate_route_change_request_screen.dart';
import 'poi_guest_review_screen.dart';

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
  final Set<String> _tripIdsWithPendingPoiInbox = {};

  @override
  void initState() {
    super.initState();
    _fetchOngoingTrips();
    _listenPoiInboxPending();
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

  void _fetchOngoingTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final List<Map<dynamic, dynamic>> ongoingTrips = data.entries.map((entry) {
          final Map<dynamic, dynamic> trip = Map<dynamic, dynamic>.from(entry.value as Map);
          trip['id'] = entry.key;
          return trip;
        })
        .where((trip) {
          final status = trip['status'] ?? '';
          final city = trip['city']?.toLowerCase() ?? '';
          final isOngoingStatus = status == 'started' ||
                                  status == 'passenger reached' ||
                                  status == 'picked up passenger' ||
                                  status.startsWith('on_stop_way') ||
                                  status.startsWith('stop_reached');
          return isOngoingStatus && city == widget.region.toLowerCase();
        })
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

  void _listenPoiInboxPending() {
    final regionKey = widget.region.trim().toUpperCase();
    FirebaseDatabase.instance.ref('poi_inbox/$regionKey').onValue.listen((event) {
      final next = <String>{};
      final val = event.snapshot.value;
      if (val is Map) {
        val.forEach((_, raw) {
          if (raw is Map) {
            final m = Map<String, dynamic>.from(raw);
            final status = (m['status'] ?? '').toString();
            final tripId = (m['tripId'] ?? '').toString();
            if (status == 'pending' && tripId.isNotEmpty) {
              next.add(tripId);
            }
          }
        });
      }
      setState(() {
        _tripIdsWithPendingPoiInbox
          ..clear()
          ..addAll(next);
      });
    });
  }

  bool _tripHasPendingPoiGuests(Map<dynamic, dynamic> trip) {
    final gar = trip['guest_add_requests'];
    if (gar is! Map) return false;
    for (final v in gar.values) {
      if (v is Map && v['guests'] is Map) {
        final guests = v['guests'] as Map;
        for (final g in guests.values) {
          if (g is Map) {
            final st = (g['status'] ?? '').toString().trim();
            if (st.isEmpty || st == 'pending') return true;
          }
        }
      }
    }
    return false;
  }

  List<String> _approvedPoiGuests(Map<dynamic, dynamic> trip) {
    final result = <String>[];

    final gar = trip['guest_add_requests'];
    if (gar is Map) {
      gar.forEach((_, reqRaw) {
        if (reqRaw is! Map) return;
        final req = Map<String, dynamic>.from(reqRaw);

        final guests = req['guests'];
        if (guests is! Map) return;

        guests.forEach((_, gRaw) {
          if (gRaw is! Map) return;
          final g = Map<String, dynamic>.from(gRaw);

          final status = (g['status'] ?? '').toString().trim().toLowerCase();
          final isPoi = (g['poi'] == true) ||
                        ((req['reason'] ?? '').toString() == 'person_of_interest');

          if (status == 'approved' && isPoi) {
            final name = (g['name'] ?? '').toString().trim();
            if (name.isNotEmpty) result.add(name);
          }
        });
      });
    }

    return result;
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
          ? buildEmptyState(
            icon: Icons.directions_run,
            title: 'Sin viajes en progreso',
            subtitle: 'Aquí aparecerán los viajes que están actualmente en curso.',
          )
          : ListView.builder(
              itemCount: _ongoingTrips.length,
              itemBuilder: (context, index) {
                final trip = _ongoingTrips[index];
                final approvedPoi = _approvedPoiGuests(trip);
                final hasPendingPoi = _tripHasPendingPoiGuests(trip) ||
                  _tripIdsWithPendingPoiInbox.contains(
                    (trip['id'] ?? '').toString(), // defensivo por si no es String
                  );
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
                          if (approvedPoi.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'POI autorizados:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            ...approvedPoi.map((name) => Text('• $name', style: const TextStyle(fontSize: 14))),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Conductor: ${(trip['driverName'] ?? trip['driver'] ?? 'N/A').toString()}',
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
                              if (trip.containsKey("route_change_request") &&
                                  trip["route_change_request"]["status"] == "pending")
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RouteChangeReviewScreen(
                                            trip: Map<String, dynamic>.from(trip),
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Evaluar cambio de ruta',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),

                              // ✅ Botón azul solo si NO existe solicitud o no es "pending"
                              if (!trip.containsKey("route_change_request") ||
                                  trip["route_change_request"]["status"] != "pending")
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RouteChangeControlRoomScreen(
                                            trip: Map<String, dynamic>.from(trip),
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    child: const Text(
                                      'Solicitar cambio de ruta',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                if (hasPendingPoi)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PoiGuestReviewScreen(
                                            tripId: trip['id'] as String,
                                            region: widget.region,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                    ),
                                    child: const Text('Gestionar abordajes (POI)', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: () => _showCancelDialog(trip['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text(
                                  'Cancelar Viaje',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          )
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