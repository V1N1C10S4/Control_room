import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final DatabaseReference _messagesRef = FirebaseDatabase.instance.ref().child("messages");
  List<Map<String, dynamic>> _pendingMessages = [];
  List<Map<String, dynamic>> _attendedMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    _messagesRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        List<Map<String, dynamic>> pendingList = [];
        List<Map<String, dynamic>> attendedList = [];

        Map<dynamic, dynamic> messagesMap = event.snapshot.value as Map<dynamic, dynamic>;

        messagesMap.forEach((key, value) {
          Map<String, dynamic> message = {
            "id": key,
            "usuario": value["usuario"],
            "pickup_location": value["pickup_location"],
            "destination_location": value["destination_location"],
            "trip_date_time": value["trip_date_time"],
            "attended": value["attended"] ?? false,
            "has_stops": value["has_stops"] ?? false,
            "stops_count": value["stops_count"] ?? 0,
            "stops": value["stops"] ?? [],
            "needs_extra_vehicle": value["needs_extra_vehicle"] ?? false,
            "passengers": value["passengers"] ?? 1,
            "luggage": value["luggage"] ?? 0,
            "pets": value["pets"] ?? 0,
            "baby_seats": value["baby_seats"] ?? 0,
            "timestamp": value["timestamp"] ?? 0,
            "extra_details": value["extra_details"] ?? "",
            "response": value["response"] ?? "", 
          };

          if (message["attended"]) {
            attendedList.add(message);
          } else {
            pendingList.add(message);
          }
        });

        // Ordenar los mensajes
        pendingList.sort((a, b) => a["timestamp"].compareTo(b["timestamp"])); // Más antiguos primero
        attendedList.sort((a, b) => b["timestamp"].compareTo(a["timestamp"])); // Más recientes primero

        setState(() {
          _pendingMessages = pendingList;
          _attendedMessages = attendedList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendingMessages = [];
          _attendedMessages = [];
          _isLoading = false;
        });
      }
    });
  }

  String formatTimestamp(int timestamp) {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat("dd/MM/yyyy HH:mm").format(dateTime);
  }

  void _markAsAttended(String messageId, String response) async {
    try {
      await _messagesRef.child(messageId).update({
        "attended": true,
        "response": response,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message marked as attended')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating message: $e')),
      );
    }
  }

  Widget _buildMessageCard(Map<String, dynamic> message, {bool isPending = true}) {
    final TextEditingController _responseController =
        TextEditingController(text: message["response"]);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Usuario: ${message["usuario"]}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("De: ${message["pickup_location"]}\nHacia: ${message["destination_location"]}"),
            Text("Enviado el: ${message.containsKey('timestamp') ? formatTimestamp(message['timestamp']) : 'Desconocido'}"),
            Text("Viaje para la fecha: ${message["trip_date_time"]}"),
            const SizedBox(height: 5),

            if (message["has_stops"]) ...[
              Text("Paradas: ${message["stops_count"]}"),
              for (String stop in List<String>.from(message["stops"]))
                Text("• $stop", style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 5),
            ],

            if (message["needs_extra_vehicle"])
              const Text("🚖 Vehículo extra solicitado", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),

            Text("Pasajeros: ${message["passengers"]}"),
            Text("Equipaje: ${message["luggage"]}"),
            Text("Mascotas: ${message["pets"]}"),
            Text("Asientos de bebé: ${message["baby_seats"]}"),

            if (message["extra_details"].toString().isNotEmpty) ...[
              const Divider(),
              const Text("Detalles adicionales:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(message["extra_details"], style: const TextStyle(color: Colors.black87)),
            ],

            if (isPending) ...[
              const SizedBox(height: 10),
              const Text("Respuesta:", style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _responseController,
                maxLength: 200,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Escribe una respuesta corta (opcional)",
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _markAsAttended(message["id"], _responseController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  "Marcar como Atendido",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ] else ...[
              if (message["response"].toString().isNotEmpty) ...[
                const Divider(),
                const Text("Respuesta dada:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(message["response"], style: const TextStyle(color: Colors.black87)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mensajes',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'OpenSans',
            fontSize: 25.0,
          ),
        ),
        backgroundColor: Colors.lightBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingMessages.isEmpty && _attendedMessages.isEmpty
              ? const Center(child: Text("No hay mensajes disponibles."))
              : Column(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.orange,
                            padding: const EdgeInsets.all(10),
                            child: const Text(
                              "Pendientes",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _pendingMessages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageCard(_pendingMessages[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: Colors.green,
                            padding: const EdgeInsets.all(10),
                            child: const Text(
                              "Atendidos",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _attendedMessages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageCard(_attendedMessages[index], isPending: false);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}