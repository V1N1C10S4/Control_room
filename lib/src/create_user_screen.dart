import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserCreationScreen extends StatefulWidget {
  final String usuario;
  final bool isSupervisor;
  final String region;

  const UserCreationScreen({
    Key? key,
    required this.usuario,
    required this.isSupervisor,
    required this.region,
  }) : super(key: key);

  @override
  _UserCreationScreenState createState() => _UserCreationScreenState();
}

class _UserCreationScreenState extends State<UserCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _nombreUsuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _fotoPerfilController = TextEditingController();
  final TextEditingController _numeroTelefonoController = TextEditingController();

  bool _isSaving = false;

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final userId = _userIdController.text.trim();

      final userData = {
        'Ciudad': _ciudadController.text.trim(),
        'NombreUsuario': _nombreUsuarioController.text.trim(),
        'Contraseña': _contrasenaController.text.trim(),
        'FotoPerfil': _fotoPerfilController.text.trim(),
        'NumeroTelefono': _numeroTelefonoController.text.trim(),
      };

      try {
        setState(() {
          _isSaving = true;
        });

        // Guardar documento en Firestore bajo "Usuarios/{userId}"
        await FirebaseFirestore.instance.collection('Usuarios').doc(userId).set(userData);

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
          SnackBar(content: Text('Error al crear el usuario: $e')),
        );
      }
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Usuario Creado'),
          content: const Text('El usuario ha sido creado exitosamente.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context); // Regresar a la pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
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
          'Crear Usuario',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'UserId'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese un UserId';
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
                controller: _nombreUsuarioController,
                decoration: const InputDecoration(labelText: 'NombreUsuario'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese el NombreUsuario';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contrasenaController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
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
                decoration: const InputDecoration(labelText: 'NumeroTelefono'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese el NumeroTelefono';
                  }
                  if (value.length != 10) {
                    return 'El número debe tener 10 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(120, 170, 90, 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Usuario',
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
    // Liberar los controladores
    _userIdController.dispose();
    _ciudadController.dispose();
    _nombreUsuarioController.dispose();
    _contrasenaController.dispose();
    _fotoPerfilController.dispose();
    _numeroTelefonoController.dispose();
    super.dispose();
  }
}