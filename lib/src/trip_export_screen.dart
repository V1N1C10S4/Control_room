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
        if (key.startsWith('stop_') && RegExp(r'stop_\d+\$').hasMatch(key)) {
          if (!dynamicStops.contains(key)) dynamicStops.add(key);
        }
        if (key.startsWith('on_stop_way_') && key.endsWith('_at')) {
          if (!dynamicStopWays.contains(key)) dynamicStopWays.add(key);
        }
        if (key.startsWith('stop_reached_') && key.endsWith('_at')) {
          if (!dynamicStopReached.contains(key)) dynamicStopReached.add(key);
        }
      });
    }

    dynamicStops.sort((a, b) => int.parse(a.split('_')[1]).compareTo(int.parse(b.split('_')[1])));
    dynamicStopWays.sort((a, b) => int.parse(a.split('_')[3]).compareTo(int.parse(b.split('_')[3])));
    dynamicStopReached.sort((a, b) => int.parse(b.split('_')[2]).compareTo(int.parse(a.split('_')[2])));

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
                                columns: _filteredTrips.first.keys
                                    .map((key) => DataColumn(label: Text(key)))
                                    .toList(),
                                rows: _filteredTrips
                                    .map((trip) => DataRow(
                                          cells: trip.values
                                              .map((value) =>
                                                  DataCell(Text(value?.toString() ?? '')))
                                              .toList(),
                                        ))
                                    .toList(),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}