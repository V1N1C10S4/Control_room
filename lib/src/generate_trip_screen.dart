import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  static const String googleApiKey = 'AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

  List<Map<String, dynamic>> _pickupPredictions = [];
  List<Map<String, dynamic>> _destinationPredictions = [];

  @override
  void initState() {
    super.initState();
    _loadUsersFromFirestore();
  }

  Future<void> _loadUsersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('Usuarios').get();
    setState(() {
      users = snapshot.docs;
    });
  }

  Future<List<Map<String, dynamic>>> _getPlacePredictions(String input) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleApiKey';
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
    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$googleApiKey';
    final response = await http.get(Uri.parse(url));
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
          _markers.add(Marker(markerId: MarkerId('pickup'), position: latLng));
        } else {
          _destinationLocation = latLng;
          _destinationAddress = data['result']['formatted_address'];
          _destinationController.text = _destinationAddress ?? '';
          _destinationPredictions = [];
          _markers.add(Marker(markerId: MarkerId('destination'), position: latLng));
        }
        _drawPolyline();
      });
    }
  }

  Future<void> _drawPolyline() async {
    if (_pickupLocation == null || _destinationLocation == null) return;

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_pickupLocation!.latitude},${_pickupLocation!.longitude}&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}&key=$googleApiKey';
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      List<PointLatLng> points =
          polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
      setState(() {
        _polylineCoordinates.clear();
        for (var point in points) {
          _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: _polylineCoordinates,
          color: Colors.blue,
          width: 5,
        ));
      });
    }
  }

  Future<void> _sendTripRequest() async {
    if (selectedUserId == null || _pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Seleccione el usuario, el punto de recogida y el destino.'),
      ));
      return;
    }

    final tripData = {
      'userId': selectedUserId,
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
    };

    FirebaseFirestore.instance.collection('trip_requests').add(tripData).then((_) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Viaje', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(107, 202, 186, 1),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedUserId,
                items: users
                    .map((user) => DropdownMenuItem(
                          value: user.id,
                          child: Text(user['NombreUsuario']),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedUserId = value;
                  });
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
        ListView.builder(
          shrinkWrap: true,
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