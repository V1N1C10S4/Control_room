import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'trip_request_screen.dart';
import 'ongoing_trip_screen.dart';
import 'finished_trip_screen.dart';
import 'driver_availability.dart';
import 'driver_management_screen.dart';
import 'login_screen.dart';
import 'emergency_during_trip_screen.dart';
import 'cancelled_trip_screen.dart';

class HomeScreen extends StatefulWidget {
  final String usuario;
  final bool isSupervisor;
  final String region;

  const HomeScreen({
    Key? key,
    required this.usuario,
    required this.isSupervisor,
    required this.region,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _listenForTokenRefresh();
  }

  Future<void> _initializeFCM() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("Notification permission granted.");

        // Retrieve the FCM token for the device
        _fcmToken = await _messaging.getToken(
          vapidKey: "BD7fXudObgHwjzX_crRsNMPi5OW6txgyCXRIi_kPfBLd0G1NNGe-uoG9m7qT4T0FQrTmtHHAE5_YK4WOO6ln98A",
        );
        if (_fcmToken != null) {
          print("Initial FCM Token: $_fcmToken");
          await _updateTokenInDatabase(_fcmToken!);
        }
      } else {
        print("Notification permission not granted.");
      }
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }

  void _listenForTokenRefresh() {
    // Listen for FCM token refresh events
    _messaging.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      setState(() {
        _fcmToken = newToken;
      });
      await _updateTokenInDatabase(newToken);
    });
  }

  Future<void> _updateTokenInDatabase(String token) async {
    try {
      final controlRoomRef = _databaseReference.child('controlroom/${widget.usuario}');

      // Check if the "controlroom/${usuario}" node exists
      final snapshot = await controlRoomRef.get();
      if (!snapshot.exists) {
        // Create the node if it doesn't exist
        await controlRoomRef.set({
          'fcmToken_2': token,
          'city': widget.region,
        });
        Fluttertoast.showToast(
          msg: "Token and city created in database.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        // Update the token and city if the node exists
        await controlRoomRef.update({
          'fcmToken_2': token,
          'city': widget.region,
        });
        Fluttertoast.showToast(
          msg: "Token and city updated in database.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error updating token in database: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Función para cerrar sesión
  void _cerrarSesion(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MyAppForm()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Título dinámico según la región
    final String appBarTitle =
        widget.region == 'Tabasco' ? 'Control Room Tabasco' : 'Control Room CDMX';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(149, 189, 64, 1), // Verde militar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              _cerrarSesion(context);
            },
          ),
        ],
      ),
      body: Container(
        color: const Color.fromARGB(255, 27, 25, 31), // Fondo negro
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripRequestScreen(
                                usuario: widget.usuario,
                                isSupervisor: widget.isSupervisor,
                                region: widget.region),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Solicitudes de Viajes',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(207, 215, 107, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => OngoingTripScreen(
                                    usuario: widget.usuario,
                                    region: widget.region,
                                  )),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Viajes en Progreso',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(158, 212, 176, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => FinishedTripScreen(
                                    usuario: widget.usuario,
                                    region: widget.region,
                                  )),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Viajes Terminados',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(110, 191, 137, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DriverAvailability(
                                    usuario: widget.usuario,
                                    region: widget.region,
                                  )),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_taxi, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Conductores Disponibles',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[300], // Color rojo tenue
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmergencyDuringTripScreen(region: widget.region),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Emergencias',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(255, 99, 71, 1), // Rojo tomate
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CancelledTripsScreen(region: widget.region),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, size: 50, color: Colors.white),
                          SizedBox(height: 10),
                          Text(
                            'Viajes Cancelados',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isSupervisor)
              const SizedBox(height: 16),
            if (widget.isSupervisor)
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(150, 190, 65, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverManagementScreen(
                          usuario: widget.usuario,
                          region: widget.region,
                        ),
                      ),
                    );
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 50, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Gestión de Conductores y Vehículos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}