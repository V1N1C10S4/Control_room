import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'generate_stops_for_trip_screen.dart';

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
  List<Map<String, dynamic>> _selectedStops = [];
  DateTime? _scheduledDateTime;
  bool _needSecondDriver = false;


  static const String proxyBaseUrl =
      "https://googleplacesproxy-3tomukm2tq-uc.a.run.app";
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
        'https://googleplacesproxy-3tomukm2tq-uc.a.run.app/place/autocomplete/json?input=$input&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
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

  Future<void> _navigateToStopsScreen() async {
    final stops = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerateStopsForTripScreen(
          existingStops: _selectedStops,
        ),
      ),
    );

    setState(() {
      if (stops == null || stops.isEmpty) {
        _selectedStops.clear();
        _markers.removeWhere((marker) => marker.markerId.value.startsWith('stop'));
      } else {
        _selectedStops = stops;
        _updateStopMarkers();
      }
    });

    // 🔥 Llamar a _drawPolyline() para recalcular la ruta después de actualizar las paradas
    _drawPolyline();
  }

  Future<void> _selectDateTime() async {
    DateTime now = DateTime.now();
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)), // Permite programar hasta un año adelante
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _scheduledDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }

  void _updateStopMarkers() {
    setState(() {
      // Eliminar marcadores de paradas previos
      _markers.removeWhere((marker) => marker.markerId.value.startsWith('stop'));

      // Solo agregar marcadores si existen paradas
      if (_selectedStops.isNotEmpty) {
        for (int i = 0; i < _selectedStops.length; i++) {
          final stop = _selectedStops[i];
          final latLng = LatLng(stop['latitude'], stop['longitude']);

          _markers.add(Marker(
            markerId: MarkerId('stop${i + 1}'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
        }
      }

      // 🔥 Redibujar la ruta después de actualizar los marcadores
      _drawPolyline();
    });
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

    String waypoints = _selectedStops.isNotEmpty
        ? "&waypoints=" + _selectedStops.map((stop) => "${stop['latitude']},${stop['longitude']}").join('|')
        : "";

    String url =
        '$proxyBaseUrl/directions/json?origin=${_pickupLocation!.latitude},${_pickupLocation!.longitude}'
        '$waypoints'
        '&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        List<PointLatLng> points = polylinePoints
            .decodePolyline(data['routes'][0]['overview_polyline']['points']);

        int totalDistance = 0;
        int totalDuration = 0;

        // 🔹 Sumar todas las distancias y tiempos de cada tramo
        for (var leg in data['routes'][0]['legs']) {
          totalDistance += (leg['distance']['value'] as num).toInt(); // distancia en metros
          totalDuration += (leg['duration']['value'] as num).toInt(); // duración en segundos
        }

        // Convertir metros a kilómetros y segundos a minutos
        double distanceKm = totalDistance / 1000.0;
        int durationMinutes = (totalDuration / 60).round();

        final arrivalTime = DateTime.now().add(Duration(seconds: totalDuration));
        final arrivalTimeText =
            "${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}";

        setState(() {
          _polylineCoordinates.clear();
          for (var point in points) {
            _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }

          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: _polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));

          // 🔥 Mostrar la distancia y duración total del viaje
          _distanceText = "${distanceKm.toStringAsFixed(1)} km";
          _durationText = "$durationMinutes min";
          _arrivalTimeText = arrivalTimeText;
        });

        _adjustCameraToRoute();

      } else {
        print("Error en la respuesta de la API: ${data['status']}");
      }
    } else {
      print("Error en la solicitud: ${response.statusCode}");
    }
  }

  Future<void> _sendTripRequest() async {
    if (selectedUserId == null || _pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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

    // 🔹 Generar las paradas en el formato adecuado con campos numerados
    Map<String, dynamic> stopsData = {};

    if (_selectedStops.isNotEmpty) {
      for (int i = 0; i < _selectedStops.length; i++) {
        stopsData['stop${i + 1}'] = {
          'latitude': _selectedStops[i]['latitude'],
          'longitude': _selectedStops[i]['longitude'],
          'placeName': _selectedStops[i]['placeName'],
        };
      }
    }

    // 🔥 Crear la solicitud de viaje con las paradas incluidas
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
      ...stopsData, // ✅ Incluir paradas correctamente formateadas
      'passengers': passengers,
      'luggage': luggage,
      'pets': pets,
      'babySeats': babySeats,
      'status': _scheduledDateTime != null ? 'scheduled' : 'pending',
      'created_at': DateTime.now().toIso8601String(),
      if (_scheduledDateTime != null)
        'scheduled_at': _scheduledDateTime!.toIso8601String(),
      'emergency': false,
      if (fcmToken != null) 'fcmToken': fcmToken, // ✅ Añadir fcmToken solo si existe
      if (_needSecondDriver) 'need_second_driver': true,
    };

    // Guardar en Firebase Realtime Database
    databaseRef.push().set(tripData).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solicitud de viaje creada exitosamente.'),
      ));
      _resetForm();

    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al enviar la solicitud: $error'),
      ));
    });
  }

  void _adjustCameraToRoute() async {
    if (_polylineCoordinates.isEmpty) return;

    final GoogleMapController controller = await _mapController.future;

    double minLat = _polylineCoordinates.first.latitude;
    double maxLat = _polylineCoordinates.first.latitude;
    double minLng = _polylineCoordinates.first.longitude;
    double maxLng = _polylineCoordinates.first.longitude;

    for (LatLng coord in _polylineCoordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
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
      _scheduledDateTime = null;
      _needSecondDriver = false;
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
                      userPhone = userDoc.data()?['NumeroTelefono'] ?? "No disponible";
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
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
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
              if (_selectedStops.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paradas:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ..._selectedStops.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final stop = entry.value;
                      return ListTile(
                        leading: Text('#$index'),
                        title: Text(stop['placeName']),
                        subtitle: Text('Lat: ${stop['latitude']}, Lng: ${stop['longitude']}'),
                      );
                    }).toList(),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendTripRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Crear Solicitud de Viaje',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _navigateToStopsScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Añadir Paradas',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectDateTime,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Programar Viaje',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('¿Requiere conductor adicional?'),
                              content: const Text('¿Deseas asignar un conductor adicional para este viaje?'),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Sí'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            setState(() {
                              _needSecondDriver = true;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Se solicitará conductor adicional para este viaje.'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _needSecondDriver ? Colors.red : Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Conductor Adicional',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    ),
                  ],
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