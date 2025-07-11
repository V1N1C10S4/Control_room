import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

class TripExportScreen extends StatefulWidget {
  final String region;
  const TripExportScreen({Key? key, required this.region}) : super(key: key);

  @override
  State<TripExportScreen> createState() => _TripExportScreenState();
}

class _TripExportScreenState extends State<TripExportScreen> {
  DateTimeRange? _selectedRange;
  bool _loading = false;
  List<Map<String, dynamic>> _filteredTrips = [];
  List<String> _tableKeys = [];
  final List<String> staticFieldOrder = [
    "trip_id",
    "driver",
    "TelefonoConductor",
    "userId",
    "userName",
    "telefonoPasajero",
    "created_at",
    "city",
    "pickup",
    "pickup_coords",
    "destination",
    "destination_coords",
    "passengers",
    "luggage",
    "pets",
    "babySeats",
    "need_second_driver",
    "notes",
    "driver_feedback",
    "user_feedback",
    "emergency",
    "attended_at",
    "emergency_at",
    "emergency_location",
    "emergency_reason",
    "started_at",
    "passenger_reached_at",
    "picked_up_passenger_at",
    "finished_at",
    "status",
    "route_change_request",
    "scheduled_at",
    "cancellation_reason"
  ];

  final Map<String, String> fieldTranslations = {
    "trip_id": "Id de viaje",
    "driver": "Conductor",
    "TelefonoConductor": "Teléfono de conductor",
    "userId": "Id de pasajero",
    "userName": "Nombre de pasajero",
    "telefonoPasajero": "Teléfono pasajero",
    "created_at": "Viaje creado",
    "city": "Ciudad",
    "pickup": "Punto de partida",
    "destination": "Destino",
    "passengers": "Pasajeros",
    "luggage": "Equipaje",
    "pets": "Mascotas",
    "babySeats": "Sillas para bebé",
    "need_second_driver": "Segundo conductor requerido",
    "notes": "Notas adicionales",
    "driver_feedback": "Opinión de conductor",
    "user_feedback": "Opinión del pasajero",
    "emergency": "Emergencia",
    "attended_at": "Emergencia terminada",
    "emergency_at": "Emergencia atendida",
    "emergency_location": "Ubicación de emergencia",
    "emergency_reason": "Razón de emergencia",
    "started_at": "Viaje autorizado",
    "passenger_reached_at": "Pasajero alcanzado",
    "picked_up_passenger_at": "Pasajero recogido",
    "finished_at": "Viaje terminado",
    "status": "Estatus",
    "route_change_request": "Solicitud cambio de ruta",
    "scheduled_at": "Fecha de viaje agendado",
    "cancellation_reason": "Razón de cancelación"
  };

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
    }
  }

  Future<void> _loadAndFilterTrips() async {
    if (_selectedRange == null) return;

    setState(() {
      _loading = true;
      _filteredTrips.clear();
    });

    final ref = FirebaseDatabase.instance.ref("trip_requests");
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      setState(() => _loading = false);
      return;
    }

    final allTrips = Map<String, dynamic>.from(snapshot.value as Map);

    final filtered = allTrips.entries.where((entry) {
      final tripData = Map<String, dynamic>.from(entry.value);
      final createdAtStr = tripData['created_at']?.toString();
      final city = tripData['city']?.toString();

      if (createdAtStr == null || city != widget.region) return false;

      try {
        final createdAt = DateTime.parse(createdAtStr);
        return createdAt.isAfter(_selectedRange!.start.subtract(const Duration(seconds: 1))) &&
              createdAt.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
      } catch (_) {
        return false;
      }
    }).map((entry) {
      final data = Map<String, dynamic>.from(entry.value);
      data['trip_id'] = entry.key;

      // Extraer placeName y coordenadas de pickup
      if (data['pickup'] is Map) {
        final pickup = Map<String, dynamic>.from(data['pickup']);
        data['pickup'] = pickup['placeName'] ?? '';
        data['pickup_coords'] = '${pickup['latitude']}, ${pickup['longitude']}';
      }

      // Extraer placeName y coordenadas de destination
      if (data['destination'] is Map) {
        final destination = Map<String, dynamic>.from(data['destination']);
        data['destination'] = destination['placeName'] ?? '';
        data['destination_coords'] = '${destination['latitude']}, ${destination['longitude']}';
      }

      if (data['driver_feedback'] is Map) {
        final feedback = Map<String, dynamic>.from(data['driver_feedback']);
        data['driver_feedback'] = '''
      Comportamiento general: ${feedback['comportamientoGeneral'] ?? ''}
      Es puntual: ${feedback['esPuntual'] ?? ''}
      Seguridad del vehículo: ${feedback['seguridadVehiculo'] ?? ''}
      Calificación: ${feedback['starRating'] ?? ''}
      Comentarios adicionales: ${feedback['comentariosAdicionales'] ?? ''}
      '''.trim();
      }

      if (data['user_feedback'] is Map) {
        final feedback = Map<String, dynamic>.from(data['user_feedback']);
        data['user_feedback'] = '''
      Siguió reglas de tránsito: ${feedback['followedTrafficRules'] ?? ''}
      Servicio general: ${feedback['generalService'] ?? ''}
      Seguridad del vehículo: ${feedback['vehicleSafety'] ?? ''}
      Calificación: ${feedback['starRating'] ?? ''}
      Comentarios adicionales: ${feedback['additionalComments'] ?? ''}
      '''.trim();
      }

      // Formatear emergency_location si es un Map con lat/lng
      if (data['emergency_location'] is Map) {
        final emergency = Map<String, dynamic>.from(data['emergency_location']);
        data['emergency_location'] = '${emergency['latitude']}, ${emergency['longitude']}';
      }

      // Extraer status de solicitud de cambio de ruta si existe
      if (data['route_change_request'] is Map) {
        final rcr = Map<String, dynamic>.from(data['route_change_request']);
        data['route_change_request'] = rcr['status'] ?? '';
      }

      // Extraer paradas dinámicas stop_x
      final stopKeys = data.keys
        .where((k) => RegExp(r'^stop\d+$').hasMatch(k))
        .toList(); // 👈 aquí el cambio

      for (final key in stopKeys) {
        if (data[key] is Map) {
          final stop = Map<String, dynamic>.from(data[key]);
          data[key] = stop['placeName'] ?? '';
          data['${key}_coords'] = '${stop['latitude']}, ${stop['longitude']}';
        }
      }

      return data;
    }).toList();

    // 🔁 Construcción de _tableKeys
    final dynamicStops = <String>{};
    final stopCoords = <String>{};
    final dynamicStopWays = <String>{};
    final dynamicStopReached = <String>{};

    for (final trip in filtered) {
  trip.keys.forEach((key) {
    final parts = key.split('_');
    
      // ✅ Detectar correctamente stop_x
      if (RegExp(r'^stop\d+$').hasMatch(key)) {
        dynamicStops.add(key);
        final coordKey = '${key}_coords';
        if (trip.containsKey(coordKey)) {
          stopCoords.add(coordKey);
        }
      }

      // 🔒 Mantener condiciones existentes
      if (key.startsWith('on_stop_way_') && key.endsWith('_at') && parts.length >= 4) {
        final stopNum = int.tryParse(parts[3]);
        if (stopNum != null) {
          dynamicStopWays.add(key);
        }
      }

      if (key.startsWith('stop_reached_') && key.endsWith('_at') && parts.length >= 4) {
        final stopNum = int.tryParse(parts[2]);
        if (stopNum != null) {
          dynamicStopReached.add(key);
        }
      }
    });
  }

    final sortedStops = dynamicStops.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceFirst('stop', ''));
        final bNum = int.tryParse(b.replaceFirst('stop', ''));
        return (aNum ?? 0).compareTo(bNum ?? 0);
      });

    final sortedStopCoords = stopCoords.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'stop(\d+)_coords'), r'$1'));
        final bNum = int.tryParse(b.replaceAll(RegExp(r'stop(\d+)_coords'), r'$1'));
        return (aNum ?? 0).compareTo(bNum ?? 0);
      });

    final sortedStopWays = dynamicStopWays.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.split('_')[3]);
        final bNum = int.tryParse(b.split('_')[3]);
        return (aNum ?? 0).compareTo(bNum ?? 0);
      });

    final sortedStopReached = dynamicStopReached.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.split('_')[2]);
        final bNum = int.tryParse(b.split('_')[2]);
        return (aNum ?? 0).compareTo(bNum ?? 0);
      });

    // Insertar dinámicamente después de 'pickup_coords'
    final indexAfterPickupCoords = staticFieldOrder.indexOf('pickup_coords') + 1;

    print('✅ sortedStops: $sortedStops');
    print('✅ sortedStopCoords: $sortedStopCoords');

    _tableKeys = List.from(staticFieldOrder);

    for (int i = 0; i < sortedStops.length; i++) {
      _tableKeys.insert(indexAfterPickupCoords + i * 2, sortedStops[i]);
      final coordKey = '${sortedStops[i]}_coords';
      if (sortedStopCoords.contains(coordKey)) {
        _tableKeys.insert(indexAfterPickupCoords + i * 2 + 1, coordKey);
      }
    }

    // Añadir los demás campos al final
    _tableKeys.addAll([
      ...sortedStopWays,
      ...sortedStopReached,
    ]);

    print('📋 _tableKeys: $_tableKeys');

    if (filtered.isNotEmpty) {
      print('🧪 Ejemplo de trip: ${filtered.first}');
    }

    setState(() {
      _filteredTrips = filtered;
      _loading = false;
    });
  }

  void _exportCSV() {
    if (_filteredTrips.isEmpty) return;

    final headerRow = _tableKeys.map((key) {
      if (fieldTranslations.containsKey(key)) return fieldTranslations[key]!;

      if (key.startsWith("stop_reached_")) {
        final parts = key.split("_");
        if (parts.length >= 4) return "Parada ${parts[2]} alcanzada";
      }

      if (key.startsWith("on_stop_way_")) {
        final parts = key.split("_");
        if (parts.length >= 4) return "En camino a parada ${parts[3]}";
      }

      if (RegExp(r'^stop\d+$').hasMatch(key)) {
        final index = key.replaceFirst('stop', '');
        return "Parada $index";
      }

      if (key.endsWith("_coords")) {
        return "Coordenadas de ${_labelFromKey(key)}";
      }

      return key;
    }).toList();

    final rows = [headerRow];

    for (final trip in _filteredTrips) {
      final row = _tableKeys.map((key) {
        final rawValue = trip[key];

        // 🕓 Formato de fecha legible
        if (rawValue is String &&
            RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(rawValue)) {
          try {
            final parsedDate = DateTime.parse(rawValue);
            return DateFormat('dd/MM/yy HH:mm:ss').format(parsedDate);
          } catch (_) {
            return rawValue;
          }
        }

        return rawValue?.toString() ?? '';
      }).toList();

      rows.add(row);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "exported_trips.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _labelFromKey(String key) {
    if (key.startsWith('pickup')) return 'punto de partida';
    if (key.startsWith('destination')) return 'destino';
    if (key.startsWith('stop') && key.endsWith('_coords')) {
      final match = RegExp(r'stop(\d+)_coords').firstMatch(key);
      if (match != null) return 'parada ${match.group(1)}';
    }
    return key;
  }

  Widget _buildEmptyStateWithoutRange() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "Selecciona un rango de fechas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          SizedBox(height: 10),
          Text(
            "Usa el botón de calendario para filtrar los viajes a exportar.",
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            "No se encontraron viajes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          SizedBox(height: 10),
          Text(
            "Intenta cambiar el rango de fechas o verifica la región.",
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exportar Viajes", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.lightBlue,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text("Seleccionar rango de fechas"),
                ),
                const SizedBox(width: 12),
                if (_selectedRange != null)
                  Text(DateFormat('yyyy-MM-dd').format(_selectedRange!.start) +
                      " → " +
                      DateFormat('yyyy-MM-dd').format(_selectedRange!.end)),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _loadAndFilterTrips,
                  icon: const Icon(Icons.search),
                  label: const Text("Buscar viajes"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _filteredTrips.isEmpty ? null : _exportCSV,
                  icon: const Icon(Icons.file_download),
                  label: const Text("Exportar CSV"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedRange == null
                      ? _buildEmptyStateWithoutRange()
                      : _filteredTrips.isEmpty
                          ? _buildEmptyStateNoResults()
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical, // Scroll vertical por filas
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal, // Scroll horizontal por columnas
                                child: DataTable(
                                  columns: _tableKeys.map((key) {
                                    if (fieldTranslations.containsKey(key)) {
                                      return DataColumn(label: Text(fieldTranslations[key]!));
                                    } else if (key.startsWith('stop_reached_')) {
                                      final parts = key.split('_');
                                      if (parts.length >= 4 && int.tryParse(parts[2]) != null && parts[3] == 'at') {
                                        final index = parts[2];
                                        return DataColumn(label: Text('Parada $index alcanzada'));
                                      } else {
                                        return DataColumn(label: Text('Parada desconocida'));
                                      }
                                    } else if (key.startsWith('on_stop_way_')) {
                                      final parts = key.split('_');
                                      if (parts.length >= 4 && int.tryParse(parts[3]) != null) {
                                        final index = parts[3];
                                        return DataColumn(label: Text('En camino a parada $index'));
                                      } else {
                                        return DataColumn(label: Text('Camino desconocido'));
                                      }
                                    } else if (RegExp(r'^stop\d+$').hasMatch(key)) {
                                      final index = key.replaceFirst('stop', '');
                                      return DataColumn(label: Text('Parada $index'));
                                    } else if (key.endsWith('_coords')) {
                                      return DataColumn(label: Text('Coordenadas de ${_labelFromKey(key)}'));
                                    }
                                    return DataColumn(label: Text(key));
                                  }).toList(),
                                  rows: _filteredTrips.map((trip) => DataRow(
                                    cells: _tableKeys.map((key) {
                                      final rawValue = trip[key];
                                      if (rawValue is String &&
                                          RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(rawValue)) {
                                        try {
                                          final parsedDate = DateTime.parse(rawValue);
                                          final formatted = DateFormat('dd/MM/yy HH:mm:ss').format(parsedDate);
                                          return DataCell(Text(formatted));
                                        } catch (_) {
                                          return DataCell(Text(rawValue));
                                        }
                                      }
                                      return DataCell(Text(rawValue?.toString() ?? ''));
                                    }).toList(),
                                  )).toList(),
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}