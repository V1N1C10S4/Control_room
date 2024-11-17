import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'select_driver_screen.dart';

class DetailRequestScreen extends StatelessWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor;
  final String region;

  DetailRequestScreen({
    super.key,
    required this.tripRequest,
    required this.isSupervisor,
    required this.region,
  });

  final Logger _logger = Logger();

  void _updateTripStatus(BuildContext context, String newStatus) {
    final DatabaseReference tripRequestRef = FirebaseDatabase.instance.ref().child('trip_requests').child(tripRequest['id']);

    tripRequestRef.update({
      'status': newStatus,
    }).then((_) {
      if (newStatus == 'authorized') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectDriverScreen(
              tripRequest: tripRequest,
              isSupervisor: isSupervisor,
              region: region,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }).catchError((error) {
      _logger.e('Error updating trip status: $error');
    });
  }

  void _showConfirmationDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('¿Seguro que quieres $action este viaje?'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('No', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateTripStatus(context, action == 'autorizar' ? 'authorized' : 'denied');
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Sí', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Solicitud #${tripRequest['id']}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuario: ${tripRequest['userId']}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nombre del usuario: ${tripRequest['userName']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Pickup: ${tripRequest['pickup']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Destination: ${tripRequest['destination']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${tripRequest['status']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            // Mostrar el número de pasajeros, equipaje y mascotas
            Text(
              'Número de pasajeros: ${tripRequest['passengers'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Cantidad de equipaje: ${tripRequest['luggage'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Número de mascotas: ${tripRequest['pets'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(context, 'autorizar');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text(
                    'Autorizar viaje',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(context, 'denegar');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text(
                    'Denegar viaje',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}