import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

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
  final TextEditingController _nombreUsuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _numeroTelefonoController = TextEditingController();

  bool _isSaving = false;
  bool _isPasswordVisible = false; // Nueva variable para controlar la visibilidad
  String? _fotoPerfilURL;

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final userId = _userIdController.text.trim();

      final userData = {
        'Ciudad': widget.region,
        'NombreUsuario': _nombreUsuarioController.text.trim(),
        'Contraseña': _contrasenaController.text.trim(),
        'FotoPerfil': _fotoPerfilURL ?? '',
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
          SnackBar(content: Text('Error al crear el pasajero: $e')),
        );
      }
    }
  }

  Future<void> _seleccionarYSubirFoto(String userId) async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      final reader = html.FileReader();

      if (file != null) {
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final data = Uint8List.fromList(reader.result as List<int>);
        final storageRef = FirebaseStorage.instance.ref().child('user_profile_pictures/$userId.jpg');

        try {
          final snapshot = await storageRef.putData(data);
          final downloadUrl = await snapshot.ref.getDownloadURL();

          setState(() {
            _fotoPerfilURL = downloadUrl;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil subida correctamente.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir la foto: $e')),
          );
        }
      }
    });
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pasajero Creado'),
          content: const Text('El pasajero ha sido creado exitosamente.'),
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
                initialValue: widget.region,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                readOnly: true,
                enableInteractiveSelection: true,
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
                obscureText: !_isPasswordVisible, // Usa la variable para controlar la visibilidad
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Foto de Perfil", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      final userId = _userIdController.text.trim();
                      if (userId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor ingresa el User ID antes de subir la imagen.')),
                        );
                        return;
                      }
                      _seleccionarYSubirFoto(userId);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Seleccionar Imagen"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(120, 170, 90, 1),
                      foregroundColor: Colors.white,
                    ),
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
                        'Guardar Pasajero',
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
    _nombreUsuarioController.dispose();
    _contrasenaController.dispose();
    _numeroTelefonoController.dispose();
    super.dispose();
  }
}