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

class DetailRequestScreen extends StatelessWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor;
  final String region;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  DetailRequestScreen({
    super.key,
    required this.tripRequest,
    required this.isSupervisor,
    required this.region,
  });

  final Logger _logger = Logger();
  final Completer<GoogleMapController> _mapController = Completer();

  // URL base del proxy para consultas a la API de Google
  static const String proxyBaseUrl = "https://34.120.209.209.nip.io/militripproxy";

  void _updateTripStatus(BuildContext context, String newStatus) {
    final DatabaseReference tripRequestRef = FirebaseDatabase.instance
        .ref()
        .child('trip_requests')
        .child(tripRequest['id']);

    tripRequestRef.update({
      'status': newStatus,
    }).then((_) {
      if (newStatus == 'authorized') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SelectDriverScreen(
              tripRequest: tripRequest,
              isSupervisor: isSupervisor,
              region: region,
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

  // Método para obtener coordenadas usando el proxy
  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final String url =
        '$proxyBaseUrl/geocode/json?address=${Uri.encodeComponent(address)}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['results'][0]['geometry']['location'];
          final double latitude = location['lat'];
          final double longitude = location['lng'];
          return LatLng(latitude, longitude);
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
    // Construir la URL completa usando el proxy
    final String url =
        '$proxyBaseUrl/directions/json?origin=${pickupCoordinates.latitude},${pickupCoordinates.longitude}&destination=${destinationCoordinates.latitude},${destinationCoordinates.longitude}&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Extraer los puntos del polyline
          List<PointLatLng> points = PolylinePoints()
              .decodePolyline(data['routes'][0]['overview_polyline']['points']);

          final List<LatLng> polylineCoordinates =
              points.map((point) => LatLng(point.latitude, point.longitude)).toList();

          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));

          _logger.i('Ruta trazada exitosamente');
        } else {
          throw Exception('Error de Directions API: ${data['status']}');
        }
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        _getCoordinatesFromAddress(tripRequest['pickup']),
        _getCoordinatesFromAddress(tripRequest['destination']),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
            ),
          );
        }

        final coordinates = snapshot.data as List<LatLng?>;
        final LatLng? pickupCoordinates = coordinates[0];
        final LatLng? destinationCoordinates = coordinates[1];

        // Inserta este bloque aquí
        if (pickupCoordinates != null && destinationCoordinates != null) {
          // Agregar marcadores
          _addMarkers(pickupCoordinates, destinationCoordinates);

          // Dibujar la ruta
          _drawPolyline(pickupCoordinates, destinationCoordinates);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Solicitud #${tripRequest['id']}',
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
                  'Usuario: ${tripRequest['userId']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nombre del usuario: ${tripRequest['userName']}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pickup: ${tripRequest['pickup']}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  'Destination: ${tripRequest['destination']}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status: ${tripRequest['status']}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  'Número de pasajeros: ${tripRequest['passengers'] ?? 'No especificado'}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cantidad de equipaje: ${tripRequest['luggage'] ?? 'No especificado'}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Número de mascotas: ${tripRequest['pets'] ?? 'No especificado'}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Número de sillas para bebés: ${tripRequest['babySeats'] ?? 'No especificado'}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 250,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(19.432608, -99.133209), // Ciudad de México
                      zoom: 12,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    zoomControlsEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController.complete(controller);
                    },
                  )
                ),
                const SizedBox(height: 32),
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
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
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
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
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
      },
    );
  }
}