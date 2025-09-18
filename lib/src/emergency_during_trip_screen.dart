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
  List<Map<dynamic, dynamic>> _inProgressEmergencies = [];
  List<Map<dynamic, dynamic>> _resolvedEmergencies = [];

  @override
  void initState() {
    super.initState();
    _fetchEmergencyTrips();
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
        content: const Text('¿Estás seguro de que quieres marcar esta emergencia como atendida?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final tripRef = _databaseReference.child('trip_requests').child(tripId);
                final snap = await tripRef.get();
                final Map<dynamic, dynamic>? tripData = snap.value as Map<dynamic, dynamic>?;

                if (tripData == null) return;

                // ✅ Nuevo candado: solo si la emergencia sigue activa
                if (tripData['emergency'] != true) {
                  _logger.w('La emergencia ya fue atendida por otro operador.');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La emergencia ya fue atendida por otro operador.')),
                    );
                  }
                  return;
                }

                final nowIso = DateTime.now().toIso8601String();

                // (Opcional) historial de atenciones
                final List<dynamic> history =
                    (tripData['emergency_history'] as List?)?.toList() ?? <dynamic>[];
                history.add({
                  'emergency_at': tripData['emergency_at'],
                  'attended_at': nowIso,
                });

                await tripRef.update({
                  'emergency': false,          // 🔻 desactiva
                  'attended_at': nowIso,       // última atención (se sobreescribe cada vez)
                  'emergency_history': history // opcional, conserva registro
                });

                _logger.i('Emergencia atendida para el viaje $tripId.');
                // No hace falta _fetchEmergencyTrips(); onValue refresca solo
              } catch (error) {
                _logger.e('Error al actualizar emergencia: $error');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  Widget _buildEmergencyCard(Map<dynamic, dynamic> trip, bool isInProgress) {
    final emergencyLocation = trip['emergency_location'] as Map<dynamic, dynamic>?;
    final latitude = emergencyLocation?['latitude']?.toString() ?? 'N/A';
    final longitude = emergencyLocation?['longitude']?.toString() ?? 'N/A';
    final approvedPoi = _approvedPoiGuests(trip);

    // Verificar si el número del pasajero existe, de lo contrario mostrar "No disponible"
    String telefonoPasajero = trip.containsKey('telefonoPasajero') && trip['telefonoPasajero'] != null && trip['telefonoPasajero'].toString().trim().isNotEmpty
      ? trip['telefonoPasajero']
      : "No disponible";

    // ✅ Verificar si el número del conductor existe, de lo contrario mostrar "No disponible"
    String telefonoConductor = trip.containsKey('TelefonoConductor') && trip['TelefonoConductor'] != null && trip['TelefonoConductor'].toString().trim().isNotEmpty
        ? trip['TelefonoConductor']
        : "No disponible";

    // Obtener tiempo transcurrido si la emergencia ya fue atendida
    String tiempoAtencion = "No disponible";
    if (!isInProgress && trip.containsKey('emergency_at') && trip.containsKey('attended_at')) {
      try {
        DateTime emergencyTime = DateTime.parse(trip['emergency_at']);
        DateTime attendedTime = DateTime.parse(trip['attended_at']);
        Duration diferencia = attendedTime.difference(emergencyTime);
        tiempoAtencion = "${diferencia.inMinutes} min"; // Convertir a minutos
      } catch (e) {
        tiempoAtencion = "Error en formato de fecha";
      }
    }

    String emergencyReason = trip.containsKey('emergency_reason') &&
            trip['emergency_reason'] != null &&
            trip['emergency_reason'].toString().trim().isNotEmpty
        ? trip['emergency_reason']
        : "N/A";

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
                'Conductor: ${trip['driverName']?.toString().trim().isNotEmpty == true
                    ? trip['driverName']
                    : (trip['driver']?.toString().isNotEmpty == true ? trip['driver'] : 'N/A')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teléfono del conductor: $telefonoConductor',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              if (trip['driver2'] != null && trip['driver2'].toString().trim().isNotEmpty) ...[
                Text(
                  'Conductor secundario: ${trip['driver2Name']?.toString().trim().isNotEmpty == true
                      ? trip['driver2Name']
                      : (trip['driver2']?.toString().isNotEmpty == true ? trip['driver2'] : 'N/A')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (trip['TelefonoConductor2'] != null && trip['TelefonoConductor2'].toString().trim().isNotEmpty) ...[
                  Text(
                    'Teléfono del conductor secundario: ${trip['TelefonoConductor2']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              Text(
                'Pasajero: ${trip['userName'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Teléfono del pasajero: $telefonoPasajero',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (approvedPoi.isNotEmpty) ...[
                const Text(
                  'POI autorizados:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...approvedPoi.map(
                  (name) => Text('• $name', style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Punto de partida: ${trip['pickup']?['placeName'] ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                for (int i = 1; trip.containsKey('stop$i'); i++)
                  Text(
                    'Parada $i: ${trip['stop$i']['placeName'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (trip.containsKey('stop1')) const SizedBox(height: 8), // ✅ Solo añade espacio si hay paradas
              ],
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
                // ✅ Mostrar la razón de la emergencia en ROJO
              Text(
                'Causa de emergencia: $emergencyReason',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red, // 🔴 Texto en rojo
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
              if (!isInProgress) ...[
                const SizedBox(height: 8),
                Text(
                  'Atendida en: ${_formatDateTime(trip['attended_at'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tiempo de atención: $tiempoAtencion',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
              ],
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
      body: (_inProgressEmergencies.isEmpty && _resolvedEmergencies.isEmpty)
          ? buildEmptyState(
              icon: Icons.warning_amber_rounded,
              title: 'Sin emergencias activas',
              subtitle: 'Aquí se mostrarán las emergencias reportadas en tiempo real.',
          )
          : Column(
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