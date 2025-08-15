import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateSupervisorScreen extends StatefulWidget {
  final String usuario;
  final String supervisorId;
  final Map<String, dynamic> supervisorData;

  const UpdateSupervisorScreen({
    super.key,
    required this.usuario,
    required this.supervisorId,
    required this.supervisorData,
  });

  @override
  State<UpdateSupervisorScreen> createState() => _UpdateSupervisorScreenState();
}

class _UpdateSupervisorScreenState extends State<UpdateSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciudadController = TextEditingController();
  final _telefonoController = TextEditingController();

  final Color _brand = const Color.fromRGBO(120, 170, 90, 1);

  @override
  void initState() {
    super.initState();
    _ciudadController.text = widget.supervisorData['Ciudad'] ?? '';
    _telefonoController.text = widget.supervisorData['Número de teléfono'] ?? '';
  }

  @override
  void dispose() {
    _ciudadController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _confirmAndUpdate() {
    if (_formKey.currentState?.validate() != true) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
    final supRef = db.collection('Supervisores').doc(widget.supervisorId);
    final data = {
      'Número de teléfono': _telefonoController.text.trim(),
    };

    try {
      // 1) Actualiza el supervisor
      await supRef.update(data);

      // 2) Propaga a conductores que lo tienen asignado
      final updatedPhone = _telefonoController.text.trim();
      final affected = await _propagateSupervisorChanges(
        supervisorId: widget.supervisorId,
        telefono: updatedPhone,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supervisor actualizado. Sincronizados $affected conductores.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  // Propaga cambios del supervisor a todos los conductores relacionados.
  Future<int> _propagateSupervisorChanges({
    required String supervisorId,
    required String telefono,
  }) async {
    final db = FirebaseFirestore.instance;

    // Query nueva (por referencia lógica)
    final q1 = await db
        .collection('Conductores')
        .where('supervisorId', isEqualTo: supervisorId)
        .get();

    // Query de compatibilidad (por nombre denormalizado)
    final q2 = await db
        .collection('Conductores')
        .where('NombreSupervisor', isEqualTo: supervisorId)
        .get();

    // Desduplicar por id
    final Map<String, QueryDocumentSnapshot> map = {};
    for (final d in q1.docs) map[d.id] = d;
    for (final d in q2.docs) map[d.id] = d;
    final docs = map.values.toList();

    if (docs.isEmpty) return 0;

    // Armamos la actualización denormalizada
    final updates = <String, dynamic>{
      'NombreSupervisor': supervisorId, // tu ID es el nombre visible
      'NumeroSupervisor': telefono,
    };

    // Commits por lotes de 500 (límite Firestore)
    const int maxOps = 500;
    int total = 0;
    for (int i = 0; i < docs.length; i += maxOps) {
      final end = (i + maxOps < docs.length) ? i + maxOps : docs.length;
      final batch = db.batch();
      for (final doc in docs.sublist(i, end)) {
        batch.update(doc.reference, updates);
      }
      await batch.commit();
      total += (end - i);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Actualizar Supervisor - ${widget.supervisorId}', style: const TextStyle(color: Colors.white)),
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
                initialValue: widget.supervisorId,
                decoration: const InputDecoration(labelText: 'Supervisor'),
                readOnly: true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ciudadController,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                readOnly: true,
                enableInteractiveSelection: true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Número de Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Ingresa el Número de Teléfono';
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'El número debe tener 10 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _confirmAndUpdate,
                style: ElevatedButton.styleFrom(backgroundColor: _brand, padding: const EdgeInsets.symmetric(vertical: 12)),
                child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}