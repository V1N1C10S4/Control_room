import 'package:flutter/material.dart';

class GenerateTripScreen extends StatelessWidget {
  const GenerateTripScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Generar Viaje',
          style: TextStyle(color: Colors.white), // Título blanco
        ),
        backgroundColor: Colors.blue, // Color del AppBar
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: const Center(
        child: Text(
          'Pantalla vacía para generar viajes',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}