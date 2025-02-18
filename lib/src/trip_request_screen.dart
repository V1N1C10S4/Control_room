import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'detail_request.dart'; // Importa la nueva pantalla
import 'package:intl/intl.dart';

class TripRequestScreen extends StatefulWidget {
  final String usuario;
  final bool isSupervisor; // Añadir el parámetro isSupervisor aquí
  final String region;
  const TripRequestScreen({super.key, required this.usuario, required this.isSupervisor, required this.region}); // Asegurar que sea requerido

  @override
  TripRequestScreenState createState() => TripRequestScreenState();
}

class TripRequestScreenState extends State<TripRequestScreen> {
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> _tripRequests = [];
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchTripRequests();
  }

  void _fetchTripRequests() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        final List<Map<dynamic, dynamic>> tripRequests = data.entries.map((entry) {
          final Map<dynamic, dynamic> request = Map<dynamic, dynamic>.from(entry.value as Map);
          request['id'] = entry.key;
          request['pickup'] = request['pickup']['placeName'] ?? 'NA';
          request['destination'] = request['destination']['placeName'] ?? 'NA';

          // 🔍 Extraer todas las paradas
          List<String> stopsList = [];

          // 🛑 Si hay una parada única en "stop"
          if (request.containsKey('stop') && request['stop'] != null) {
            stopsList.add("Parada: ${request['stop']['placeName']}");
          }

          // 🔄 Iterar sobre posibles paradas numeradas (stop1, stop2...)
          for (int i = 1; i <= 5; i++) {
            if (request.containsKey('stop$i') && request['stop$i'] != null) {
              stopsList.add("Parada $i: ${request['stop$i']['placeName']}");
            }
          }

          request['stopsList'] = stopsList; // Guardar la lista corregida

          return request;
        })
        .where((request) =>
            (request['status'] == 'pending' || request['status'] == 'authorized') &&
            request['city']?.toString().toLowerCase() == widget.region.toLowerCase()) // Filtrar por región
        .toList();

        setState(() {
          _tripRequests = tripRequests.reversed.toList(); // 🔄 Mostrar los más recientes primero
        });
      } else {
        setState(() {
          _tripRequests = [];
        });
      }
    }).onError((error) {
      _logger.e('Error fetching trip requests: $error');
      setState(() {
        _tripRequests = [];
      });
    });
  }

  // Formatear las fechas al formato deseado
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    DateTime dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Viajes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _tripRequests.isEmpty
          ? const Center(
              child: Text(
                'No hay solicitudes de viaje',
                style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _tripRequests.length,
              itemBuilder: (context, index) {
                final tripRequest = _tripRequests[index];

                // Obtener y formatear el campo de "created_at"
                final String createdAt = tripRequest['created_at'] != null ? _formatDateTime(tripRequest['created_at']) : 'N/A';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Solicitud #${_tripRequests.length - index}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Punto de partida: ${tripRequest['pickup']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                // 🔹 Mostrar dinámicamente las paradas intermedias
                                if (tripRequest['stopsList'] != null)
                                  for (var stop in tripRequest['stopsList'])
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Text(
                                        stop,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                const SizedBox(height: 8),
                                Text(
                                  'Destino: ${tripRequest['destination']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Estatus: ${tripRequest['status']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Pasajero solicitante: ${tripRequest['userId']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Solicitado: $createdAt',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailRequestScreen(
                                    tripRequest: tripRequest,
                                    isSupervisor: widget.isSupervisor,
                                    region: widget.region,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Detalles', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}