import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GenerateStopsForTripScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? existingStops;

  const GenerateStopsForTripScreen({Key? key, this.existingStops}) : super(key: key);

  @override
  _GenerateStopsForTripScreenState createState() => _GenerateStopsForTripScreenState();
}

class _GenerateStopsForTripScreenState extends State<GenerateStopsForTripScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final List<TextEditingController> _stopControllers = [];
  final List<LatLng> _stopLocationsTemp = []; // Solo almacenamiento temporal
  final List<String> _stopAddressesTemp = [];
  final List<Map<String, dynamic>> _tempStopsData = [];
  final Set<Marker> _markers = {};

  static const String proxyBaseUrl = "https://34.120.209.209.nip.io/militripproxy";
  List<List<Map<String, dynamic>>> _stopPredictions = [];

  @override
  void initState() {
    super.initState();
    _initializeStops();
  }

  Future<void> _zoomToMarker(int index) async {
    if (index < _stopLocationsTemp.length) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_stopLocationsTemp[index], 16),
      );
    }
  }

  void _initializeStops() {
    if (widget.existingStops != null && widget.existingStops!.isNotEmpty) {
      for (var stop in widget.existingStops!) {
        final latLng = LatLng(stop['latitude'], stop['longitude']);
        _stopLocationsTemp.add(latLng);
        _stopAddressesTemp.add(stop['placeName'] ?? "Ubicación desconocida");

        _stopControllers.add(TextEditingController(text: stop['placeName'] ?? ''));
        _stopPredictions.add([]);

        _markers.add(Marker(
          markerId: MarkerId('stop${_stopLocationsTemp.length}'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));

        _tempStopsData.add({
          'latitude': latLng.latitude,
          'longitude': latLng.longitude,
          'placeName': stop['placeName'] ?? '',
        });
      }
    }
    // Agregar la primera barra de búsqueda si no hay paradas existentes
    if (_stopControllers.isEmpty) {
      _addNewStopField();
    }
  }

  void _addNewStopField() {
    setState(() {
      _stopControllers.add(TextEditingController());
      _stopPredictions.add([]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Paradas', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stopControllers.length,
                    itemBuilder: (context, index) {
                      return _buildStopField(index);
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 250,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(19.432608, -99.133209),
                  zoom: 12,
                ),
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _mapController.complete(controller);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _tempStopsData);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Guardar Paradas', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _stopLocationsTemp.clear();
                    _stopAddressesTemp.clear();
                    _markers.clear();

                    // Guardar solo cuando el usuario lo confirme
                    for (var stop in _tempStopsData) {
                      final latLng = LatLng(stop['latitude'], stop['longitude']);
                      _stopLocationsTemp.add(latLng);
                      _stopAddressesTemp.add(stop['placeName']);

                      _markers.add(Marker(
                        markerId: MarkerId('stop${_stopLocationsTemp.length}'),
                        position: latLng,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ));
                    }
                  });

                  // Cerrar pantalla y enviar datos a GenerateTripScreen
                  Navigator.pop(context, _tempStopsData);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Eliminar Paradas', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStopField(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stopControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Parada ${index + 1}',
                    border: OutlineInputBorder(),
                    suffixIcon: _stopControllers[index].text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _clearStopField(index),
                          )
                        : null,
                  ),
                  onChanged: (input) => _onStopSearchChanged(input, index),
                ),
              ),
              const SizedBox(width: 8),
              if (index < _tempStopsData.length)
                ElevatedButton(
                  onPressed: () => _zoomToMarker(index),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
          if (_stopPredictions[index].isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ListView.builder(
                itemCount: _stopPredictions[index].length,
                itemBuilder: (context, predIndex) {
                  final prediction = _stopPredictions[index][predIndex];
                  return ListTile(
                    title: Text(prediction['description']),
                    onTap: () {
                      _getStopDetails(prediction['place_id'], index);
                      setState(() {
                        _stopPredictions[index] = [];
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _clearStopField(int index) {
    setState(() {
      _stopControllers[index].clear();
      _stopPredictions[index] = [];
    });
  }

  void _onStopSearchChanged(String input, int index) async {
    if (input.isNotEmpty) {
      final predictions = await _getPlacePredictions(input);
      setState(() {
        _stopPredictions[index] = predictions;
      });
    } else {
      setState(() {
        _stopPredictions[index] = [];
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getPlacePredictions(String input) async {
    String url = '$proxyBaseUrl/place/autocomplete/json?input=$input&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    }
    return [];
  }

  Future<void> _getStopDetails(String placeId, int index) async {
    String url = '$proxyBaseUrl/place/details/json?place_id=$placeId&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          final address = data['result']['formatted_address'];

          setState(() {
            _stopControllers[index].text = address;
            _stopPredictions[index] = [];
            
            // Solo se guardan temporalmente
            if (index >= _tempStopsData.length) {
              _tempStopsData.add({
                'latitude': latLng.latitude,
                'longitude': latLng.longitude,
                'placeName': address,
              });
            } else {
              _tempStopsData[index] = {
                'latitude': latLng.latitude,
                'longitude': latLng.longitude,
                'placeName': address,
              };
            }

            // Agregar un nuevo campo si estamos en la última barra
            if (index == _stopControllers.length - 1) {
              _addNewStopField();
            }
          });
        }
      }
    } catch (e) {
      print("Error al obtener detalles del lugar: $e");
    }
  }
}