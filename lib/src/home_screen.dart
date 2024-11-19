import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audioplayers/audioplayers.dart';
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
    _listenForTripStatusChanges();
    _listenForEmergencies();
  }

  void _listenForEmergencies() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    // Attach a listener to monitor changes in the `emergency` field
    tripRequestsRef.onChildChanged.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> tripData = event.snapshot.value as Map<dynamic, dynamic>;
        _handleEmergency(event.snapshot.key, tripData);
      }
    });
  }

  void _handleEmergency(String? tripId, Map<dynamic, dynamic> tripData) {
    if (tripData.containsKey('emergency') && tripId != null) {
      final bool isEmergency = tripData['emergency'] == true;
      final String userName = tripData['userName'] ?? 'Usuario desconocido';

      if (isEmergency) {
        String message = "¡¡¡Emergencia detectada!!! En viaje de $userName ($tripId), se requiere atención inmediata";
        _showEmergencyBanner(message);
        _playEmergencyAlert();
      }
    }
  }

  void _showEmergencyBanner(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.red,
    );

    // Ensure the context is still valid before showing
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  void _playEmergencyAlert() async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/emergency_alert.mp3'));
  }

  void _listenForTripStatusChanges() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    // Attach a listener to the trip_requests node
    tripRequestsRef.onChildChanged.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> tripData = event.snapshot.value as Map<dynamic, dynamic>;
        _handleStatusChange(event.snapshot.key, tripData);
      }
    });
  }

  void _handleStatusChange(String? tripId, Map<dynamic, dynamic> tripData) {
    if (tripData.containsKey('status') && tripId != null) {
      final String status = tripData['status'];
      final String userName = tripData['userName'] ?? 'Usuario desconocido';
      final String driver = tripData['driver'] ?? 'Conductor desconocido';

      String message;

      switch (status) {
        case 'pending':
          message = "Nueva solicitud de viaje detectada de $userName ($tripId)";
          break;
        case 'started':
          message = "El viaje de $userName ($tripId) y $driver ha comenzado";
          break;
        case 'passenger reached':
          message = "El conductor $driver ha llegado con el pasajero $userName ($tripId)";
          break;
        case 'picked up passenger':
          message = "El pasajero $userName ha sido recogido ($tripId)";
          break;
        case 'trip finished':
          message = "El viaje de $userName ($tripId) ha finalizado con éxito!";
          break;
        case 'trip cancelled':
          message = "$userName ($tripId) ha cancelado su viaje";
          break;
        default:
          return; // No action for unhandled statuses
      }

      // Show the banner notification
      _showBannerNotification(message);
      _playNotificationSound();
    }
  }

  void _showBannerNotification(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 6),
      backgroundColor: Colors.blue,
    );

    // Ensure the context is still valid before showing
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  void _playNotificationSound() async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/notification.mp3'));
  }

  // Step 1: Initialize and fetch the FCM token
  Future<void> _initializeFCM() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("Notification permission granted.");
        _fcmToken = await _messaging.getToken(
          vapidKey: "BD7fXudObgHwjzX_crRsNMPi5OW6txgyCXRIi_kPfBLd0G1NNGe-uoG9m7qT4T0FQrTmtHHAE5_YK4WOO6ln98A",
        );
        print("FCM Token: $_fcmToken");

        // Proceed to save the token only if it exists
        if (_fcmToken != null) {
          await _prepareDatabaseNode();
          await _uploadTokenToDatabase(_fcmToken!);
        }
      } else {
        print("Notification permission not granted.");
      }
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }

  // Step 2: Prepare the database node for the token if it doesn't exist
  Future<void> _prepareDatabaseNode() async {
    try {
      final controlRoomRef = _databaseReference.child('controlroom/${widget.usuario}');
      final snapshot = await controlRoomRef.once(); // Use `.once()` to read the data only once.

      if (snapshot.snapshot.value == null) {
        await controlRoomRef.set({
          'city': widget.region,
          'fcmToken_2': '',
        });
        print("Database node prepared for ${widget.usuario}.");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error preparing database node: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Step 3: Upload the token to the database
  Future<void> _uploadTokenToDatabase(String token) async {
    try {
      final controlRoomRef = _databaseReference.child('controlroom/${widget.usuario}');
      await controlRoomRef.update({'fcmToken_2': token});

      Fluttertoast.showToast(
        msg: "Token updated successfully in database.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error uploading token: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // Step 4: Listen for FCM token refresh events
  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      print("FCM Token refreshed: $newToken");
      setState(() {
        _fcmToken = newToken;
      });
      await _uploadTokenToDatabase(newToken);
    });
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