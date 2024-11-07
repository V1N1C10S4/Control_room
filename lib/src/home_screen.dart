import 'package:flutter/material.dart';
import 'trip_request_screen.dart';
import 'ongoing_trip_screen.dart';
import 'finished_trip_screen.dart';
import 'driver_availability.dart';
import 'driver_management_screen.dart';
import 'login_screen.dart'; // Asegúrate de tener la pantalla de login

class HomeScreen extends StatelessWidget {
  final String usuario;
  final bool isSupervisor; // Añadido el parámetro isSupervisor

  const HomeScreen({super.key, required this.usuario, required this.isSupervisor}); // Añadido como requerido

  // Función para cerrar sesión
  void _cerrarSesion(BuildContext context) {
    // Navega de vuelta a la pantalla de inicio de sesión
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MyAppForm()), // Cambia esto si tu pantalla de inicio de sesión tiene otro nombre
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Control Room',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              _cerrarSesion(context); // Llama a la función para cerrar sesión
            },
          ),
        ],
      ),
      body: Container(
        color: const Color.fromARGB(255, 27, 25, 31),  // Cambiado a negro
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TripRequestScreen(usuario: usuario, isSupervisor: isSupervisor)), // Pasar isSupervisor
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Solicitudes de Viajes',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(207, 215, 107, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OngoingTripScreen(usuario: usuario)),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Viajes en Progreso',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(158, 212, 176, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FinishedTripScreen(usuario: usuario)),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Viajes Terminados',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(110, 191, 137, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DriverAvailability(usuario: usuario)),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon((Icons.local_taxi), size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Conductores Disponibles',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isSupervisor)  // Mostrar solo si es supervisor
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(150, 190, 65, 1),  // Verde Lima
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DriverManagementScreen(usuario: usuario)),
                          );
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.settings, size: 50, color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              'Gestión de Conductores y Vehículos',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}