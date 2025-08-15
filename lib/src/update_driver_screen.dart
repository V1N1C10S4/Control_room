import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

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
  bool _estatusDisponible = false;
  final _placasController = TextEditingController();
  final _nombreSupervisorController = TextEditingController();
  final _fotoPerfilController = TextEditingController(); // Nuevo controlador para FotoPerfil
  final _formKey = GlobalKey<FormState>();
  String? _selectedSupervisorId;

  @override
  void initState() {
    super.initState();
    _ciudadController.text = widget.driverData['Ciudad'] ?? '';
    _infoVehiculoController.text = widget.driverData['InfoVehiculo'] ?? '';
    _numeroSupervisorController.text = widget.driverData['NumeroSupervisor'] ?? '';
    _numeroTelefonoController.text = widget.driverData['NumeroTelefono'] ?? '';
    final estatusRaw = (widget.driverData['Estatus'] ?? '').toString().toLowerCase().trim();
    _estatusDisponible = estatusRaw == 'disponible';
    _placasController.text = widget.driverData['Placas'] ?? '';
    _nombreSupervisorController.text = widget.driverData['NombreSupervisor'] ?? '';
    _fotoPerfilController.text = widget.driverData['FotoPerfil'] ?? ''; // Inicializar con el valor actual
    _selectedSupervisorId = widget.driverData['supervisorId'];
  }

  @override
  void dispose() {
    _ciudadController.dispose();
    _infoVehiculoController.dispose();
    _numeroSupervisorController.dispose();
    _numeroTelefonoController.dispose();
    _placasController.dispose();
    _nombreSupervisorController.dispose();
    _fotoPerfilController.dispose(); // Liberar el controlador
    super.dispose();
  }

  void _confirmAndUpdateDriverData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // M3: evita tinte sobre blanco
          title: const Text('Confirmar Cambios'),
          content: const Text('¿Estás seguro de que deseas guardar estos cambios?'),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateDriverData();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _seleccionarYSubirNuevaFoto(String driverId) async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      final reader = html.FileReader();

      if (file != null) {
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final data = Uint8List.fromList(reader.result as List<int>);
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$driverId.jpg');

        try {
          // Subir la nueva imagen
          final snapshot = await storageRef.putData(data);
          final downloadUrl = await snapshot.ref.getDownloadURL();

          setState(() {
            _fotoPerfilController.text = downloadUrl;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada correctamente.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar la foto: $e')),
          );
        }
      }
    });
  }

  void _updateDriverData() {
    // Referencia al documento del conductor en Firestore
    final driverRef = FirebaseFirestore.instance.collection('Conductores').doc(widget.driverKey);

    // Datos actualizados
    final updatedData = {
      'Ciudad': _ciudadController.text,
      'InfoVehiculo': _infoVehiculoController.text,
      'NumeroSupervisor': _numeroSupervisorController.text, // denormalizado
      'NumeroTelefono': _numeroTelefonoController.text,
      'Estatus': _estatusDisponible ? 'disponible' : 'no disponible',
      'Placas': _placasController.text,
      'NombreSupervisor': _nombreSupervisorController.text, // denormalizado
      'supervisorId': _selectedSupervisorId,                // referencia lógica
      'FotoPerfil': _fotoPerfilController.text,
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
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction, // por UX
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Ciudad'),
                value: const ['Tabasco', 'CDMX'].contains(_ciudadController.text)
                    ? _ciudadController.text
                    : null,
                items: const [
                  DropdownMenuItem(value: 'Tabasco', child: Text('Tabasco')),
                  DropdownMenuItem(value: 'CDMX', child: Text('CDMX')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _ciudadController.text = val;
                    _selectedSupervisorId = null;        // limpia selección previa
                    _nombreSupervisorController.clear(); // limpia denormalizados
                    _numeroSupervisorController.clear();
                  });
                },
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Selecciona una ciudad' : null,
                hint: const Text('Selecciona una ciudad'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _numeroTelefonoController,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _infoVehiculoController,
                decoration: const InputDecoration(labelText: 'Info. del Vehículo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(labelText: 'Placas'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: (_ciudadController.text.isEmpty)
                    ? const Stream<QuerySnapshot>.empty()
                    : FirebaseFirestore.instance
                        .collection('Supervisores')
                        .where('Ciudad', isEqualTo: _ciudadController.text)
                        .snapshots(),
                builder: (context, snap) {
                  if (_ciudadController.text.isEmpty) {
                    return DropdownButtonFormField<String>(
                      items: [],
                      onChanged: null,
                      decoration: InputDecoration(labelText: 'Supervisor'),
                      hint: Text('Selecciona primero una ciudad'),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      items: [],
                      onChanged: null,
                      decoration: InputDecoration(labelText: 'Supervisor'),
                      hint: Text('Cargando supervisores...'),
                    );
                  }
                  if (snap.hasError) {
                    return DropdownButtonFormField<String>(
                      items: [],
                      onChanged: null,
                      decoration: InputDecoration(labelText: 'Supervisor'),
                      hint: Text('Error al cargar'),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final items = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final tel = (data['Número de teléfono'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: d.id,
                      child: Text('${d.id}${tel.isNotEmpty ? " · $tel" : ""}'),
                    );
                  }).toList();

                  final isValidSelected =
                      docs.any((d) => d.id == _selectedSupervisorId);

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Supervisor'),
                    value: isValidSelected ? _selectedSupervisorId : null,
                    items: items,
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedSupervisorId = val;
                        final sel = docs.firstWhere((d) => d.id == val);
                        final data = sel.data() as Map<String, dynamic>;
                        _nombreSupervisorController.text = sel.id; // denormalizado
                        _numeroSupervisorController.text =
                            (data['Número de teléfono'] ?? '').toString();
                      });
                    },
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Selecciona un supervisor'
                        : null,
                    hint: const Text('Selecciona un supervisor'),
                  );
                },
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _nombreSupervisorController,
                decoration: const InputDecoration(labelText: 'Nombre del Supervisor (auto)'),
                readOnly: true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _numeroSupervisorController,
                decoration: const InputDecoration(labelText: 'Número del Supervisor (auto)'),
                readOnly: true,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),

              TextFormField(
                initialValue: widget.driverKey,
                decoration: const InputDecoration(labelText: 'Usuario'),
                readOnly: true,
              ),
              const SizedBox(height: 10),

              TextFormField(
                initialValue: widget.driverData['Contraseña'] ?? '',
                decoration: const InputDecoration(labelText: 'Contraseña'),
                readOnly: true,
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                title: const Text('Estatus'),
                subtitle: Text(_estatusDisponible ? 'Disponible' : 'No disponible'),
                value: _estatusDisponible,
                activeColor: const Color.fromRGBO(149, 189, 64, 1),
                onChanged: (val) => setState(() => _estatusDisponible = val),
              ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () => _seleccionarYSubirNuevaFoto(widget.driverKey),
                icon: const Icon(Icons.image),
                label: const Text('Cambiar Foto de Perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() != true) return; // evita guardar con vacíos
                  _confirmAndUpdateDriverData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Guardar Cambios',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}