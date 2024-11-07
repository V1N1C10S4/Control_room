import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_room/src/home_screen.dart'; // Importa el archivo home_screen.dart

class MyAppForm extends StatefulWidget {
  const MyAppForm({super.key});

  @override
  State<MyAppForm> createState() => _MyAppFormState();
}

class _MyAppFormState extends State<MyAppForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _verificarCredenciales(BuildContext context, String usuario, String contrasena) async {
    try {
      // Verificar primero en la colección SupControlRoom
      final docRefSup = FirebaseFirestore.instance.collection('SupControlRoom').doc(usuario);
      final snapshotSup = await docRefSup.get();

      if (snapshotSup.exists) {
        // El usuario es supervisor
        final userData = snapshotSup.data();
        final storedPassword = userData?['Contraseña'];

        if (storedPassword == contrasena) {
          Fluttertoast.showToast(
            msg: 'Credenciales válidas (Supervisor)',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 3,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );

          if (mounted) {
            // Navegar a la pantalla principal y pasar el parámetro isSupervisor como true
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(usuario: usuario, isSupervisor: true),
              ),
            );
          }
        } else {
          _mostrarErrorCredenciales();
        }
      } else {
        // Verificar en la colección ControlRoom (usuario común)
        final docRef = FirebaseFirestore.instance.collection('ControlRoom').doc(usuario);
        final snapshot = await docRef.get();

        if (snapshot.exists) {
          final userData = snapshot.data();
          final storedPassword = userData?['Contraseña'];

          if (storedPassword == contrasena) {
            Fluttertoast.showToast(
              msg: 'Credenciales válidas',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 3,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );

            if (mounted) {
              // Navegar a la pantalla principal y pasar el parámetro isSupervisor como false
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(usuario: usuario, isSupervisor: false),
                ),
              );
            }
          } else {
            _mostrarErrorCredenciales();
          }
        } else {
          Fluttertoast.showToast(
            msg: 'El usuario no existe en la base de datos',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 3,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error al verificar credenciales: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _mostrarErrorCredenciales() {
    Fluttertoast.showToast(
      msg: 'Credenciales inválidas',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius2 = BorderRadius.all(Radius.circular(20.0));
    const verticalSpacing = SizedBox(height: 20.0);

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 27, 25, 31),
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 100,
            top: -460,
            child: Transform.rotate(
              angle: 0.7,
              child: Container(
                width: 10,
                height: MediaQuery.of(context).size.height,
                color: const Color.fromRGBO(149,189,64,100),
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: -490,
            child: Transform.rotate(
              angle: 0.7,
              child: Container(
                width: 10,
                height: MediaQuery.of(context).size.height,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          ),
          Positioned(
            left: 100,
            top: -520,
            child: Transform.rotate(
              angle: 0.7,
              child: Container(
                width: 10,
                height: MediaQuery.of(context).size.height,
                color: const Color.fromRGBO(149,189,64,100),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 90.0,
            ),
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 350,
                    width: 400,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: borderRadius2,
                      image: DecorationImage(
                        image: AssetImage('images/milipol_logo.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Text(
                    '        ',
                    style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 30.0,
                    ),
                  ),
                  verticalSpacing,
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white), // Color de texto blanco
                    cursorColor: Colors.white, // Color del cursor blanco
                    enableInteractiveSelection: false,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Nombre de usuario',
                      hintStyle: TextStyle(color: Colors.white), // Color de texto del hint blanco
                      labelText: 'Usuario',
                      labelStyle: TextStyle(color: Colors.white), // Color de la etiqueta blanco
                      suffixIcon: Icon(Icons.verified_user, color: Colors.white), // Color del icono blanco
                      focusedBorder: OutlineInputBorder(
                        borderRadius: borderRadius2,
                        borderSide: BorderSide(color: Colors.white), // Color del borde cuando está enfocado
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: borderRadius2,
                        borderSide: BorderSide(color: Colors.white), // Color del borde cuando no está enfocado
                      ),
                    ),
                    onSubmitted: (value) {
                      _usernameController.text = value;
                    },
                  ),
                  verticalSpacing,
                  TextField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white), // Color de texto blanco
                    cursorColor: Colors.white, // Color del cursor blanco
                    obscureText: true,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      hintText: 'Contraseña',
                      hintStyle: TextStyle(color: Colors.white), // Color de texto del hint blanco
                      labelText: 'Contraseña',
                      labelStyle: TextStyle(color: Colors.white), // Color de la etiqueta blanco
                      suffixIcon: Icon(Icons.lock, color: Colors.white), // Color del icono blanco
                      focusedBorder: OutlineInputBorder(
                        borderRadius: borderRadius2,
                        borderSide: BorderSide(color: Colors.white), // Color del borde cuando está enfocado
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: borderRadius2,
                        borderSide: BorderSide(color: Colors.white), // Color del borde cuando no está enfocado
                      ),
                    ),
                    onSubmitted: (value) {
                      _passwordController.text = value;
                    },
                  ),
                  verticalSpacing,
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        final usuario = _usernameController.text;
                        final contrasena = _passwordController.text;

                        await _verificarCredenciales(context, usuario, contrasena);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(149,189,64,100),
                      ),
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(color: Colors.white)
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'App Login',
    home: MyAppForm(),
  ));
}