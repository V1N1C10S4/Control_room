import 'package:flutter/material.dart';

class UserCreationScreen extends StatelessWidget {
  final String usuario;
  final bool isSupervisor;
  final String region;

  const UserCreationScreen({
    Key? key,
    required this.usuario,
    required this.isSupervisor,
    required this.region,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crear Usuario',
          style: TextStyle(color: Colors.white), // Texto blanco en el AppBar
        ),
        backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white), // Iconos blancos en el AppBar
      ),
      body: const Center(
        child: Text(
          'Pantalla en desarrollo',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}