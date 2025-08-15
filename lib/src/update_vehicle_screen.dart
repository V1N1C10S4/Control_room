import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class UpdateVehicleScreen extends StatefulWidget {
  final String usuario;
  final String vehicleId;
  final Map<String, dynamic> vehicleData;

  const UpdateVehicleScreen({
    super.key,
    required this.usuario,
    required this.vehicleId,
    required this.vehicleData,
  });

  @override
  State<UpdateVehicleScreen> createState() => _UpdateVehicleScreenState();
}

class _UpdateVehicleScreenState extends State<UpdateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciudadController = TextEditingController();
  final _infoController = TextEditingController();
  final _placasController = TextEditingController();
  final _fotoController = TextEditingController();

  static const _brand = Color.fromRGBO(90, 150, 200, 1);

  @override
  void initState() {
    super.initState();
    _ciudadController.text = widget.vehicleData['Ciudad'] ?? '';
    _infoController.text = widget.vehicleData['InfoVehiculo'] ?? '';
    _placasController.text = widget.vehicleData['Placas'] ?? '';
    _fotoController.text = widget.vehicleData['Foto'] ?? '';
  }

  @override
  void dispose() {
    _ciudadController.dispose();
    _infoController.dispose();
    _placasController.dispose();
    _fotoController.dispose();
    super.dispose();
  }

  Future<void> _subirNuevaFoto(String id) async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      final reader = html.FileReader();
      if (file != null) {
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final data = Uint8List.fromList(reader.result as List<int>);
        final ref = FirebaseStorage.instance.ref().child('vehicle_pictures/$id.jpg');

        try {
          final snap = await ref.putData(data);
          final url = await snap.ref.getDownloadURL();
          if (!mounted) return;
          setState(() => _fotoController.text = url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto actualizada correctamente.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar la foto: $e')),
          );
        }
      }
    });
  }

  void _confirmAndUpdate() {
    if (_formKey.currentState?.validate() != true) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // evita tinte M3
        title: const Text('Confirmar Cambios'),
        content: const Text('¿Estás seguro de que deseas guardar estos cambios?'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _update();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _update() async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('UnidadesVehiculares').doc(widget.vehicleId);

    final newCity   = _ciudadController.text.trim();
    final newInfo   = _infoController.text.trim();
    final newPlacas = _placasController.text.trim();
    final newFoto   = _fotoController.text.trim();
    final oldPlacas = (widget.vehicleData['Placas'] ?? '').toString();

    final data = {
      'Ciudad': newCity,
      'InfoVehiculo': newInfo,
      'Placas': newPlacas,
      'Foto': newFoto,
    };

    try {
      await ref.update(data);

      // Propaga y desvincula según ciudad
      final result = await _propagateVehicleChangesAndUnlinkByCity(
        vehicleId: widget.vehicleId,
        newInfo: newInfo,
        newPlacas: newPlacas,
        newCity: newCity,
        oldPlacasForCompat: oldPlacas,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vehículo actualizado. Sincronizados ${result['updated']} conductores, desvinculados ${result['unlinked']}.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar los datos: $e')),
      );
    }
  }

  // Sincroniza a conductores con misma ciudad, desvincula a los de otra ciudad, y migra legacy por placas.
  Future<Map<String, int>> _propagateVehicleChangesAndUnlinkByCity({
    required String vehicleId,
    required String newInfo,
    required String newPlacas,
    required String newCity,
    required String oldPlacasForCompat,
  }) async {
    final db = FirebaseFirestore.instance;

    // Conductores con puntero actual
    final qLinked = await db
        .collection('Conductores')
        .where('vehicleId', isEqualTo: vehicleId)
        .get();

    int updated = 0;
    int unlinked = 0;

    const maxOps = 500;
    final linked = qLinked.docs;

    for (int i = 0; i < linked.length; i += maxOps) {
      final end = (i + maxOps < linked.length) ? i + maxOps : linked.length;
      final batch = db.batch();
      for (final doc in linked.sublist(i, end)) {
        final data = doc.data();
        final driverCity = (data['Ciudad'] ?? '').toString();

        if (driverCity == newCity) {
          // Misma ciudad → sincroniza
          batch.update(doc.reference, {
            'InfoVehiculo': newInfo,
            'Placas': newPlacas,
            'vehicleId': vehicleId,
          });
          updated++;
        } else {
          // Otra ciudad → desvincula
          batch.update(doc.reference, {
            'vehicleId': null,
            'InfoVehiculo': '',
            'Placas': '',
          });
          unlinked++;
        }
      }
      await batch.commit();
    }

    // Compatibilidad: sin vehicleId, con placas anteriores, y en la NUEVA ciudad → vincular y sincronizar
    if (oldPlacasForCompat.isNotEmpty) {
      final qLegacy = await db
          .collection('Conductores')
          .where('Placas', isEqualTo: oldPlacasForCompat)
          .where('Ciudad', isEqualTo: newCity)
          .get();

      final existing = Set<String>.from(linked.map((d) => d.id));
      final toAssign = qLegacy.docs.where((d) => !existing.contains(d.id)).toList();

      for (int i = 0; i < toAssign.length; i += maxOps) {
        final end = (i + maxOps < toAssign.length) ? i + maxOps : toAssign.length;
        final batch = db.batch();
        for (final doc in toAssign.sublist(i, end)) {
          batch.update(doc.reference, {
            'InfoVehiculo': newInfo,
            'Placas': newPlacas,
            'vehicleId': vehicleId,
          });
        }
        await batch.commit();
        updated += (end - i);
      }
    }

    return {'updated': updated, 'unlinked': unlinked};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Actualizar Vehículo - ${widget.vehicleId}', style: const TextStyle(color: Colors.white)),
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
                initialValue: widget.vehicleId,
                decoration: const InputDecoration(labelText: 'Vehículo'),
                readOnly: true,
              ),
              const SizedBox(height: 10),
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
                  setState(() => _ciudadController.text = val);
                },
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Selecciona una ciudad' : null,
                hint: const Text('Selecciona una ciudad'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _infoController,
                decoration: const InputDecoration(labelText: 'InfoVehiculo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _placasController,
                decoration: const InputDecoration(labelText: 'Placas'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _subirNuevaFoto(widget.vehicleId),
                icon: const Icon(Icons.image),
                label: const Text('Cambiar Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                ),
              ),
              if (_fotoController.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Imagen actualizada ✅', style: TextStyle(color: Colors.green)),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _confirmAndUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}