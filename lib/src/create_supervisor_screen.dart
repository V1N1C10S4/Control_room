import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pantalla para crear supervisores sin manejo de foto.
/// Mantiene el mismo estilo y validaciones (teléfono 10 dígitos).
class CreateSupervisorScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const CreateSupervisorScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  State<CreateSupervisorScreen> createState() => _CreateSupervisorScreenState();
}

class _CreateSupervisorScreenState extends State<CreateSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _isSaving = false;
  static const _brand = Color.fromRGBO(120, 170, 90, 1);

  @override
  void dispose() {
    _idController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // evita tinte en M3
        title: const Text('Supervisor Creado'),
        content: const Text('El supervisor ha sido creado exitosamente.'),
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
      'Número de teléfono': _telefonoController.text.trim(),
    };

    try {
      setState(() => _isSaving = true);
      await FirebaseFirestore.instance.collection('Supervisores').doc(id).set(data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showConfirmation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear el supervisor: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Supervisor', style: TextStyle(color: Colors.white)),
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Supervisor ID / Nombre'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el ID/Nombre del Supervisor'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.region,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                readOnly: true, // fija por navegación
                enableInteractiveSelection: false,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Supervisor', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}