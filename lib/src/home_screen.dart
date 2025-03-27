import 'package:control_room/src/user_management_screen.dart';
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
import 'generate_trip_screen.dart';
import 'messages_screen.dart';
import 'scheduled_trip_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final Set<String> _shownStatuses = {};
  int _pendingCount = 0;
  int _authorizedCount = 0;
  int _inProgressCount = 0;
  int _startedCount = 0;
  int _passengerReachedCount = 0;
  int _pickedUpPassengerCount = 0;
  int _emergencyCount = 0;
  int _cancelledTripsCount = 0;
  int _pendingMessagesCount = 0;
  Set<String> _seenCancelledTrips = {};
  int _scheduledLessThan12h = 0; // 🔵 Antes _scheduledMoreThan24h
  int _scheduledLessThan6h = 0;  // 🟠 Antes _scheduledBetween6And24h
  int _scheduledLessThan2h = 0;
  int _unreviewedScheduledTrips = 0;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _listenForTokenRefresh();
    _listenForEmergencies();
    _listenForTripStatusChanges();
    _listenForTripRequests();
    _listenForOngoingTrips();
    _listenForEmergenciesCounter();
    _listenForCancelledTrips();
    _listenForPendingMessages();
    _listenForScheduledTrips();
    _listenForNewMessages();
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

  void _listenForPendingMessages() {
    _databaseReference.child('messages').onValue.listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> messagesMap = event.snapshot.value as Map<dynamic, dynamic>;
        int pendingCount = messagesMap.values.where((message) => message["attended"] == false).length;

        setState(() {
          _pendingMessagesCount = pendingCount;
        });
      } else {
        setState(() {
          _pendingMessagesCount = 0;
        });
      }
    });
  }

  void _listenForNewMessages() {
    _databaseReference.child('messages').onChildAdded.listen((event) async {
      final messageId = event.snapshot.key;
      final messageData = event.snapshot.value as Map<dynamic, dynamic>?;

      if (messageId != null && messageData != null) {
        // ✅ Filtro: Solo si no ha sido atendido
        if (messageData['attended'] == true) return;

        final String usuario = messageData['usuario'] ?? '';
        final String notificationKey = '$messageId-new_message';

        // ✅ Ya se mostró esta notificación
        if (_shownStatuses.contains(notificationKey)) return;

        try {
          // 🔍 Obtener ciudad del usuario
          final userDoc = await FirebaseFirestore.instance.collection('Usuarios').doc(usuario).get();

          if (userDoc.exists) {
            final String ciudad = userDoc.data()?['Ciudad'] ?? '';

            if (ciudad == widget.region) {
              _showBannerNotification("📨 Nuevo mensaje recibido de $usuario");
              _playNotificationSound();
              _shownStatuses.add(notificationKey); // ✅ Marcar como mostrado
            }
          }
        } catch (e) {
          print("Error al verificar ciudad del usuario $usuario: $e");
        }
      }
    });
  }

  void _listenForScheduledTrips() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        int lessThan12h = 0;
        int lessThan6h = 0;
        int lessThan2h = 0;
        int unreviewed = 0;

        DateTime now = DateTime.now();

        data.forEach((key, value) {
          if (value is Map && (value['status'] == "scheduled" || value['status'] == "scheduled approved") && value['city'] == widget.region) {
            if (value.containsKey("scheduled_at")) {
              DateTime scheduledTime = DateTime.parse(value["scheduled_at"]);
              Duration difference = scheduledTime.difference(now);

              if (difference.inHours < 2) {
                lessThan2h++;
              } else if (difference.inHours < 6) {
                lessThan6h++;
              } else if (difference.inHours < 12) {
                lessThan12h++;
              }
            }

            if (value['status'] == "scheduled") {
              unreviewed++;
            }
          }
        });

        setState(() {
          _scheduledLessThan12h = lessThan12h;
          _scheduledLessThan6h = lessThan6h;
          _scheduledLessThan2h = lessThan2h;
          _unreviewedScheduledTrips = unreviewed;
        });
      }
    });
  }

  void _handleEmergency(String? tripId, Map<dynamic, dynamic> tripData) {
    if (tripData.containsKey('emergency') && tripId != null) {
      final bool isEmergency = tripData['emergency'] == true;
      final String userName = tripData['userName'] ?? 'Usuario desconocido';
      final String tripCity = tripData['city'] ?? '';

      // Filtrar por región antes de mostrar la notificación
      if (tripCity != widget.region) {
        return; // Ignorar emergencias de otras regiones
      }

      if (isEmergency) {
        String message =
            "¡¡¡Emergencia detectada!!! En viaje de $userName ($tripId), se requiere atención inmediata";
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
      duration: const Duration(seconds: 6),
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

  void _handlePendingTrip(String? tripId, Map<dynamic, dynamic> tripData) {
    if (tripData.containsKey('status') && tripId != null) {
      final String status = tripData['status'];
      final String tripCity = tripData['city'] ?? '';

      // Filtrar por región antes de mostrar la notificación
      if (tripCity != widget.region) {
        return; // Ignorar notificaciones de otras regiones
      }

      if (status == 'pending' && !_shownStatuses.contains('$tripId-pending')) {
        final String userName = tripData['userName'] ?? 'Usuario desconocido';
        String message = "Nueva solicitud de viaje detectada de $userName ($tripId) en $tripCity";

        _showBannerNotification(message);
        _playNotificationSound();

        // Marca el banner como mostrado
        _shownStatuses.add('$tripId-pending');
      }
    }
  }

  void _listenForTripStatusChanges() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    // Escucha entradas nuevas con "status: pending".
    tripRequestsRef.onChildAdded.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> tripData = event.snapshot.value as Map<dynamic, dynamic>;
        _handlePendingTrip(event.snapshot.key, tripData);
      }
    });

    // Escucha cambios en los estados de las entradas existentes.
    tripRequestsRef.onChildChanged.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> tripData = event.snapshot.value as Map<dynamic, dynamic>;
        _handleStatusChange(event.snapshot.key, tripData);
      }
    });
  }

  // Maneja los cambios de estado en entradas existentes.
  void _handleStatusChange(String? tripId, Map<dynamic, dynamic> tripData) {
    if (tripData.containsKey('status') && tripId != null) {
      final String status = tripData['status'];
      final String tripCity = tripData['city'] ?? '';

      // Filtrar por región antes de mostrar la notificación
      if (tripCity != widget.region) {
        return; // Ignorar cambios de estado de otras regiones
      }

      // Evitar notificaciones repetidas para el mismo estado
      if (_shownStatuses.contains('$tripId-$status')) return;

      final String userName = tripData['userName'] ?? 'Usuario desconocido';
      final String driver = tripData['driver'] ?? 'Conductor desconocido';

      String message;
      switch (status) {
        case 'scheduled':
          message = "Se ha detectado un nuevo viaje programado de $userName ($tripId)";
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
        case 'on_stop_way':
          message = "El conductor va en camino hacia la parada con el pasajero $userName ($tripId)";
          break;
        case 'stop_reached':
          message = "El conductor llegó a la parada intermedia del viaje de $userName ($tripId)";
          break;
        case 'trip finished':
          message = "El viaje de $userName ($tripId) ha finalizado con éxito!";
          break;
        case 'trip cancelled':
          message = "$userName ($tripId) ha cancelado su viaje";
          break;
        default:
          return; // No hacer nada para estados no manejados
      }

      _showBannerNotification(message);
      _playNotificationSound();

      // Marca el estado como mostrado
      _shownStatuses.add('$tripId-$status');
    }
  }

  // Muestra una notificación tipo banner.
  void _showBannerNotification(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      duration: const Duration(seconds: 6),
      backgroundColor: Colors.blue,
    );

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

  void _listenForTripRequests() {
    _databaseReference.child('trip_requests').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        int pending = 0;
        int authorized = 0;
        int inProgress = 0;

        data.forEach((key, value) {
          if (value['city'] == widget.region) { // Filtrar por región
            String status = value['status'] ?? '';

            if (status == 'pending') pending++;
            else if (status == 'authorized') authorized++;
            else if (status == 'in progress') inProgress++;
          }
        });

        setState(() {
          _pendingCount = pending;
          _authorizedCount = authorized;
          _inProgressCount = inProgress;
        });
      }
    });
  }

  void _listenForOngoingTrips() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    tripRequestsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        int started = 0;
        int passengerReached = 0;
        int pickedUp = 0;

        data.forEach((key, value) {
          if (value is Map) {
            final String status = value['status'] ?? '';
            final String tripCity = value['city'] ?? '';

            // Filtrar por la región del usuario
            if (tripCity == widget.region) {
              if (status == 'started') {
                started++;
              } else if (status == 'passenger reached') {
                passengerReached++;
              } else if (status == 'picked up passenger') {
                pickedUp++;
              }
            }
          }
        });

        // Actualizar el estado con los nuevos valores
        setState(() {
          _startedCount = started;
          _passengerReachedCount = passengerReached;
          _pickedUpPassengerCount = pickedUp;
        });
      }
    });
  }

  void _listenForEmergenciesCounter() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    tripRequestsRef.onChildChanged.listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> tripData = event.snapshot.value as Map<dynamic, dynamic>;
        bool isEmergency = tripData['emergency'] == true;
        setState(() {
          if (isEmergency) {
            _emergencyCount++;
          } else {
            _emergencyCount = (_emergencyCount > 0) ? _emergencyCount - 1 : 0;
          }
        });
      }
    });
  }

  void _listenForCancelledTrips() {
    final tripRequestsRef = _databaseReference.child('trip_requests');

    tripRequestsRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;

        int unreviewedCount = 0; // Contador de cancelaciones NO revisadas

        data.forEach((key, value) {
          if (value is Map && value['status'] == "trip cancelled" && value['city'] == widget.region) {
            bool isReviewed = value.containsKey('reviewed') ? value['reviewed'] == true : false;

            if (!isReviewed) {
              unreviewedCount++; // Solo cuenta los NO revisados
            }
          }
        });

        setState(() {
          _cancelledTripsCount = unreviewedCount;
        });
      } else {
        setState(() {
          _cancelledTripsCount = 0;
        });
      }
    });
  }

  Widget _buildStatusBubble(int count, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBubble(int count) {
    if (count == 0) return SizedBox(); // Si el contador es 0, no muestra la burbuja.

    return Positioned(
      top: -5,
      right: -5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
          ],
        ),
        child: Text(
          count > 9 ? '9+' : count.toString(), // Muestra "9+" si el valor es mayor a 9
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _resetCancelledTripsCount() {
    setState(() {
      _cancelledTripsCount = 0;
      _seenCancelledTrips.clear(); // Vaciar la lista de viajes visualizados
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
                    child: Stack(
                      children: [
                        SizedBox.expand(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(180, 180, 255, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScheduledTripScreen(region: widget.region),
                                ),
                              );
                            },
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_note, size: 50, color: Colors.white), 
                                SizedBox(height: 10),
                                Text(
                                  'Viajes Programados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_scheduledLessThan2h > 0) _buildStatusBubble(_scheduledLessThan2h, Colors.red, Icons.alarm), // 🔴 Menos de 2 horas
                              if (_scheduledLessThan6h > 0) _buildStatusBubble(_scheduledLessThan6h, Colors.yellow, Icons.timer), // 🟠 Menos de 6 horas
                              if (_scheduledLessThan12h > 0) _buildStatusBubble(_scheduledLessThan12h, Colors.green, Icons.access_time), // 🔵 Menos de 12 horas
                              if (_unreviewedScheduledTrips > 0) _buildStatusBubble(_unreviewedScheduledTrips, Colors.blue, Icons.visibility_off), // 🟣 No revisados
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Stack(
                      children: [
                        SizedBox.expand(
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
                                    region: widget.region,
                                  ),
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
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_pendingCount > 0) _buildStatusBubble(_pendingCount, Colors.red, Icons.new_releases),
                              if (_authorizedCount > 0) _buildStatusBubble(_authorizedCount, Colors.orange, Icons.check_circle),
                              if (_inProgressCount > 0) _buildStatusBubble(_inProgressCount, Colors.blue, Icons.directions_run),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Stack(
                      children: [
                        SizedBox.expand(
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
                                  ),
                                ),
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
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_startedCount > 0) _buildStatusBubble(_startedCount, Colors.blue, Icons.directions_car),
                              if (_passengerReachedCount > 0) _buildStatusBubble(_passengerReachedCount, Colors.orange, Icons.place),
                              if (_pickedUpPassengerCount > 0) _buildStatusBubble(_pickedUpPassengerCount, Colors.green, Icons.airplane_ticket),
                            ],
                          ),
                        ),
                      ],
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
                    child: Stack(
                      children: [
                        SizedBox.expand(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[300]!,
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
                        if (_emergencyCount > 0)
                          Positioned(top: 8, right: 8, child: _buildNotificationBubble(_emergencyCount)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Stack(
                      children: [
                        SizedBox.expand(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(255, 99, 71, 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            onPressed: () async {
                              // Marcar todos los viajes cancelados como revisados en Firebase
                              final tripRequestsRef = _databaseReference.child('trip_requests');
                              final snapshot = await tripRequestsRef.orderByChild('status').equalTo('trip cancelled').get();

                              if (snapshot.exists) {
                                final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
                                
                                data.forEach((key, value) {
                                  if (value is Map && value['city'] == widget.region) {
                                    tripRequestsRef.child(key).update({'reviewed': true});
                                  }
                                });
                              }

                              _resetCancelledTripsCount(); // Actualiza la UI
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
                        if (_cancelledTripsCount > 0)
                          Positioned(top: 8, right: 8, child: _buildNotificationBubble(_cancelledTripsCount)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isSupervisor)
              const SizedBox(height: 16),
            if (widget.isSupervisor)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(150, 190, 65, 1), // Verde militar
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue, // Color similar al de la imagen
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MessagesScreen(region: widget.region),
                                  ),
                                );
                              },
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat, size: 50, color: Colors.white), // Icono de mensajes
                                  SizedBox(height: 10),
                                  Text(
                                    'Mensajes',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_pendingMessagesCount > 0)
                            Positioned(top: 8, right: 8, child: _buildNotificationBubble(_pendingMessagesCount)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16), // Espacio entre los botones
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(120, 170, 90, 1), // Verde diferente
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserManagementScreen(
                                usuario: widget.usuario,
                                region: widget.region,
                                isSupervisor: widget.isSupervisor,
                              ),
                            ),
                          );
                        },
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 50, color: Colors.white), // Icono de usuarios
                            SizedBox(height: 10),
                            Text(
                              'Gestión de Pasajeros',
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
            if (widget.isSupervisor) // Solo mostrar el botón si es supervisor
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity, // Ocupa todo el renglón
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(107, 202, 186, 1),
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GenerateTripScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.map, size: 28, color: Colors.white), // Ícono que representa un viaje
                        SizedBox(width: 8),
                        Text(
                          'Generar Viaje',
                          style: TextStyle(color: Colors.white, fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}