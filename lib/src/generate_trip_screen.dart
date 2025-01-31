import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

class GenerateTripScreen extends StatefulWidget {
  const GenerateTripScreen({Key? key}) : super(key: key);

  @override
  State<GenerateTripScreen> createState() => _GenerateTripScreenState();
}

class _GenerateTripScreenState extends State<GenerateTripScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Completer<GoogleMapController> _mapController = Completer();

  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  String? _pickupAddress;
  String? _destinationAddress;
  String? userPhone;
  int passengers = 1;
  int luggage = 0;
  int pets = 0;
  int babySeats = 0;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> users = [];
  String? selectedUserId;
  String? userName;
  String? city;


  static const String proxyBaseUrl =
      "https://34.120.209.209.nip.io/militripproxy";
  List<Map<String, dynamic>> _pickupPredictions = [];
  List<Map<String, dynamic>> _destinationPredictions = [];

  // Información del viaje
  String? _distanceText;
  String? _durationText;
  String? _arrivalTimeText;

  @override
  void initState() {
    super.initState();
    _loadUsersFromFirestore();
  }

  Future<void> _loadUsersFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Usuarios').get();
    setState(() {
      users = snapshot.docs;
    });
  }

  Future<List<Map<String, dynamic>>> _getPlacePredictions(String input) async {
    String url =
        'https://34.120.209.209.nip.io/militripproxy/place/autocomplete/json?input=$input&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    }
    return [];
  }

  void _onPickupSearchChanged(String input) async {
    if (input.isNotEmpty) {
      final predictions = await _getPlacePredictions(input);
      setState(() {
        _pickupPredictions = predictions;
      });
    } else {
      setState(() {
        _pickupPredictions = [];
      });
    }
  }

  void _onDestinationSearchChanged(String input) async {
    if (input.isNotEmpty) {
      final predictions = await _getPlacePredictions(input);
      setState(() {
        _destinationPredictions = predictions;
      });
    } else {
      setState(() {
        _destinationPredictions = [];
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId, bool isPickup) async {
    // Construir la URL completa para Google Places a través de tu proxy
    String url =
        '$proxyBaseUrl/place/details/json?place_id=$placeId&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);

          setState(() {
            if (isPickup) {
              _pickupLocation = latLng;
              _pickupAddress = data['result']['formatted_address'];
              _pickupController.text = _pickupAddress ?? '';
              _pickupPredictions = [];
              _markers.add(Marker(
                markerId: MarkerId('pickup'),
                position: latLng,
                icon: BitmapDescriptor.defaultMarker, // Color por defecto (rojo)
              ));
            } else {
              _destinationLocation = latLng;
              _destinationAddress = data['result']['formatted_address'];
              _destinationController.text = _destinationAddress ?? '';
              _destinationPredictions = [];
              _markers.add(Marker(
                markerId: MarkerId('destination'),
                position: latLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Azul
              ));
            }
            _drawPolyline();
          });
        } else {
          print("Error en la respuesta de la API: ${data['status']}");
        }
      } else {
        print("Error en la solicitud: ${response.statusCode}");
      }
    } catch (e) {
      print("Excepción en la solicitud: $e");
    }
  }

  Future<void> _drawPolyline() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    // Construir la URL completa usando el proxy
    String url =
        '$proxyBaseUrl/directions/json?origin=${_pickupLocation!.latitude},${_pickupLocation!.longitude}&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        // Extraer información adicional: distancia, duración y hora de llegada
        final route = data['routes'][0]['legs'][0];
        final distanceText = route['distance']['text'];
        final durationText = route['duration']['text'];
        final durationValue = route['duration']['value'];
        final arrivalTime = DateTime.now().add(Duration(seconds: durationValue));
        final arrivalTimeText =
            "${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}";

        // Decodificar los puntos del polyline
        List<PointLatLng> points = polylinePoints
            .decodePolyline(data['routes'][0]['overview_polyline']['points']);

        setState(() {
          // Limpiar y agregar los puntos de la polyline
          _polylineCoordinates.clear();
          for (var point in points) {
            _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }

          // Configurar la polyline en el mapa
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: PolylineId('route'),
            points: _polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));

          // Actualizar las variables de información del viaje
          _distanceText = distanceText;
          _durationText = durationText;
          _arrivalTimeText = arrivalTimeText;
        });
      } else {
        print("Error en la respuesta de la API: ${data['status']}");
      }
    } else {
      print("Error en la solicitud: ${response.statusCode}");
    }
  }

  Future<void> _sendTripRequest() async {
    if (selectedUserId == null || _pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Seleccione el usuario, el punto de recogida y el destino.'),
      ));
      return;
    }

    // Inicializa el campo fcmToken como nulo
    String? fcmToken;

    // Buscar coincidencias en Firebase Realtime Database
    final DatabaseReference databaseRef = FirebaseDatabase.instance.ref('trip_requests');
    try {
      final snapshot = await databaseRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value['userName'] == userName) { // Comparar userName
            fcmToken = value['fcmToken']; // Copiar el fcmToken si hay coincidencia
            print("FCM Token encontrado: $fcmToken");
            return; // Rompe el bucle una vez encontrada la coincidencia
          }
        });
      }
    } catch (e) {
      print("Error al buscar FCM Token: $e");
    }

    // Crear la solicitud de viaje con el fcmToken si fue encontrado
    final tripData = {
      'userId': selectedUserId,
      'userName': userName,
      'city': city,
      'telefonoPasajero': userPhone ?? "No disponible",
      'pickup': {
        'latitude': _pickupLocation!.latitude,
        'longitude': _pickupLocation!.longitude,
        'placeName': _pickupAddress ?? '',
      },
      'destination': {
        'latitude': _destinationLocation!.latitude,
        'longitude': _destinationLocation!.longitude,
        'placeName': _destinationAddress ?? '',
      },
      'passengers': passengers,
      'luggage': luggage,
      'pets': pets,
      'babySeats': babySeats,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'emergency': false,
      if (fcmToken != null) 'fcmToken': fcmToken, // Añadir fcmToken solo si existe
    };

    // Guardar en Firebase Realtime Database
    databaseRef.push().set(tripData).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Solicitud de viaje creada exitosamente.'),
      ));
      _resetForm();

    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al enviar la solicitud: $error'),
      ));
    });
  }

  void _resetForm() {
    setState(() {
      _pickupController.clear();
      _destinationController.clear();
      _pickupLocation = null;
      _destinationLocation = null;
      _pickupAddress = null;
      _destinationAddress = null;
      _pickupPredictions = [];
      _destinationPredictions = [];
      _markers.clear();
      _polylines.clear();
      selectedUserId = null;
      passengers = 1;
      luggage = 0;
      pets = 0;
      babySeats = 0;
      _distanceText = null;
      _durationText = null;
      _arrivalTimeText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Viaje', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(107, 202, 186, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedUserId,
                items: users.map((user) => DropdownMenuItem(
                      value: user.id,
                      child: Text(user['NombreUsuario']), // Mostrar el nombre del usuario
                    )).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedUserId = value; // ID del usuario seleccionado
                    // Buscar el documento del usuario seleccionado
                    final selectedUser = users.firstWhere((user) => user.id == value);
                    userName = selectedUser['NombreUsuario']; // Capturar NombreUsuario
                    city = selectedUser['Ciudad']; // Capturar Ciudad
                  });
                      // ✅ Obtener el teléfono del pasajero desde Firestore
                  DocumentSnapshot<Map<String, dynamic>> userDoc =
                      await FirebaseFirestore.instance.collection('Usuarios').doc(value).get();

                  if (userDoc.exists) {
                    setState(() {
                      userPhone = userDoc.data()?['Telefono'] ?? "No disponible";
                    });
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Usuario',
                ),
              ),
              const SizedBox(height: 16),
              _buildLocationField(
                controller: _pickupController,
                label: 'Punto de Recogida',
                onChanged: _onPickupSearchChanged,
                predictions: _pickupPredictions,
                isPickup: true,
              ),
              const SizedBox(height: 16),
              _buildLocationField(
                controller: _destinationController,
                label: 'Destino',
                onChanged: _onDestinationSearchChanged,
                predictions: _destinationPredictions,
                isPickup: false,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildNumericField('Pasajeros', (value) {
                    passengers = int.tryParse(value) ?? 1;
                  }),
                  const SizedBox(width: 16),
                  _buildNumericField('Equipaje', (value) {
                    luggage = int.tryParse(value) ?? 0;
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildNumericField('Mascotas', (value) {
                    pets = int.tryParse(value) ?? 0;
                  }),
                  const SizedBox(width: 16),
                  _buildNumericField('Sillas para Bebés', (value) {
                    babySeats = int.tryParse(value) ?? 0;
                  }),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    height: 300,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(19.432608, -99.133209), // Ciudad de México
                        zoom: 12,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController.complete(controller);
                      },
                    ),
                  ),
                if (_distanceText != null &&
                    _durationText != null &&
                    _arrivalTimeText != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4.0,
                            spreadRadius: 1.0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Distancia: $_distanceText",
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Duración: $_durationText",
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Hora estimada de llegada: $_arrivalTimeText",
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _sendTripRequest,
                child: const Text('Crear Solicitud de Viaje'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    required List<Map<String, dynamic>> predictions,
    required bool isPickup,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
        if (predictions.isNotEmpty)
          Container(
            height: 200, // Define una altura fija para las predicciones
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                return ListTile(
                  title: Text(prediction['description']),
                  onTap: () {
                    _getPlaceDetails(prediction['place_id'], isPickup);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNumericField(String label, Function(String) onChanged) {
    return Expanded(
      child: TextField(
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}