import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_driver_screen.dart';

class ScheduledTripScreen extends StatelessWidget {
  final String region;

  const ScheduledTripScreen({Key? key, required this.region}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Viajes Programados',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        backgroundColor: const Color.fromRGBO(180, 180, 255, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref()
            .child("trip_requests")
            .orderByChild("status")
            .onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          Map<dynamic, dynamic> tripMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> scheduledTrips = tripMap.entries
              .map((entry) {
                var trip = Map<String, dynamic>.from(entry.value);
                trip["tripId"] = entry.key; // Guardamos el ID del viaje
                return trip;
              })
              .where((trip) =>
                  trip.containsKey("city") &&
                  trip["city"].toString().toLowerCase() ==
                      region.toLowerCase() &&
                  (trip["status"] == "scheduled" ||
                      trip["status"] == "scheduled approved"))
              .toList();

          if (scheduledTrips.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: scheduledTrips.length,
            itemBuilder: (context, index) {
              final trip = scheduledTrips[index];
              return _buildTripCard(trip, context);
            },
          );
        },
      ),
    );
  }

  void _updateTripStatus(String tripId, String newStatus) {
    FirebaseDatabase.instance.ref().child("trip_requests/$tripId").update({
      "status": newStatus,
    }).then((_) {
      // ignore: avoid_print
      print("Estado actualizado a: $newStatus");
    }).catchError((error) {
      // ignore: avoid_print
      print("Error al actualizar estado: $error");
    });
  }

  void _showConfirmationDialog(BuildContext context, String title, String message,
      String newStatus, String tripId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateTripStatus(tripId, newStatus);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text("Confirmar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// 🟢 Estado vacío si no hay viajes programados
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text("No hay viajes programados!",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          SizedBox(height: 10),
          Text("Los viajes programados aparecerán en esta pantalla.",
              style: TextStyle(fontSize: 14, color: Colors.black45)),
        ],
      ),
    );
  }

  /// 🟢 Construye la tarjeta de cada viaje programado
  Widget _buildTripCard(Map<String, dynamic> trip, BuildContext context) {
    String formattedDate = trip["scheduled_at"] != null
        ? DateFormat("yyyy-MM-dd HH:mm")
            .format(DateTime.parse(trip["scheduled_at"]))
        : "Unknown";

    String createdDate = trip["created_at"] != null
        ? DateFormat("yyyy-MM-dd HH:mm")
            .format(DateTime.parse(trip["created_at"]))
        : "Unknown";

    String userName = trip["userName"] ?? "Usuario desconocido";
    String telefono = trip["telefonoPasajero"] ?? "Sin número";
    final hasPre1 = (trip['preassigned_driver'] ?? '').toString().isNotEmpty;
    final hasPre2 = (trip['preassigned_driver2'] ?? '').toString().isNotEmpty;

    // 🔥 Determinar el ícono de estado basado en el status
    Icon statusIcon;
    if (trip["status"] == "scheduled") {
      statusIcon =
          const Icon(Icons.schedule, color: Colors.blue, size: 30); // ⏳ Azul
    } else if (trip["status"] == "scheduled approved") {
      statusIcon = const Icon(Icons.check_circle,
          color: Colors.green, size: 30); // ✅ Verde
    } else {
      statusIcon = const Icon(Icons.help_outline,
          color: Colors.grey, size: 30); // Por si hay un estado inesperado
    }

    // Extraer paradas intermedias
    List<String> stops = [];
    if (trip.containsKey("stop")) {
      stops.add(trip["stop"]["placeName"] ?? "Unknown Stop");
    } else {
      int stopIndex = 1;
      while (trip.containsKey("stop$stopIndex")) {
        stops.add(trip["stop$stopIndex"]["placeName"] ?? "Unknown Stop");
        stopIndex++;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("👤 Pasajero: $userName",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("📞 Teléfono: $telefono",
                          style: const TextStyle(fontSize: 16)),
                      Text(
                        "📍 Punto de partida: ${trip["pickup"]["placeName"] ?? "Unknown"}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (stops.isNotEmpty) ...[
                        for (var stop in stops)
                          Text(
                            "🛑 Parada: $stop",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                      ],
                      Text(
                        "📍 Destino: ${trip["destination"]["placeName"] ?? "Unknown"}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                statusIcon, // 🔥 Ícono dinámico basado en el estado del viaje
              ],
            ),
            const SizedBox(height: 5),
            Text("📅 Agendado para: $formattedDate"),
            Text("🕒 Creado en: $createdDate"),
            Text("👥 Pasajeros: ${trip["passengers"] ?? 1}"),
            if ((trip["luggage"] ?? 0) > 0) Text("👜 Equipaje: ${trip["luggage"]}"),
            if ((trip["pets"] ?? 0) > 0) Text("🐶 Mascotas: ${trip["pets"]}"),
            if ((trip["babySeats"] ?? 0) > 0)
              Text("👶 Sillas para bebé: ${trip["babySeats"]}"),
            if (trip["need_second_driver"] == true)
              const Text("🧍‍♂️ Se requiere conductor adicional"),
            if (trip["notes"] != null && trip["notes"].toString().trim().isNotEmpty)
              Text("📝 Notas: ${trip["notes"]}"),
            if (hasPre1) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preasignación',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person, color: Colors.orange),
                      title: Text(trip['preassigned_driver_name'] ?? '(sin nombre)'),
                      subtitle: Text(
                        [
                          if ((trip['preassigned_driver_phone'] ?? '').toString().isNotEmpty)
                            'Tel: ${trip['preassigned_driver_phone']}',
                          if ((trip['preassigned_vehicle_info'] ?? '').toString().isNotEmpty)
                            'Veh: ${trip['preassigned_vehicle_info']}',
                          if ((trip['preassigned_vehicle_plates'] ?? '').toString().isNotEmpty)
                            'Placas: ${trip['preassigned_vehicle_plates']}',
                        ].join(' · '),
                      ),
                    ),
                    if (hasPre2) ...[
                      const Divider(height: 10),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person, color: Colors.green),
                        title: Text(trip['preassigned_driver2_name'] ?? '(sin nombre)'),
                        subtitle: Text(
                          [
                            if ((trip['preassigned_driver2_phone'] ?? '').toString().isNotEmpty)
                              'Tel: ${trip['preassigned_driver2_phone']}',
                            if ((trip['preassigned_vehicle2_info'] ?? '').toString().isNotEmpty)
                              'Veh: ${trip['preassigned_vehicle2_info']}',
                            if ((trip['preassigned_vehicle2_plates'] ?? '').toString().isNotEmpty)
                              'Placas: ${trip['preassigned_vehicle2_plates']}',
                          ].join(' · '),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔴 Botón Cancelar Viaje
                ElevatedButton(
                  onPressed: () => _showConfirmationDialog(
                    context,
                    "Cancelar viaje",
                    "¿Estás seguro de que deseas cancelar este viaje? Esta acción no se puede deshacer.",
                    "scheduled canceled",
                    trip["tripId"],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Cancelar viaje",
                      style: TextStyle(color: Colors.white)),
                ),

                // 🟡 REVISAR & PREASIGNAR (antes: "Marcar como Revisado")
                if (trip["status"] == "scheduled" || trip["status"] == "scheduled approved")
                  ElevatedButton(
                    onPressed: () async {
                      final tripId = trip["tripId"];

                      // Si aún está en "scheduled", primero márcalo como revisado
                      if (trip["status"] == "scheduled") {
                        await FirebaseDatabase.instance
                            .ref("trip_requests/$tripId")
                            .update({"status": "scheduled approved"});
                      }

                      // Navega a SelectDriverScreen en modo preasignación
                      final tripForSelect = {...trip, 'id': tripId};
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SelectDriverScreen(
                            tripRequest: tripForSelect,
                            isSupervisor: true, // ajusta si aplica
                            region: region,
                            preassignMode: true, // clave
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      // Texto dinámico según exista preasignación
                      ((trip['preassigned_driver'] ?? '').toString().isNotEmpty)
                          ? 'Editar preasignación'
                          : 'Preasignar conductor',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                // 🟢 Iniciar Viaje
                ElevatedButton(
                  onPressed: () => _confirmStartTrip(context, trip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Iniciar viaje", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTrip(BuildContext context, String tripId) async {
    final tripRef = FirebaseDatabase.instance.ref("trip_requests/$tripId");
    final snap    = await tripRef.get();

    if (!snap.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El viaje ya no existe.')),
      );
      return;
    }

    final m = Map<String, dynamic>.from(snap.value as Map);

    // Lee preasignación (si existe)
    final preD1  = (m['preassigned_driver'] ?? '').toString().trim();
    final preD1N = (m['preassigned_driver_name'] ?? '').toString().trim();
    final preD1P = (m['preassigned_driver_phone'] ?? '').toString().trim();
    final preV1P = (m['preassigned_vehicle_plates'] ?? '').toString();
    final preV1I = (m['preassigned_vehicle_info'] ?? '').toString();

    final preD2  = (m['preassigned_driver2'] ?? '').toString().trim();
    final preD2N = (m['preassigned_driver2_name'] ?? '').toString().trim();
    final preD2P = (m['preassigned_driver2_phone'] ?? '').toString().trim();
    final preV2P = (m['preassigned_vehicle2_plates'] ?? '').toString();
    final preV2I = (m['preassigned_vehicle2_info'] ?? '').toString();

    final hasPreassigned = preD1.isNotEmpty;

    try {
      if (hasPreassigned) {
        // Marcar conductores como ocupados en Firestore (solo al iniciar)
        try {
          await FirebaseFirestore.instance
              .collection('Conductores')
              .doc(preD1)
              .update({'Viaje': true});
        } catch (_) {}
        if (preD2.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('Conductores')
                .doc(preD2)
                .update({'Viaje': true});
          } catch (_) {}
        }

        // Promociona preassigned_* → canónicos y limpia preassigned_*
        final updates = <String, dynamic>{
          // canónicos
          'driver': preD1,
          'driverName': preD1N,
          'TelefonoConductor': preD1P,
          'vehiclePlates': preV1P,
          'vehicleInfo':   preV1I,

          // segundo conductor si aplica
          if (preD2.isNotEmpty) ...{
            'driver2': preD2,
            'driver2Name': preD2N,
            'TelefonoConductor2': preD2P,
            'vehicle2Plates': preV2P,
            'vehicle2Info':   preV2I,
          } else ...{
            'driver2': null,
            'driver2Name': null,
            'TelefonoConductor2': null,
            'vehicle2Plates': null,
            'vehicle2Info': null,
          },

          // estado de inicio
          'status': 'in progress',
          'started_at': DateTime.now().toIso8601String(),

          // limpia preassigned_*
          'preassigned_driver': null,
          'preassigned_driver_name': null,
          'preassigned_driver_phone': null,
          'preassigned_vehicle_plates': null,
          'preassigned_vehicle_info': null,
          'preassigned_driver2': null,
          'preassigned_driver2_name': null,
          'preassigned_driver2_phone': null,
          'preassigned_vehicle2_plates': null,
          'preassigned_vehicle2_info': null,
        };

        await tripRef.update(updates);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje iniciado con conductor preasignado.')),
        );
      } else {
        // Sin preasignación → va a verificación
        await tripRef.update({'status': 'pending'});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje enviado a verificación (pending).')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar el viaje: $e')),
      );
    }
  }

  void _confirmStartTrip(BuildContext context, Map<String, dynamic> trip) {
    final hasPre =
        ((trip['preassigned_driver'] ?? '').toString().isNotEmpty);

    final title = 'Confirmar inicio de viaje';
    final body = hasPre
        ? 'Se iniciará el viaje y se asignará(n) el/los conductor(es) preseleccionado(s). '
          'Se marcarán como ocupados y el estado pasará a "En espera de conductor". ¿Deseas continuar?'
        : 'No hay conductor preasignado. El viaje pasará a "pending" para verificación y asignación. '
          '¿Deseas continuar?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // cierra el diálogo
              await _startTrip(context, trip['tripId'] as String);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

}