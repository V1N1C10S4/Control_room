import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_vehicle_screen.dart';
import 'update_vehicle_screen.dart';

class VehicleManagementScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const VehicleManagementScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  static const Color _brand = Color.fromRGBO(90, 150, 200, 1);

  StreamSubscription<QuerySnapshot>? _sub;
  List<QueryDocumentSnapshot> _all = [];
  List<QueryDocumentSnapshot> _filtered = [];
  String _search = "";

  @override
  void initState() {
    super.initState();
    _listenVehicles();
  }

  void _listenVehicles() {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('UnidadesVehiculares')
        .where('Ciudad', isEqualTo: widget.region)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _all = snapshot.docs;
      _applySearch();
      setState(() {});
    }, onError: (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leyendo vehículos: $e')),
      );
    });
  }

  void _applySearch() {
    if (_search.isEmpty) {
      _filtered = _all;
      return;
    }
    _filtered = _all.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id.toLowerCase();
      final ciudad = (data['Ciudad'] ?? '').toString().toLowerCase();
      final placas = (data['Placas'] ?? '').toString().toLowerCase();
      final info = (data['InfoVehiculo'] ?? '').toString().toLowerCase();
      return id.contains(_search) ||
          ciudad.contains(_search) ||
          placas.contains(_search) ||
          info.contains(_search);
    }).toList();
  }

  void _confirmAndDelete(String vehicleId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Deseas eliminar esta unidad? Esta acción no se puede deshacer.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance.collection('UnidadesVehiculares').doc(vehicleId).delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unidad eliminada exitosamente.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al eliminar la unidad: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Vehículos', style: TextStyle(color: Colors.white)),
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar vehículos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (q) {
                _search = q.toLowerCase();
                _applySearch();
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No se encontraron vehículos.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final doc = _filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final foto = (data['Foto'] ?? '').toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                            child: foto.isEmpty ? const Icon(Icons.directions_car) : null,
                          ),
                          title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Ciudad: ${data['Ciudad'] ?? 'N/D'}\n'
                            'Placas: ${data['Placas'] ?? 'N/D'}\n'
                            'Vehículo: ${data['InfoVehiculo'] ?? 'N/D'}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UpdateVehicleScreen(
                                        usuario: widget.usuario,
                                        vehicleId: doc.id,
                                        vehicleData: data,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brand,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Detalles'),
                              ),
                              ElevatedButton(
                                onPressed: () => _confirmAndDelete(doc.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'vehicle_creation',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateVehicleScreen(usuario: widget.usuario, region: widget.region),
            ),
          );
        },
        backgroundColor: _brand,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Vehículo',
      ),
    );
  }
}