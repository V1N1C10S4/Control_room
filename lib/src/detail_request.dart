import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Importar Fluttertoast
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http; // Para solicitudes HTTP
import 'dart:convert'; // Para decodificar respuestas JSON
import 'select_driver_screen.dart';
import 'dart:async';

class DetailRequestScreen extends StatefulWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor;
  final String region;

  const DetailRequestScreen({
    Key? key,
    required this.tripRequest,
    required this.isSupervisor,
    required this.region,
  }) : super(key: key);

  @override
  _DetailRequestScreenState createState() => _DetailRequestScreenState();
}

class _DetailRequestScreenState extends State<DetailRequestScreen> {
  final Logger _logger = Logger();
  final Completer<GoogleMapController> _mapController = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // URL base del proxy para consultas a la API de Google
  static const String proxyBaseUrl = "https://34.120.209.209.nip.io/militripproxy";

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() async {
    final pickupCoordinates = await _getCoordinatesFromAddress(widget.tripRequest['pickup']);
    final destinationCoordinates = await _getCoordinatesFromAddress(widget.tripRequest['destination']);

    if (pickupCoordinates != null && destinationCoordinates != null) {
      _addMarkers(pickupCoordinates, destinationCoordinates);
      _drawPolyline(pickupCoordinates, destinationCoordinates);
    }
  }

  void _updateTripStatus(BuildContext context, String newStatus) {
    final DatabaseReference tripRequestRef = FirebaseDatabase.instance
        .ref()
        .child('trip_requests')
        .child(widget.tripRequest['id']);

    tripRequestRef.update({
      'status': newStatus,
    }).then((_) {
      if (newStatus == 'authorized') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectDriverScreen(
              tripRequest: widget.tripRequest,
              isSupervisor: widget.isSupervisor,
              region: widget.region,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }).catchError((error) {
      _logger.e('Error updating trip status: $error');
    });
  }

  void _showConfirmationDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('¿Seguro que quieres $action este viaje?'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('No', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateTripStatus(context, action == 'autorizar' ? 'authorized' : 'denied');
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Sí', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final String url =
        '$proxyBaseUrl/geocode/json?address=${Uri.encodeComponent(address)}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error getting coordinates for address "$address": $e');
      Fluttertoast.showToast(
        msg: 'Error obteniendo coordenadas: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.0,
      );
      return null;
    }
  }

  Future<void> _drawPolyline(LatLng pickupCoordinates, LatLng destinationCoordinates) async {
    final String url =
        '$proxyBaseUrl/directions/json?origin=${pickupCoordinates.latitude},${pickupCoordinates.longitude}&destination=${destinationCoordinates.latitude},${destinationCoordinates.longitude}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          List<PointLatLng> points = PolylinePoints()
              .decodePolyline(data['routes'][0]['overview_polyline']['points']);

          setState(() {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
              color: Colors.blue,
              width: 5,
            ));
          });
        } else {
          throw Exception('Directions API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error al trazar la ruta: $e');
      Fluttertoast.showToast(
        msg: 'Error al trazar la ruta: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }

  void _addMarkers(LatLng pickup, LatLng destination) {
    setState(() {
      _markers.clear();

      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        infoWindow: const InfoWindow(title: 'Punto de Recogida'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));

      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    });
  }

  Future<void> _zoomToBothMarkers() async {
    final GoogleMapController controller = await _mapController.future;

    if (_markers.length >= 2) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _markers.first.position.latitude < _markers.last.position.latitude
              ? _markers.first.position.latitude
              : _markers.last.position.latitude,
          _markers.first.position.longitude < _markers.last.position.longitude
              ? _markers.first.position.longitude
              : _markers.last.position.longitude,
        ),
        northeast: LatLng(
          _markers.first.position.latitude > _markers.last.position.latitude
              ? _markers.first.position.latitude
              : _markers.last.position.latitude,
          _markers.first.position.longitude > _markers.last.position.longitude
              ? _markers.first.position.longitude
              : _markers.last.position.longitude,
        ),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  Future<void> _zoomToPickup() async {
    final GoogleMapController controller = await _mapController.future;
    try {
      Marker pickupMarker = _markers.firstWhere(
        (marker) => marker.markerId.value == 'pickup',
      );

      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pickupMarker.position,
            zoom: 18, // Zoom profundo
          ),
        ),
      );
    } catch (e) {
      _logger.e("Pickup marker not found: $e");
      Fluttertoast.showToast(
        msg: "Error: Pickup marker not found",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _zoomToDestination() async {
    final GoogleMapController controller = await _mapController.future;
    try {
      Marker destinationMarker = _markers.firstWhere(
        (marker) => marker.markerId.value == 'destination',
      );

      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: destinationMarker.position,
            zoom: 18, // Zoom profundo
          ),
        ),
      );
    } catch (e) {
      _logger.e("Destination marker not found: $e");
      Fluttertoast.showToast(
        msg: "Error: Destination marker not found",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Solicitud #${widget.tripRequest['id']}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuario: ${widget.tripRequest['userId']}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Nombre del usuario: ${widget.tripRequest['userName']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Pickup: ${widget.tripRequest['pickup']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Destination: ${widget.tripRequest['destination']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${widget.tripRequest['status']}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              'Número de pasajeros: ${widget.tripRequest['passengers'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Cantidad de equipaje: ${widget.tripRequest['luggage'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Número de mascotas: ${widget.tripRequest['pets'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Número de sillas para bebés: ${widget.tripRequest['babySeats'] ?? 'No especificado'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 32),

            // Google Map con controles y leyenda
            Stack(
              children: [
                SizedBox(
                  height: 280,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(19.432608, -99.133209),
                      zoom: 12,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: false, // Deshabilitar controles predeterminados
                    onMapCreated: (GoogleMapController controller) {
                      _mapController.complete(controller);
                    },
                  ),
                ),

                // Leyenda de los colores
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('Punto de partida'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Destino'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Botones de control de mapa
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        onPressed: _zoomToBothMarkers,
                        mini: true,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.fit_screen, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        onPressed: _zoomToPickup,
                        mini: true,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Colors.green),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        onPressed: _zoomToDestination,
                        mini: true,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(context, 'autorizar');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                  ),
                  child: const Text(
                    'Autorizar viaje',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(context, 'denegar');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                  ),
                  child: const Text(
                    'Denegar viaje',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}