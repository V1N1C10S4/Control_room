import 'package:flutter/material.dart';

class TripDetailsScreen extends StatelessWidget {
  final Map<dynamic, dynamic> trip;
  final Color appBarColor;

  const TripDetailsScreen({super.key, required this.trip, this.appBarColor = const Color.fromRGBO(207, 215, 107, 1)});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Viaje', style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
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
              'Viaje ID: ${trip['id']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Usuario: ${trip['userId']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Conductor: ${trip['driver']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Recogida: ${trip['pickup']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Destino: ${trip['destination']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Estado: ${trip['status']}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}