import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VehiclesAvailability extends StatelessWidget {
  final String usuario;
  final String region;

  const VehiclesAvailability({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  Widget build(BuildContext context) {
    final vehiclesQuery = FirebaseFirestore.instance
        .collection('UnidadesVehiculares')
        .where('Ciudad', isEqualTo: region);

    final busyDriversQuery = FirebaseFirestore.instance
        .collection('Conductores')
        .where('Ciudad', isEqualTo: region)
        .where('Viaje', isEqualTo: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehículos Disponibles', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(90, 150, 200, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: vehiclesQuery.snapshots(),
        builder: (context, vehicleSnap) {
          if (!vehicleSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final vehicles = vehicleSnap.data!.docs; // mismos de la región

          // Segundo stream: conductores ocupados (Viaje == true) en la región
          return StreamBuilder<QuerySnapshot>(
            stream: busyDriversQuery.snapshots(),
            builder: (context, driversSnap) {
              // Si falla o no llega aún, seguimos como si no hubiera ninguno ocupado
              final busyVehicleIds = <String>{};
              if (driversSnap.hasData) {
                for (final d in driversSnap.data!.docs) {
                  final m = d.data() as Map<String, dynamic>;
                  final vid = (m['vehicleId'] ?? '').toString().trim();
                  if (vid.isNotEmpty) busyVehicleIds.add(vid);
                }
              }

              final available = <QueryDocumentSnapshot>[];
              final unavailable = <QueryDocumentSnapshot>[];

              for (final v in vehicles) {
                final data = v.data() as Map<String, dynamic>;
                final vehId = v.id;
                final disponible = (data['Disponible'] as bool?) ?? true;
                final isBusy = busyVehicleIds.contains(vehId);

                // Mismo criterio que con conductores:
                // Disponible SOLO si flag true y no está en un viaje
                if (disponible && !isBusy) {
                  available.add(v);
                } else {
                  unavailable.add(v);
                }
              }

              Widget buildCard(QueryDocumentSnapshot doc, {required bool isAvailable}) {
                final m = doc.data() as Map<String, dynamic>;
                final rawFoto = (m['Foto'] ?? '').toString().trim();
                final hasImage = rawFoto.isNotEmpty; // opcional: && rawFoto.startsWith('http');
                final info = (m['InfoVehiculo'] ?? '').toString();
                final placas = (m['Placas'] ?? '').toString();
                final ciudad = (m['Ciudad'] ?? '').toString();
                final disponible = (m['Disponible'] as bool?) ?? true;
                final isBusy = busyVehicleIds.contains(doc.id);
                final reason = isBusy
                    ? 'Viaje en progreso'
                    : (disponible ? 'Disponible' : 'Fuera de servicio');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(
                        color: isAvailable ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.transparent,
                            backgroundImage: hasImage ? CachedNetworkImageProvider(rawFoto) : null,
                            // Evita que una imagen corrupta/HTML rompa la UI
                            onBackgroundImageError: (Object error, StackTrace? stackTrace) {
                              // puedes loguear si quieres: debugPrint('Foto vehículo inválida: $error');
                            },
                            // Fallback visual cuando no hay imagen o falló la carga
                            child: !hasImage ? const Icon(Icons.directions_car, size: 40) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vehículo: ${doc.id}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Ubicación: $ciudad'),
                                Text('Info. del vehículo: $info'),
                                Text('Placas: ${placas.isEmpty ? "N/D" : placas}'),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                            decoration: BoxDecoration(
                              color: isBusy
                                  ? Colors.red
                                  : (disponible ? Colors.green : Colors.orange),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              reason,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Vehículos disponibles:',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: available.length,
                            itemBuilder: (context, i) =>
                                buildCard(available[i], isAvailable: true),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Vehículos no disponibles:',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: unavailable.length,
                            itemBuilder: (context, i) =>
                                buildCard(unavailable[i], isAvailable: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}