import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:control_room/src/home_screen.dart';
import 'package:web/web.dart' as html;
import 'dart:js_interop';

// Declaración JS interop
@JS('Notification')
@staticInterop
class NotificationJS {}

extension NotificationJSExtension on NotificationJS {
  external JSPromise<JSString> requestPermission();
}

@JS('Notification')
external NotificationJS get notification;

class MyAppForm extends StatefulWidget {
  const MyAppForm({super.key});

  @override
  State<MyAppForm> createState() => _MyAppFormState();
}

class _MyAppFormState extends State<MyAppForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<String> solicitarPermisoNotificaciones() async {
    try {
      final JSPromise<JSString> promise = notification.requestPermission();
      final JSString permissionJS = await promise.toDart;
      return permissionJS.toDart;
    } catch (e) {
      print('⚠️ No se pudo obtener permiso de notificación: $e');
      return 'denied';
    }
  }

  Future<void> _verificarCredenciales(BuildContext context, String usuario, String contrasena) async {
    try {
      // Lista de colecciones y sus respectivos roles y regiones
      final List<Map<String, dynamic>> collections = [
        {'name': 'SupControlRoomTabasco', 'isSupervisor': true, 'region': 'Tabasco'},
        {'name': 'SupControlRoomCDMX', 'isSupervisor': true, 'region': 'CDMX'},
        {'name': 'ControlRoomTabasco', 'isSupervisor': false, 'region': 'Tabasco'},
        {'name': 'ControlRoomCDMX', 'isSupervisor': false, 'region': 'CDMX'},
      ];

      for (var collection in collections) {
        final docRef = FirebaseFirestore.instance.collection(collection['name']).doc(usuario);
        final snapshot = await docRef.get();

        if (snapshot.exists) {
          // Usuario encontrado en la colección actual
          final userData = snapshot.data();
          final storedPassword = userData?['Contraseña'];

          if (storedPassword == contrasena) {
            Fluttertoast.showToast(
              msg: 'Credenciales válidas (${collection['region']} - ${collection['isSupervisor'] ? "Supervisor" : "Monitorista"})',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 3,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );

            // Guardar sesión en sessionStorage
            html.window.sessionStorage['usuario'] = usuario;
            html.window.sessionStorage['region'] = collection['region'];
            html.window.sessionStorage['isSupervisor'] = collection['isSupervisor'].toString();

            if (mounted) {
                final String permission = await solicitarPermisoNotificaciones();

                print('🔔 Permiso notificación: $permission');

                if (permission != 'granted') {
                  Fluttertoast.showToast(
                    msg: 'No se otorgaron permisos para notificaciones.',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                }

              // Navegar a la pantalla principal y pasar los parámetros
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    usuario: usuario,
                    isSupervisor: collection['isSupervisor'],
                    region: collection['region'],
                  ),
                ),
              );
            }
            return;
          } else {
            // Contraseña incorrecta
            Fluttertoast.showToast(
              msg: 'Credenciales inválidas',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 3,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            return;
          }
        }
      }

      // Usuario no encontrado en ninguna colección
      Fluttertoast.showToast(
        msg: 'El usuario no existe en la base de datos',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      // Error general al verificar credenciales
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