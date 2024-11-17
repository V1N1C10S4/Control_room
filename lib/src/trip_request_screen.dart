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
          return request;
        }).where((request) => request['status'] == 'pending' || request['status'] == 'authorized').toList();

        setState(() {
          _tripRequests = tripRequests.reversed.toList(); // Invertir el orden para mostrar primero las solicitudes más antiguas
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
                                  'Pickup: ${tripRequest['pickup']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Destination: ${tripRequest['destination']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Status: ${tripRequest['status']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'User: ${tripRequest['userId']}',
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