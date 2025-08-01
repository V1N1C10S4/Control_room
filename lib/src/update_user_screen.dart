import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class UpdateUserScreen extends StatefulWidget {
  final String usuario;
  final String userId;
  final Map<String, dynamic> userData;

  const UpdateUserScreen({
    super.key,
    required this.usuario,
    required this.userId,
    required this.userData,
  });

  @override
  _UpdateUserScreenState createState() => _UpdateUserScreenState();
}

class _UpdateUserScreenState extends State<UpdateUserScreen> {
  final _userNameController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _numeroTelefonoController = TextEditingController();
  final _fotoPerfilController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userNameController.text = widget.userData['NombreUsuario'] ?? '';
    _ciudadController.text = widget.userData['Ciudad'] ?? '';
    _numeroTelefonoController.text = widget.userData['NumeroTelefono'] ?? '';
    _fotoPerfilController.text = widget.userData['FotoPerfil'] ?? '';
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _ciudadController.dispose();
    _numeroTelefonoController.dispose();
    _fotoPerfilController.dispose();
    super.dispose();
  }

  void _confirmAndUpdateUserData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cambios'),
          content: const Text('¿Estás seguro de que deseas guardar estos cambios?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo sin guardar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Botón rojo
              ),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateUserData();
                Navigator.of(context).pop(); // Cierra el diálogo tras confirmar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
              ),
              child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _seleccionarYSubirNuevaFoto(String userId) async {
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

  void _updateUserData() {
    // Referencia al documento del usuario en Firestore
    final userRef = FirebaseFirestore.instance.collection('Usuarios').doc(widget.userId);

    // Datos actualizados
    final updatedData = {
      'NombreUsuario': _userNameController.text.trim(),
      'Ciudad': _ciudadController.text.trim(),
      'NumeroTelefono': _numeroTelefonoController.text.trim(),
      'FotoPerfil': _fotoPerfilController.text.trim(),
    };

    // Actualizar documento en Firestore
    userRef.update(updatedData).then((_) {
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos del usuario actualizados exitosamente.')),
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
          'Actualizar Usuario - ${widget.userData['NombreUsuario'] ?? 'Sin Nombre'}',
          style: const TextStyle(color: Colors.white), // Texto blanco
        ),
        backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
        iconTheme: const IconThemeData(color: Colors.white), // Iconos blancos
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _userNameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ciudadController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _numeroTelefonoController,
              decoration: const InputDecoration(labelText: 'Número de Teléfono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: widget.userId,
              decoration: const InputDecoration(
                labelText: 'Usuario',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            if (widget.userData.containsKey('Contraseña'))
            TextFormField(
              initialValue: widget.userData['Contraseña'],
              decoration: const InputDecoration(
                labelText: 'Contraseña',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _seleccionarYSubirNuevaFoto(widget.userId),
              icon: const Icon(Icons.image),
              label: const Text('Cambiar Foto de Perfil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
            if (_fotoPerfilController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("Imagen actualizada ✅", style: TextStyle(color: Colors.green)),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmAndUpdateUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde militar
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Guardar Cambios',
                style: TextStyle(fontSize: 16, color: Colors.white), // Texto blanco
              ),
            ),
          ],
        ),
      ),
    );
  }
}