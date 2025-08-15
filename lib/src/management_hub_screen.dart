import 'package:flutter/material.dart';
import 'driver_management_screen.dart';
import 'supervisor_management_screen.dart';
// import 'vehicle_management_screen.dart'; // pendiente (botón desactivado)

/// Hub de gestión con navegación a Conductores, Supervisores y Vehículos.
/// Se recibe `usuario` y `region` para propagarlos a las pantallas hijas.
/// Por ahora, el botón de Vehículos está desactivado (onPressed: null).
class ManagementHubScreen extends StatelessWidget {
  final String usuario;
  final String region;

  const ManagementHubScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  static const Color _brand = Color.fromRGBO(149, 189, 64, 1);

  // Botón grande reutilizable; altura generosa para buena tocabilidad.
  Widget _bigActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed, // null = desactivado (vehículos por ahora)
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          disabledBackgroundColor: Colors.grey.shade500, // para el botón desactivado
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
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
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _bigActionButton(
              context: context,
              icon: Icons.local_shipping, // Conductores
              title: 'Gestión de Conductores',
              subtitle: 'Altas, edición, eliminación',
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
              icon: Icons.supervisor_account, // Supervisores
              title: 'Gestión de Supervisores',
              subtitle: 'Altas, edición, eliminación',
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
              icon: Icons.directions_car, // Vehículos (desactivado)
              title: 'Gestión de Vehículos',
              subtitle: 'Próximamente',
              onPressed: null, // deshabilitado por ahora
            ),
          ],
        ),
      ),
    );
  }
}