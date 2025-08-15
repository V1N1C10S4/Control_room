import 'package:flutter/material.dart';
import 'driver_management_screen.dart';
import 'supervisor_management_screen.dart';
import 'vehicle_management_screen.dart';

class ManagementHubScreen extends StatelessWidget {
  final String usuario;
  final String region;

  const ManagementHubScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  // Paleta por sección (texto en blanco para buen contraste)
  static const Color _driversColor     = Color.fromRGBO(149, 189, 64, 1); // Conductores
  static const Color _supervisorsColor = Color.fromRGBO(120, 170, 90, 1); // Supervisores
  static const Color _vehiclesColor    = Color.fromRGBO(90, 150, 200, 1);  // Vehículos (azulado)
  static const Color _appBarColor      = _driversColor;

  // Botón grande reutilizable con color parametrizable
  Widget _bigActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onPressed,
    required Color color,                  // <- nuevo parámetro
    Color foreground = Colors.white,       // opcional, por si algún color necesita texto negro
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,  // mantiene identidad aun deshabilitado
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
        title: const Text('Panel de Gestión', style: TextStyle(color: Colors.white)),
        backgroundColor: _appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bigActionButton(
              context: context,
              icon: Icons.local_shipping,
              title: 'Gestión de Conductores',
              subtitle: 'Altas, edición, eliminación',
              color: _driversColor, // <- color único
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverManagementScreen(
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
              icon: Icons.supervisor_account,
              title: 'Gestión de Supervisores',
              subtitle: 'Altas, edición, eliminación',
              color: _supervisorsColor, // <- color único
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupervisorManagementScreen(
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
              icon: Icons.directions_car,
              title: 'Gestión de Vehículos',
              subtitle: 'Altas, edición, eliminación',
              color: _vehiclesColor, // <- color único
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VehicleManagementScreen(
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