import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> users = [];
  String? selectedUserId;

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
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=YOUR_GOOGLE_MAPS_API_KEY';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    }
    return [];
  }

  Future<void> _selectPlace(String input, bool isPickup) async {
    final predictions = await _getPlacePredictions(input);

    if (predictions.isEmpty) {
      return;
    }

    // Mostrar diálogo con las sugerencias
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Seleccione una ubicación'),
        children: predictions.map((prediction) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              _getPlaceDetails(prediction['place_id'], isPickup);
            },
            child: Text(prediction['description']),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _getPlaceDetails(String placeId, bool isPickup) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=YOUR_GOOGLE_MAPS_API_KEY';
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
          _markers.add(Marker(markerId: MarkerId('pickup'), position: latLng));
        } else {
          _destinationLocation = latLng;
          _destinationAddress = data['result']['formatted_address'];
          _destinationController.text = _destinationAddress ?? '';
          _markers.add(Marker(markerId: MarkerId('destination'), position: latLng));
        }
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
      _markers.clear();
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
        title: const Text(
          'Generar Viaje',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(107, 202, 186, 1),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seleccione un Usuario',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                  hintText: 'Seleccione un usuario',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pickupController,
                decoration: InputDecoration(
                  labelText: 'Punto de Recogida',
                  hintText: 'Ingrese el punto de recogida',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final input = await showDialog<String>(
                    context: context,
                    builder: (_) => _AutocompleteDialog(),
                  );
                  if (input != null) {
                    await _selectPlace(input, true);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Destino',
                  hintText: 'Ingrese el destino',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final input = await showDialog<String>(
                    context: context,
                    builder: (_) => _AutocompleteDialog(),
                  );
                  if (input != null) {
                    await _selectPlace(input, false);
                  }
                },
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
                  onMapCreated: (GoogleMapController controller) {
                    _mapController.complete(controller);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        passengers = int.tryParse(value) ?? 1;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Pasajeros',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        luggage = int.tryParse(value) ?? 0;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Equipaje',
                        border: OutlineInputBorder(),
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
}

class _AutocompleteDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return AlertDialog(
      title: Text('Buscar Lugar'),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: 'Ingrese el lugar'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('Buscar'),
        ),
      ],
    );
  }
}