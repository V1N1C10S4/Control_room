import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
            .onValue, // 🔥 Eliminamos equalTo para filtrar múltiples estados
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          Map<dynamic, dynamic> tripMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> scheduledTrips = tripMap.entries
              .map((entry) {
                var trip = Map<String, dynamic>.from(entry.value);
                trip["tripId"] = entry.key; // Guardamos el ID del viaje
                return trip;
              })
              .where((trip) => trip.containsKey("city") &&
                              trip["city"].toString().toLowerCase() == region.toLowerCase() &&
                              (trip["status"] == "scheduled" || trip["status"] == "scheduled approved"))
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
      print("Estado actualizado a: $newStatus");
    }).catchError((error) {
      print("Error al actualizar estado: $error");
    });
  }

  void _showConfirmationDialog(BuildContext context, String title, String message, String newStatus, String tripId) {
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
              child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateTripStatus(tripId, newStatus);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
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
          Text("No hay viajes programados!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          SizedBox(height: 10),
          Text("Los viajes programados aparecerán en esta pantalla.", style: TextStyle(fontSize: 14, color: Colors.black45)),
        ],
      ),
    );
  }

  /// 🟢 Construye la tarjeta de cada viaje programado
  Widget _buildTripCard(Map<String, dynamic> trip, BuildContext context) {
    String formattedDate = trip["scheduled_at"] != null
        ? DateFormat("yyyy-MM-dd HH:mm").format(DateTime.parse(trip["scheduled_at"]))
        : "Unknown";

    String createdDate = trip["created_at"] != null
        ? DateFormat("yyyy-MM-dd HH:mm").format(DateTime.parse(trip["created_at"]))
        : "Unknown";
    
    String userName = trip["userName"] ?? "Usuario desconocido";
    String telefono = trip["telefonoPasajero"] ?? "Sin número";

    // 🔥 Determinar el ícono de estado basado en el status
    Icon statusIcon;
    if (trip["status"] == "scheduled") {
      statusIcon = const Icon(Icons.schedule, color: Colors.blue, size: 30); // ⏳ Azul
    } else if (trip["status"] == "scheduled approved") {
      statusIcon = const Icon(Icons.check_circle, color: Colors.green, size: 30); // ✅ Verde
    } else {
      statusIcon = const Icon(Icons.help_outline, color: Colors.grey, size: 30); // Por si hay un estado inesperado
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
                      Text("👤 Usuario: $userName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("📞 Teléfono: $telefono", style: const TextStyle(fontSize: 16)),
                      Text(
                        "📍 Punto de partida: ${trip["pickup"]["placeName"] ?? "Unknown"}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (stops.isNotEmpty) ...[
                        for (var stop in stops)
                          Text(
                            "🛑 Parada: $stop",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                      ],
                      Text(
                        "📍 Destino: ${trip["destination"]["placeName"] ?? "Unknown"}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            Text("👜 Equipaje: ${trip["luggage"] ?? 0}"),
            Text("🐶 Mascotas: ${trip["pets"] ?? 0}"),
            Text("👶 Sillas para bebé: ${trip["babySeats"] ?? 0}"),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Cancelar viaje", style: TextStyle(color: Colors.white)),
                ),

                // 🟡 Botón Marcar como Revisado (se oculta si el estado es "scheduled approved")
                if (trip["status"] == "scheduled")
                  ElevatedButton(
                    onPressed: () => _showConfirmationDialog(
                      context,
                      "Marcar como Revisado",
                      "¿Quieres aprobar esta solicitud de viaje programado?",
                      "scheduled approved",
                      trip["tripId"],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Marcar como Revisado", style: TextStyle(color: Colors.white)),
                  ),

                // 🟢 Botón Iniciar Viaje
                ElevatedButton(
                  onPressed: () => _showConfirmationDialog(
                    context,
                    "Iniciar Viaje",
                    "¿Confirmas que deseas iniciar este viaje? Pasará al estado de pendiente.",
                    "pending",
                    trip["tripId"],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Iniciar Viaje", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}