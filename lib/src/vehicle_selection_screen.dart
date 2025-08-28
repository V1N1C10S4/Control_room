import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleSelectionScreen extends StatefulWidget {
  final String driverId;      // conductor al que le cambiaremos el vehículo
  final String region;        // ciudad/region del flujo
  final String? userCity;     // si ya la tienes calculada, úsala; si no, region
  final String? currentVehicleId; // opcional: para marcar el actual

  const VehicleSelectionScreen({
    super.key,
    required this.driverId,
    required this.region,
    this.userCity,
    this.currentVehicleId,
  });

  @override
  State<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends State<VehicleSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, dynamic>? _selected;

  bool _loading = true;
  String? _error;

  String get _city => (widget.userCity ?? widget.region).trim();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  String _canonicalCity(String c) {
    final s = c.trim().toLowerCase();
    if (s == 'cdmx' || s == 'ciudad de méxico' || s == 'ciudad de mexico') return 'CDMX';
    if (s == 'tabasco') return 'Tabasco';
    return c.trim(); // fallback: deja tal cual
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final qCity = _canonicalCity(_city);

      // 1) Vehículos disponibles en la ciudad
      final vSnap = await FirebaseFirestore.instance
          .collection('UnidadesVehiculares')
          .where('Ciudad', isEqualTo: qCity)
          .where('Disponible', isEqualTo: true)
          .get();

      // 2) Conductores EN VIAJE en esa ciudad -> vehículo ocupado
      final busySnap = await FirebaseFirestore.instance
          .collection('Conductores')
          .where('Ciudad', isEqualTo: qCity)
          .where('Viaje', isEqualTo: true)
          .get();

      final busyVehicleIds = <String>{
        for (final d in busySnap.docs)
          (d.data()['vehicleId'] ?? '').toString().trim(),
      }..removeWhere((e) => e.isEmpty);

      // 3) Construir lista y EXCLUIR vehículos ocupados
      final vehicles = <Map<String, dynamic>>[];
      for (final doc in vSnap.docs) {
        if (busyVehicleIds.contains(doc.id)) continue; // filtramos ocupados

        final m = doc.data();
        vehicles.add({
          'id': doc.id,
          'Ciudad': (m['Ciudad'] ?? '').toString(),
          'InfoVehiculo': (m['InfoVehiculo'] ?? '').toString(),
          'Placas': (m['Placas'] ?? '').toString(),
          'Foto': (m['Foto'] ?? '').toString(),
          'Disponible': (m['Disponible'] as bool?) ?? true,
        });
      }

      // Logs opcionales
      debugPrint('Vehículos (ciudad=$qCity, disponibles=true): ${vSnap.docs.length}');
      debugPrint('VehicleIds ocupados: $busyVehicleIds');
      debugPrint('Vehículos listados en UI: ${vehicles.length}');

      setState(() {
        _vehicles = vehicles;
        _filtered = vehicles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error al cargar vehículos: $e';
      });
    }
  }

  void _filter(String q) {
    final s = q.toLowerCase().trim();
    if (s.isEmpty) {
      setState(() => _filtered = List.from(_vehicles));
      return;
    }
    setState(() {
      _filtered = _vehicles.where((v) {
        final id    = (v['id'] ?? '').toString().toLowerCase();
        final city  = (v['Ciudad'] ?? '').toString().toLowerCase();
        final info  = (v['InfoVehiculo'] ?? '').toString().toLowerCase();
        final plate = (v['Placas'] ?? '').toString().toLowerCase();
        return id.contains(s) || city.contains(s) || info.contains(s) || plate.contains(s);
      }).toList();
    });
  }

  Widget _vehicleAvatar(dynamic fotoField) {
    final url = (fotoField ?? '').toString().trim();
    final ok = Uri.tryParse(url)?.hasScheme == true;

    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey.shade200,
      child: ok
          ? ClipOval(
              child: Image.network(
                url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Colors.grey),
              ),
            )
          : const Icon(Icons.directions_car, color: Colors.grey),
    );
  }

  Future<void> _confirmSelection() async {
    if (_selected == null) return;
    try {
      final fotoVehiculo = (_selected!['Foto'] ?? '').toString();

      await FirebaseFirestore.instance
          .collection('Conductores')
          .doc(widget.driverId)
          .update({
        'vehicleId': _selected!['id'],
        'InfoVehiculo': _selected!['InfoVehiculo'] ?? '',
        'Placas': _selected!['Placas'] ?? '',
        'FotoVehiculo': fotoVehiculo,
      });

      if (!mounted) return;
      Navigator.pop(context, {
        'vehicleId'    : _selected!['id'],
        'InfoVehiculo' : _selected!['InfoVehiculo'],
        'Placas'       : _selected!['Placas'],
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo asignar el vehículo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = (widget.currentVehicleId ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar vehículo', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(90, 150, 200, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Búsqueda
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por id, ciudad, vehículo o placas...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        onChanged: _filter,
                      ),
                      const SizedBox(height: 12),

                      // Aviso si ya tiene uno actual
                      if (currentId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Vehículo actual del conductor: $currentId',
                                  style: const TextStyle(color: Colors.blueGrey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Lista
                      Expanded(
                        child: _filtered.isEmpty
                            ? const Center(
                                child: Text('No hay vehículos disponibles con los filtros.'),
                              )
                            : ListView.builder(
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final v = _filtered[i];
                                  final isSelected = _selected?['id'] == v['id'];

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: _vehicleAvatar(v['Foto']),
                                      title: Text(
                                        'Vehículo: ${v['id']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        'Ciudad: ${v['Ciudad']}  ·  Info: ${v['InfoVehiculo']}  ·  Placas: ${v['Placas'].toString().isEmpty ? "N/D" : v['Placas']}',
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: () {
                                          setState(() => _selected = v);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSelected ? Colors.grey : Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20.0),
                                          ),
                                        ),
                                        child: Text(
                                          isSelected ? 'Seleccionado' : 'Seleccionar',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Resumen selección
                      if (_selected != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: Colors.blue.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.directions_car, color: Colors.blue),
                            title: Text(
                              'Vehículo seleccionado: ${_selected!["id"]}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Info: ${_selected!["InfoVehiculo"]}\nPlacas: ${_selected!["Placas"].toString().isEmpty ? "N/D" : _selected!["Placas"]}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _selected = null),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Cancelar selección', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _confirmSelection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(90, 150, 200, 1),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Confirmar selección', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}