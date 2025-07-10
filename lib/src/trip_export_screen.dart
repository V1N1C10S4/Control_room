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

    final headers = _filteredTrips.fold<Set<String>>({}, (acc, trip) {
      acc.addAll(trip.keys);
      return acc;
    }).toList();

    final rows = [headers];
    for (var trip in _filteredTrips) {
      rows.add(headers.map((key) => trip[key]?.toString() ?? '').toList());
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
                    backgroundColor: Colors.lightBlue, // Color de fondo
                    foregroundColor: Colors.white, // Color del texto
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
                    backgroundColor: Colors.lightBlue, // Color de fondo
                    foregroundColor: Colors.white, // Color del texto
                  ),
                  onPressed: _loading ? null : _loadAndFilterTrips,
                  icon: const Icon(Icons.search),
                  label: const Text("Buscar viajes"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue, // Color de fondo
                    foregroundColor: Colors.white, // Color del texto
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
                  : _filteredTrips.isEmpty
                      ? const Center(child: Text("No hay datos para mostrar."))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: _filteredTrips.first.keys
                                .map((key) => DataColumn(label: Text(key)))
                                .toList(),
                            rows: _filteredTrips
                                .map((trip) => DataRow(
                                      cells: trip.values
                                          .map((value) => DataCell(
                                              Text(value?.toString() ?? '')))
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