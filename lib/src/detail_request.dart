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
  List<LatLng> _stops = []; 

  // URL base del proxy para consultas a la API de Google
  static const String proxyBaseUrl = "https://us-central1-appenitaxiusuarios.cloudfunctions.net/googlePlacesProxy";

  @override
  void initState() {
    super.initState();
    _setupTripData();
  }

  Future<void> _setupTripData() async {
    await _extractStopsFromTripRequest(); // ✅ Esperar a que se carguen las paradas
    _initializeMap(); // ✅ Ahora sí inicializamos el mapa con los datos completos
  }

  void _initializeMap() async {
    LatLng? pickupCoordinates;
    LatLng? destinationCoordinates;

    try {
      pickupCoordinates = await _getCoordinatesFromAddress(widget.tripRequest['pickup']);
      destinationCoordinates = await _getCoordinatesFromAddress(widget.tripRequest['destination']);
    } catch (e) {
      _logger.e("Error obteniendo coordenadas: $e");
      return;
    }

    if (pickupCoordinates == null || destinationCoordinates == null) {
      _logger.e("Error: No se pudo obtener las coordenadas de recogida o destino.");
      return;
    }

    if (!mounted) return; // 🔥 Evitar modificar estado si el widget ya no está en pantalla

    setState(() {
      _addMarkers(pickupCoordinates!, destinationCoordinates!);
      if (_stops.isNotEmpty) {
        _addStopMarkers(_stops);
      }
    });

    _fetchRouteWithStops(pickupCoordinates, _stops, destinationCoordinates);
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

  Future<void> _extractStopsFromTripRequest() async {
    List<LatLng> stops = [];

    if (widget.tripRequest.containsKey('stop') && widget.tripRequest['stop'] != null) {
      var stopData = widget.tripRequest['stop'];
      if (stopData is Map && stopData.containsKey('latitude') && stopData.containsKey('longitude')) {
        stops.add(LatLng(
          stopData['latitude'] ?? 0.0,
          stopData['longitude'] ?? 0.0,
        ));
      }
    }

    for (int i = 1; i <= 10; i++) {
      String stopKey = 'stop$i';
      if (widget.tripRequest.containsKey(stopKey) && widget.tripRequest[stopKey] != null) {
        var stopData = widget.tripRequest[stopKey];

        if (stopData is Map && stopData.containsKey('latitude') && stopData.containsKey('longitude')) {
          stops.add(LatLng(
            stopData['latitude'] ?? 0.0,
            stopData['longitude'] ?? 0.0,
          ));
        }
      }
    }

    if (!mounted) return; // ✅ Evitar errores si el widget fue destruido

    setState(() {
      _stops = stops;
    });

    _logger.d("Paradas extraídas: $_stops");
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

      _addStopMarkers(_stops);

      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    });
  }

  void _addStopMarkers(List<LatLng> stops) {
    if (stops.isEmpty) return; // ✅ Evita errores si no hay paradas

    for (int i = 0; i < stops.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('stop${i + 1}'),
          position: stops[i],
          infoWindow: InfoWindow(title: 'Parada ${i + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
      );
    }
  }

  Future<void> _fetchRouteWithStops(LatLng pickup, List<LatLng> stops, LatLng destination) async {
    _polylines.clear(); // Limpiar rutas previas

    // Trazar ruta desde pickup hasta la primera parada
    LatLng prevPoint = pickup;
    for (int i = 0; i < stops.length; i++) {
      await _fetchPolylineSegment(prevPoint, stops[i], 'segment$i');
      prevPoint = stops[i];
    }

    // Trazar ruta desde la última parada hasta el destino
    await _fetchPolylineSegment(prevPoint, destination, 'finalSegment');
  }

  Future<void> _fetchPolylineSegment(LatLng start, LatLng end, String segmentId) async {
    String url =
        '$proxyBaseUrl/directions/json?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        List<PointLatLng> points =
            PolylinePoints().decodePolyline(data['routes'][0]['overview_polyline']['points']);

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId(segmentId),
            color: Colors.blue,
            width: 5,
            points: points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
          ));
        });
      }
    }
  }

  Widget _buildLocationButtons() {
    return Container(
      height: 250, // ✅ Definir altura para evitar que ocupe toda la pantalla
      child: SingleChildScrollView(
        child: Column(
          children: [
            FloatingActionButton(
              onPressed: _zoomToPickup,
              mini: true,
              backgroundColor: Colors.red,
              child: const Text("1", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            if (_stops.isNotEmpty) // ✅ Si hay paradas, muestra los botones
              for (int i = 0; i < _stops.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FloatingActionButton(
                    onPressed: () => _zoomToStop(i),
                    mini: true,
                    backgroundColor: Colors.orange,
                    child: Text("${i + 2}", style: const TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                )
            else
              const SizedBox(height: 48), // ✅ Espacio reservado cuando NO hay paradas
            FloatingActionButton(
              onPressed: _zoomToDestination,
              mini: true,
              backgroundColor: Colors.red,
              child: Text("${_stops.isNotEmpty ? _stops.length + 2 : 2}", // ✅ Ajusta el número del botón de destino
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _zoomToStop(int index) async {
    final GoogleMapController controller = await _mapController.future;
    final LatLng stop = _stops[index]; // ✅ Asegurar que stop es de tipo LatLng

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(stop.latitude, stop.longitude), // ✅ Usar las propiedades correctas
          zoom: 18,
        ),
      ),
    );
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
          children: [
            // 🔹 Se añadió un Expanded con scroll para la información textual
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasajero: ${widget.tripRequest['userId']}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nombre del pasajero: ${widget.tripRequest['userName']}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Punto de partida: ${widget.tripRequest['pickup']}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    if (_stops.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_stops.length, (index) {
                          // 🔹 Primera parada puede ser "stop" o "stop1"
                          String stopKey = (index == 0 && widget.tripRequest.containsKey('stop'))
                              ? 'stop'
                              : 'stop${index + 1}';

                          var stopData = widget.tripRequest[stopKey];

                          return stopData != null && stopData is Map && stopData.containsKey('placeName')
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Parada ${index + 1}: ${stopData['placeName']}',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                )
                              : const SizedBox();
                        }),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Destino: ${widget.tripRequest['destination']}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estatus: ${widget.tripRequest['status']}',
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
                  ],
                ),
              ),
            ),

            // 🔹 Mapa y botones fijos
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
                    zoomControlsEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController.complete(controller);
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildLocationButtons(), // 🔹 Botones de ubicación dinámicos
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 Botones de acción siguen fijos en la parte inferior
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(context, 'autorizar');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
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