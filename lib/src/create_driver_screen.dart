import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateDriverScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const CreateDriverScreen({
    Key? key,
    required this.usuario,
    required this.region,
  }) : super(key: key);

  @override
  _CreateDriverScreenState createState() => _CreateDriverScreenState();
}

class _CreateDriverScreenState extends State<CreateDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _nombreConductorController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _fotoPerfilController = TextEditingController();
  final TextEditingController _numeroTelefonoController = TextEditingController();
  final TextEditingController _infoVehiculoController = TextEditingController();
  final TextEditingController _placasController = TextEditingController();
  final TextEditingController _nombreSupervisorController = TextEditingController();
  final TextEditingController _numeroSupervisorController = TextEditingController();

  bool _isSaving = false;
  bool _isPasswordVisible = false;

  void _saveDriver() async {
    if (_formKey.currentState!.validate()) {
      final driverId = _driverIdController.text.trim();

      final driverData = {
        'Ciudad': _ciudadController.text.trim(),
        'NombreConductor': _nombreConductorController.text.trim(),
        'Contraseña': _contrasenaController.text.trim(),
        'FotoPerfil': _fotoPerfilController.text.trim(),
        'NumeroTelefono': _numeroTelefonoController.text.trim(),
        'InfoVehiculo': _infoVehiculoController.text.trim(),
        'Placas': _placasController.text.trim(),
        'NombreSupervisor': _nombreSupervisorController.text.trim(),
        'NumeroSupervisor': _numeroSupervisorController.text.trim(),
        'Estatus': 'disponible',
        'Viaje': false,
      };

      try {
        setState(() {
          _isSaving = true;
        });

        // Guardar documento en Firestore bajo "Conductores/{driverId}"
        await FirebaseFirestore.instance.collection('Conductores').doc(driverId).set(driverData);

        setState(() {
          _isSaving = false;
        });

        // Mostrar ventana de confirmación
        _showConfirmationDialog();
      } catch (e) {
        setState(() {
          _isSaving = false;
        });

        // Mostrar error en caso de fallo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear el conductor: $e')),
        );
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conductor Creado'),
          content: const Text('El conductor ha sido creado exitosamente.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Regresar a la pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
              ),
              child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crear Conductor',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _driverIdController,
                decoration: const InputDecoration(labelText: 'Driver ID'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese un Driver ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ciudadController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese la Ciudad';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreConductorController,
                decoration: const InputDecoration(labelText: 'Nombre del Conductor'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese el Nombre del Conductor';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contrasenaController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese una Contraseña';
                  }
                  if (value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fotoPerfilController,
                decoration: const InputDecoration(labelText: 'FotoPerfil (URL)'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese una URL de FotoPerfil';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroTelefonoController,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese el Número de Teléfono';
                  }
                  if (value.length != 10) {
                    return 'El número debe tener 10 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _infoVehiculoController,
                decoration: const InputDecoration(labelText: 'Info del Vehículo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(labelText: 'Placas'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreSupervisorController,
                decoration: const InputDecoration(labelText: 'Nombre del Supervisor'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroSupervisorController,
                decoration: const InputDecoration(labelText: 'Número del Supervisor'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveDriver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Conductor',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _driverIdController.dispose();
    _ciudadController.dispose();
    _nombreConductorController.dispose();
    _contrasenaController.dispose();
    _fotoPerfilController.dispose();
    _numeroTelefonoController.dispose();
    _infoVehiculoController.dispose();
    _placasController.dispose();
    _nombreSupervisorController.dispose();
    _numeroSupervisorController.dispose();
    super.dispose();
  }
}