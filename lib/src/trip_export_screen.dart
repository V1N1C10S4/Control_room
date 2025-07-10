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
    "destination",
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
      return data;
    }).toList();

    // 🔁 Construcción de _tableKeys
    final dynamicStops = <String>{};
    final dynamicStopWays = <String>{};
    final dynamicStopReached = <String>{};

    for (final trip in filtered) {
      trip.keys.forEach((key) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final stopNum = int.tryParse(parts[1]);
          if (stopNum != null) {
            dynamicStops.add(key);
          }
        }
        if (key.startsWith('on_stop_way_') && key.endsWith('_at') && parts.length >= 4) {
          final stopNum = int.tryParse(parts[3]);
          if (stopNum != null) {
            dynamicStopWays.add(key);
          }
        }
        if (key.startsWith('stop_reached_') && key.endsWith('_at')) {
          final parts = key.split('_');
          if (parts.length >= 4) {
            final stopNum = int.tryParse(parts[2]);
            if (stopNum != null) {
              dynamicStopReached.add(key);
            }
          }
        }
      });
    }

    final sortedStops = dynamicStops.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.split('_')[1]);
        final bNum = int.tryParse(b.split('_')[1]);
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

    _tableKeys = [
      ...staticFieldOrder,
      ...sortedStops,
      ...sortedStopWays,
      ...sortedStopReached,
    ];

    setState(() {
      _filteredTrips = filtered;
      _loading = false;
    });
  }

  void _exportCSV() {
    if (_filteredTrips.isEmpty) return;

    final List<String> dynamicStops = [];
    final List<String> dynamicStopWays = [];
    final List<String> dynamicStopReached = [];

    for (final trip in _filteredTrips) {
      trip.keys.forEach((key) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final stopNum = int.tryParse(parts[1]);
          if (stopNum != null) {
            dynamicStops.add(key);
          }
        }
        if (key.startsWith('on_stop_way_') && key.endsWith('_at') && parts.length >= 4) {
          final stopNum = int.tryParse(parts[3]);
          if (stopNum != null) {
            dynamicStopWays.add(key);
          }
        }
        if (key.startsWith('stop_reached_') && key.endsWith('_at')) {
          final parts = key.split('_');
          if (parts.length >= 4) {
            final stopNum = int.tryParse(parts[2]);
            if (stopNum != null) {
              dynamicStopReached.add(key);
            }
          }
        }
      });
    }

    dynamicStops.sort((a, b) {
      final aNum = int.tryParse(a.split('_')[1]);
      final bNum = int.tryParse(b.split('_')[1]);
      return (aNum ?? 0).compareTo(bNum ?? 0);
    });
    dynamicStopWays.sort((a, b) {
      final aParts = a.split('_');
      final bParts = b.split('_');
      final aNum = aParts.length >= 4 ? int.tryParse(aParts[3]) : null;
      final bNum = bParts.length >= 4 ? int.tryParse(bParts[3]) : null;
      return (aNum ?? 0).compareTo(bNum ?? 0);
    });

    dynamicStopReached.sort((a, b) {
      final aParts = a.split('_');
      final bParts = b.split('_');
      final aNum = aParts.length >= 3 ? int.tryParse(aParts[2]) : null;
      final bNum = bParts.length >= 3 ? int.tryParse(bParts[2]) : null;
      return (bNum ?? 0).compareTo(aNum ?? 0);
    });

    final allKeysOrdered = [
      ...staticFieldOrder,
      ...dynamicStops,
      ...dynamicStopWays,
      ...dynamicStopReached,
    ];

    final headerRow = allKeysOrdered.map((key) {
      if (fieldTranslations.containsKey(key)) return fieldTranslations[key]!;
      if (key.startsWith("stop_")) {
        final index = key.split("_")[1];
        return "Parada $index";
      }
      if (key.startsWith("on_stop_way_")) {
        final index = key.split("_")[3];
        return "En camino a parada $index";
      }
      if (key.startsWith("stop_reached_")) {
        final index = key.split("_")[2];
        return "Parada $index alcanzada";
      }
      return key;
    }).toList();

    final rows = [headerRow];
    for (var trip in _filteredTrips) {
      final row = allKeysOrdered.map((key) => trip[key]?.toString() ?? '').toList();
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
                              scrollDirection: Axis.horizontal,
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
                                  } else if (key.startsWith('stop_')) {
                                    final index = key.split('_')[1];
                                    return DataColumn(label: Text('Parada $index'));
                                  }
                                  return DataColumn(label: Text(key));
                                }).toList(),
                                rows: _filteredTrips.map((trip) => DataRow(
                                  cells: _tableKeys.map((key) => DataCell(Text(trip[key]?.toString() ?? ''))).toList(),
                                )).toList(),
                              )
                            ),
            ),
          ],
        ),
      ),
    );
  }
}