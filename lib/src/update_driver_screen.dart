import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateDriverScreen extends StatefulWidget {
  final String usuario;
  final String driverKey;
  final Map<String, dynamic> driverData;

  const UpdateDriverScreen({
    super.key,
    required this.usuario,
    required this.driverKey,
    required this.driverData,
  });

  @override
  _UpdateDriverScreenState createState() => _UpdateDriverScreenState();
}

class _UpdateDriverScreenState extends State<UpdateDriverScreen> {
  final _ciudadController = TextEditingController();
  final _infoVehiculoController = TextEditingController();
  final _numeroSupervisorController = TextEditingController();
  final _numeroTelefonoController = TextEditingController();
  final _estatusController = TextEditingController();
  final _placasController = TextEditingController();
  final _nombreSupervisorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ciudadController.text = widget.driverData['Ciudad'] ?? '';
    _infoVehiculoController.text = widget.driverData['InfoVehiculo'] ?? '';
    _numeroSupervisorController.text = widget.driverData['NumeroSupervisor'] ?? '';
    _numeroTelefonoController.text = widget.driverData['NumeroTelefono'] ?? '';
    _estatusController.text = widget.driverData['Estatus'] ?? '';
    _placasController.text = widget.driverData['Placas'] ?? '';
    _nombreSupervisorController.text = widget.driverData['NombreSupervisor'] ?? '';
  }

  @override
  void dispose() {
    _ciudadController.dispose();
    _infoVehiculoController.dispose();
    _numeroSupervisorController.dispose();
    _numeroTelefonoController.dispose();
    _estatusController.dispose();
    _placasController.dispose();
    _nombreSupervisorController.dispose();
    super.dispose();
  }

  void _confirmAndUpdateDriverData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cambios'),
          content: const Text('¿Estás seguro de que deseas guardar estos cambios?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo sin guardar
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateDriverData();
                Navigator.of(context).pop(); // Cierra el diálogo y guarda
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateDriverData() {
    // Referencia al documento del conductor en Firestore
    final driverRef = FirebaseFirestore.instance.collection('Conductores').doc(widget.driverKey);

    // Datos actualizados
    final updatedData = {
      'Ciudad': _ciudadController.text,
      'InfoVehiculo': _infoVehiculoController.text,
      'NumeroSupervisor': _numeroSupervisorController.text,
      'NumeroTelefono': _numeroTelefonoController.text,
      'Estatus': _estatusController.text,
      'Placas': _placasController.text,
      'NombreSupervisor': _nombreSupervisorController.text,
    };

    // Actualizar documento en Firestore
    driverRef.update(updatedData).then((_) {
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos actualizados exitosamente')),
      );
      Navigator.pop(context); // Regresa a la pantalla anterior
    }).catchError((error) {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar los datos: $error')),
      );
      debugPrint('Error al actualizar los datos: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Actualizar Estado - ${widget.driverData['NombreConductor']}',
          style: const TextStyle(color: Colors.white), // Texto blanco en AppBar
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white), // Iconos blancos en AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _ciudadController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numeroTelefonoController,
              decoration: const InputDecoration(labelText: 'Número de Teléfono'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _infoVehiculoController,
              decoration: const InputDecoration(labelText: 'Info. del Vehículo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _placasController,
              decoration: const InputDecoration(labelText: 'Placas'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _estatusController,
              decoration: const InputDecoration(labelText: 'Estatus'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nombreSupervisorController,
              decoration: const InputDecoration(labelText: 'Nombre del Supervisor'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numeroSupervisorController,
              decoration: const InputDecoration(labelText: 'Número del Supervisor'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmAndUpdateDriverData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Guardar Cambios',
                style: TextStyle(fontSize: 16, color: Colors.white), // Texto blanco en el botón
              ),
            ),
          ],
        ),
      ),
    );
  }
}