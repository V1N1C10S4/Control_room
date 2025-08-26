import 'package:flutter/material.dart';

// Ajusta estas rutas a donde tengas las pantallas reales:
import 'driver_availability.dart';
import 'vehicles_availability.dart';

class AvailabilityHubScreen extends StatelessWidget {
  final String usuario;
  final String region;

  const AvailabilityHubScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  // Paleta (similar a ManagementHubScreen)
  static const Color _driversColor  = Color.fromRGBO(110, 191, 137, 1); // Conductores
  static const Color _vehiclesColor = Color.fromRGBO(90, 150, 200, 1);  // Vehículos (azulado)
  static const Color _appBarColor   = _driversColor;

  // Botón grande reutilizable
  Widget _bigActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onPressed,
    required Color color,
    Color foreground = Colors.white,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(110),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
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
        title: const Text('Panel de Disponibilidad', style: TextStyle(color: Colors.white)),
        backgroundColor: _appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bigActionButton(
              context: context,
              icon: Icons.person_pin_circle,
              title: 'Disponibilidad de Conductores',
              subtitle: 'Quién está disponible ahora',
              color: _driversColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverAvailability(
                      usuario: usuario,
                      region: region,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _bigActionButton(
              context: context,
              icon: Icons.directions_car_filled,
              title: 'Disponibilidad de Vehículos',
              subtitle: 'Unidades libres y ocupadas',
              color: _vehiclesColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VehiclesAvailability(
                      usuario: usuario,
                      region: region,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}