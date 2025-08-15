import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

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

  // Controladores existentes
  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _nombreConductorController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _numeroTelefonoController = TextEditingController();
  final TextEditingController _infoVehiculoController = TextEditingController();
  final TextEditingController _placasController = TextEditingController();

  // Mantendremos estos dos, pero los volveremos read-only y los llenaremos desde el selector
  final TextEditingController _nombreSupervisorController = TextEditingController();
  final TextEditingController _numeroSupervisorController = TextEditingController();

  bool _isSaving = false;
  bool _isPasswordVisible = false;
  String? _fotoPerfilURL;

  // Estado de selección de supervisor
  String? _selectedSupervisorId; // doc.id del supervisor seleccionado
  String? _selectedVehicleId;

  @override
  void dispose() {
    _driverIdController.dispose();
    _nombreConductorController.dispose();
    _contrasenaController.dispose();
    _numeroTelefonoController.dispose();
    _infoVehiculoController.dispose();
    _placasController.dispose();
    _nombreSupervisorController.dispose();
    _numeroSupervisorController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirFoto(String driverId) async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      final reader = html.FileReader();

      if (file != null) {
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        // Nota: en web, reader.result suele ser ByteBuffer; tus pantallas actuales lo tratan igual
        final data = Uint8List.fromList(reader.result as List<int>);
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$driverId.jpg');

        try {
          final snapshot = await storageRef.putData(data);
          final downloadUrl = await snapshot.ref.getDownloadURL();

          setState(() {
            _fotoPerfilURL = downloadUrl;
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil subida correctamente.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir la foto: $e')),
          );
        }
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveDriver() async {
    if (_formKey.currentState!.validate() != true) return;

    if (_selectedVehicleId == null) {
      _showSnack('Selecciona un vehículo');
      return;
    }
    if (_selectedSupervisorId == null) {
      _showSnack('Selecciona un supervisor');
      return;
    }

    final driverId = _driverIdController.text.trim();
    final driverData = {
      'Ciudad': widget.region,
      'NombreConductor': _nombreConductorController.text.trim(),
      'Contraseña': _contrasenaController.text.trim(),
      'FotoPerfil': _fotoPerfilURL ?? '',
      'NumeroTelefono': _numeroTelefonoController.text.trim(),
      // Denormalizados llenados por los selectores
      'InfoVehiculo': _infoVehiculoController.text.trim(),
      'Placas': _placasController.text.trim(),
      'NombreSupervisor': _nombreSupervisorController.text.trim(),
      'NumeroSupervisor': _numeroSupervisorController.text.trim(),
      // Punteros
      'vehicleId': _selectedVehicleId,
      'supervisorId': _selectedSupervisorId,
      'Estatus': 'disponible',
      'Viaje': false,
    };

    try {
      setState(() => _isSaving = true);

      await FirebaseFirestore.instance
          .collection('Conductores')
          .doc(driverId)
          .set(driverData);

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showConfirmationDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el conductor: $e')),
      );
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Conductor Creado'),
          content: const Text('El conductor ha sido creado exitosamente.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(149, 189, 64, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  /// Selector de supervisores por región.
  /// Llena automáticamente NombreSupervisor/NumeroSupervisor (read-only).
  Widget _supervisorSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Supervisores')
          .where('Ciudad', isEqualTo: widget.region)
          .snapshots(),
      builder: (context, snapshot) {
        // Estados de carga/errores
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DropdownButtonFormField<String>(
            items: [],
            onChanged: null,
            decoration: InputDecoration(labelText: 'Supervisor'),
            hint: Text('Cargando supervisores...'),
          );
        }
        if (snapshot.hasError) {
          return DropdownButtonFormField<String>(
            items: const [],
            onChanged: null,
            decoration: const InputDecoration(labelText: 'Supervisor'),
            hint: const Text('Error al cargar'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        // Construir ítems
        final items = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final tel = (data['Número de teléfono'] ?? '').toString();
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text('${doc.id}${tel.isNotEmpty ? ' · $tel' : ''}'),
          );
        }).toList();

        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Supervisor'),
          value: (docs.any((d) => d.id == _selectedSupervisorId)) ? _selectedSupervisorId : null,
          items: items,
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedSupervisorId = val;
              // Buscar doc para rellenar denormalizados
              final selectedDoc = docs.firstWhere((d) => d.id == val);
              final data = selectedDoc.data() as Map<String, dynamic>;
              final tel = (data['Número de teléfono'] ?? '').toString();

              // Llenamos los controladores (read-only en UI) para guardar denormalizados
              _nombreSupervisorController.text = selectedDoc.id;
              _numeroSupervisorController.text = tel;
            });
          },
          validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un supervisor' : null,
          hint: const Text('Selecciona un supervisor'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color.fromRGBO(149, 189, 64, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Conductor', style: TextStyle(color: Colors.white)),
        backgroundColor: brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                controller: _driverIdController,
                decoration: const InputDecoration(labelText: 'Driver ID'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Por favor, ingrese un Driver ID' : null,
              ),
              const SizedBox(height: 16),

              // Ciudad fija por navegación
              TextFormField(
                initialValue: widget.region,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                readOnly: true,
                enableInteractiveSelection: true,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nombreConductorController,
                decoration: const InputDecoration(labelText: 'Nombre del Conductor'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Por favor, ingrese el Nombre del Conductor' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _contrasenaController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
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

              // Foto (opcional)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Foto de Perfil", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final driverId = _driverIdController.text.trim();
                      if (driverId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor ingresa el Driver ID antes de subir la imagen.')),
                        );
                        return;
                      }
                      _seleccionarYSubirFoto(driverId);
                    },
                    label: const Text("Seleccionar imagen", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: brand),
                  ),
                  if (_fotoPerfilURL != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text("Imagen subida ✅", style: TextStyle(color: Colors.green)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _numeroTelefonoController,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Por favor, ingrese el Número de Teléfono';
                  if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'El número debe tener 10 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('UnidadesVehiculares')
                    .where('Ciudad', isEqualTo: widget.region)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return DropdownButtonFormField<String>(
                      items: [], onChanged: null,
                      decoration: InputDecoration(labelText: 'Vehículo'),
                      hint: Text('Cargando vehículos...'),
                    );
                  }
                  if (snap.hasError) {
                    return DropdownButtonFormField<String>(
                      items: [], onChanged: null,
                      decoration: InputDecoration(labelText: 'Vehículo'),
                      hint: Text('Error al cargar'),
                    );
                  }

                  final docs = snap.data?.docs ?? [];
                  final items = docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final placas = (data['Placas'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: d.id,
                      child: Text('${d.id}${placas.isNotEmpty ? " · $placas" : ""}'),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Vehículo'),
                    value: _selectedVehicleId,
                    items: items,
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selectedVehicleId = val;
                        final sel = docs.firstWhere((d) => d.id == val);
                        final data = sel.data() as Map<String, dynamic>;
                        _infoVehiculoController.text = (data['InfoVehiculo'] ?? '').toString();
                        _placasController.text = (data['Placas'] ?? '').toString();
                      });
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Selecciona un vehículo' : null,
                    hint: const Text('Selecciona un vehículo'),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _infoVehiculoController,
                decoration: const InputDecoration(labelText: 'Info del Vehículo (auto)'),
                readOnly: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecciona un vehículo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(labelText: 'Placas (auto)'),
                readOnly: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecciona un vehículo' : null,
              ),
              const SizedBox(height: 16),

              // === NUEVO: Selector de Supervisor por región ===
              _supervisorSelector(),
              const SizedBox(height: 12),

              // Campos informativos rellenos por el selector (no editables)
              TextFormField(
                controller: _nombreSupervisorController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Nombre del Supervisor (auto)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numeroSupervisorController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Número del Supervisor (auto)'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveDriver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Conductor', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}