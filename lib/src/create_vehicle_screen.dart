import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class CreateVehicleScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const CreateVehicleScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  State<CreateVehicleScreen> createState() => _CreateVehicleScreenState();
}

class _CreateVehicleScreenState extends State<CreateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();        // doc.id (#30, etc.)
  final _infoController = TextEditingController();      // InfoVehiculo
  final _placasController = TextEditingController();    // Placas

  bool _isSaving = false;
  String? _fotoURL;

  static const _brand = Color.fromRGBO(90, 150, 200, 1);

  @override
  void dispose() {
    _idController.dispose();
    _infoController.dispose();
    _placasController.dispose();
    super.dispose();
  }

  Future<void> _subirFoto(String vehicleId) async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      final reader = html.FileReader();
      if (file != null) {
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final data = Uint8List.fromList(reader.result as List<int>);
        final storageRef = FirebaseStorage.instance.ref().child('vehicle_pictures/$vehicleId.jpg');
        try {
          final snap = await storageRef.putData(data);
          final url = await snap.ref.getDownloadURL();
          setState(() => _fotoURL = url);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto subida correctamente.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
        }
      }
    });
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Vehículo Creado'),
        content: const Text('La unidad vehicular ha sido creada exitosamente.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    final id = _idController.text.trim();
    final data = {
      'Ciudad': widget.region,
      'InfoVehiculo': _infoController.text.trim(),
      'Placas': _placasController.text.trim(),
      'Foto': _fotoURL ?? '',
    };

    try {
      setState(() => _isSaving = true);
      await FirebaseFirestore.instance.collection('UnidadesVehiculares').doc(id).set(data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showConfirmation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el vehículo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Vehículo', style: TextStyle(color: Colors.white)),
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Vehículo ID'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el ID del vehículo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.region,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                readOnly: true,
                enableInteractiveSelection: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _infoController,
                decoration: const InputDecoration(labelText: 'InfoVehiculo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la información del vehículo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(labelText: 'Placas'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa las placas' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final id = _idController.text.trim();
                      if (id.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ingresa el ID del vehículo antes de subir la foto.')),
                        );
                        return;
                      }
                      _subirFoto(id);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Subir Foto'),
                    style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  if (_fotoURL != null) const Text('Imagen subida ✅', style: TextStyle(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Vehículo', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}