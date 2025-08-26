import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteChangeControlRoomScreen extends StatefulWidget {
  final Map trip;
  const RouteChangeControlRoomScreen({super.key, required this.trip});

  @override
  State<RouteChangeControlRoomScreen> createState() => _RouteChangeControlRoomScreenState();
}

class _RouteChangeControlRoomScreenState extends State<RouteChangeControlRoomScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final List<TextEditingController> _stopControllers = [];
  final List<Map<String, dynamic>> _stops = [];
  Map<String, dynamic>? _newPickup;
  Map<String, dynamic>? _newDestination;
  bool _isSending = false;
  static const String proxyBaseUrl = "https://googleplacesproxy-3tomukm2tq-uc.a.run.app";

  List<Map<String, dynamic>> _pickupPredictions = [];
  List<Map<String, dynamic>> _destinationPredictions = [];
  List<List<Map<String, dynamic>>> _stopPredictions = [];
  late bool allowPickupEdit;

  @override
  void initState() {
    super.initState();
    allowPickupEdit = widget.trip['status'] == 'started' || widget.trip['status'] == 'passenger reached';
    _initializeTripData();
  }

  void _initializeTripData() {
    final pickup = Map<String, dynamic>.from(widget.trip['pickup']);
    final destination = Map<String, dynamic>.from(widget.trip['destination']);

    _pickupController.text = pickup['placeName'] ?? 'Pickup';
    _destinationController.text = destination['placeName'] ?? 'Destination';

    for (int i = 1; i <= 5; i++) {
      if (widget.trip.containsKey('stop$i')) {
        final stop = Map<String, dynamic>.from(widget.trip['stop$i']);
        _stopControllers.add(TextEditingController(text: stop['placeName'] ?? 'Stop'));
        _stops.add(stop);
        _stopPredictions.add([]);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getPlacePredictions(String input) async {
    final url = '$proxyBaseUrl/place/autocomplete/json?input=$input&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    }
    return [];
  }

  void _onSearchChanged(String input, String locationType, {int? stopIndex}) async {
    if (input.isEmpty) {
      setState(() {
        if (locationType == 'pickup') _pickupPredictions = [];
        else if (locationType == 'destination') _destinationPredictions = [];
        else if (stopIndex != null) _stopPredictions[stopIndex] = [];
      });
      return;
    }

    final predictions = await _getPlacePredictions(input);
    setState(() {
      if (locationType == 'pickup') _pickupPredictions = predictions;
      else if (locationType == 'destination') _destinationPredictions = predictions;
      else if (stopIndex != null) _stopPredictions[stopIndex] = predictions;
    });
  }

  Future<void> _getPlaceDetails(String placeId, String description, String locationType, {int? stopIndex}) async {
    final url = '$proxyBaseUrl/place/details/json?place_id=$placeId&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['result']['geometry']['location'];
        final latLng = LatLng(location['lat'], location['lng']);

        setState(() {
          if (locationType == 'pickup') {
            _newPickup = {'latitude': latLng.latitude, 'longitude': latLng.longitude, 'placeName': description};
            _pickupController.text = description;
            _pickupPredictions = [];
          } else if (locationType == 'destination') {
            _newDestination = {'latitude': latLng.latitude, 'longitude': latLng.longitude, 'placeName': description};
            _destinationController.text = description;
            _destinationPredictions = [];
          } else if (stopIndex != null) {
            _stopControllers[stopIndex].text = description;
            _stops[stopIndex] = {'latitude': latLng.latitude, 'longitude': latLng.longitude, 'placeName': description};
            _stopPredictions[stopIndex] = [];
          }
        });
      }
    }
  }

  void _addEmptyStop() {
    setState(() {
      _stopControllers.add(TextEditingController());
      _stops.add({'latitude': 0.0, 'longitude': 0.0, 'placeName': ''});
      _stopPredictions.add([]);
    });
  }

  Widget _buildLocationSearchField({
    required TextEditingController controller,
    required String label,
    required String locationType,
    required List<Map<String, dynamic>> predictions,
    int? stopIndex,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (value) => _onSearchChanged(value, locationType, stopIndex: stopIndex),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        if (predictions.isNotEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                return ListTile(
                  title: Text(prediction['description']),
                  onTap: () => _getPlaceDetails(
                    prediction['place_id'],
                    prediction['description'],
                    locationType,
                    stopIndex: stopIndex,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  bool _shouldShowStopTile(int stopIndex) {
    final currentStatus = widget.trip['status'] ?? '';
    return !currentStatus.startsWith('stop_reached_${stopIndex + 1}');
  }

  void _submitRequest() async {
    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for the route change.')),
      );
      return;
    }

    if ((_newPickup == null && widget.trip['pickup'] == null) ||
        (_newDestination == null && widget.trip['destination'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes especificar tanto el punto de recogida como el destino.')),
      );
      return;
    }

    setState(() => _isSending = true);

    final tripRef = FirebaseDatabase.instance.ref('trip_requests/${widget.trip['id']}');

    final requestData = {
      'reason': reason,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
      'pickup': _newPickup ?? Map<String, dynamic>.from(widget.trip['pickup']),
      'destination': _newDestination ?? Map<String, dynamic>.from(widget.trip['destination']),
      'stops': Map.fromEntries(
        _stops.asMap().entries.map((entry) {
          final index = entry.key + 1; // Comenzar en 1
          final stop = entry.value;
          return MapEntry(
            index.toString(),
            {
              'latitude': stop['latitude'],
              'longitude': stop['longitude'],
              'placeName': stop['placeName'],
            },
          );
        }),
      ),
    };

    try {
      await tripRef.child('route_change_request').set(requestData);

      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route change request sent successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar cambio de ruta', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (allowPickupEdit) ...[
                _buildLocationSearchField(
                  controller: _pickupController,
                  label: 'Punto de recogida',
                  locationType: 'pickup',
                  predictions: _pickupPredictions,
                ),
              ],
              const SizedBox(height: 10),
              ..._stopControllers.asMap().entries.map((entry) {
                final i = entry.key;
                final controller = entry.value;

                if (!_shouldShowStopTile(i)) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildLocationSearchField(
                          controller: controller,
                          label: 'Parada ${i + 1}',
                          locationType: 'stop',
                          predictions: _stopPredictions[i],
                          stopIndex: i,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _stopControllers.removeAt(i);
                            _stops.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              _buildLocationSearchField(
                controller: _destinationController,
                label: 'Destino',
                locationType: 'destination',
                predictions: _destinationPredictions,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Motivo del cambio de ruta',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addEmptyStop,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Añadir parada', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _submitRequest,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Enviar solicitud', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
