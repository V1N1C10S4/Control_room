import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RouteChangeReviewScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const RouteChangeReviewScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<RouteChangeReviewScreen> createState() => _RouteChangeReviewScreenState();
}

class _RouteChangeReviewScreenState extends State<RouteChangeReviewScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];
  bool _routeFetched = false;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> trip = Map<String, dynamic>.from(widget.trip);
    final routeRequest = trip['route_change_request'];
    if (routeRequest == null) {
      return const Scaffold(
        body: Center(child: Text("No hay solicitud de cambio de ruta.")),
      );
    }

    final pickup = routeRequest['pickup'];
    final destination = routeRequest['destination'];
    final dynamic rawStops = routeRequest['stops'];
    late final Map<String, dynamic> allStops;

    if (rawStops is Map) {
      allStops = Map<String, dynamic>.from(rawStops);
    } else if (rawStops is List) {
      allStops = {
        for (int i = 0; i < rawStops.length; i++)
          '$i': rawStops[i] ?? {},
      };
    } else {
      allStops = {};
    }
    final reason = routeRequest['reason'] ?? 'Sin motivo proporcionado';

    final originalPickup = trip['pickup'];
    final originalDestination = trip['destination'];
    final originalStops = trip['stops'] ?? [];

    final samePickup = _isSameLocation(originalPickup, pickup);
    final sameDestination = _isSameLocation(originalDestination, destination);
    final sameStops = _areStopsEqual(originalStops, allStops);

    final reachedIndexes = _extractReachedStopIndexes(trip);

    final filteredStops = <int, dynamic>{};

    allStops.forEach((key, value) {
      final keyStr = key.toString();
      if (RegExp(r'^\d+$').hasMatch(keyStr)) {
        final index = int.parse(keyStr);

        // Asegurar que value tenga datos válidos
        if (!reachedIndexes.contains(index) &&
            value is Map &&
            value['latitude'] != null &&
            value['longitude'] != null) {
          filteredStops[index] = value;
        }
      } else {
        print("Clave inválida en stops: $keyStr");
      }
    });

    final routePoints = _buildRoutePoints(
      pickup: pickup,
      destination: destination,
      filteredStops: filteredStops,
    );

    final routeMarkers = _buildRouteMarkers(
      pickup: pickup,
      destination: destination,
      filteredStops: filteredStops,
    );

    final pickupLatLng = LatLng(pickup['latitude'], pickup['longitude']);
    final destinationLatLng = LatLng(destination['latitude'], destination['longitude']);
    final stopLatLngs = filteredStops.entries
      .map((e) => LatLng(e.value['latitude'], e.value['longitude']))
      .toList();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_routeFetched) {
        _routeFetched = true;
        _fetchRouteWithStops(pickupLatLng, stopLatLngs, destinationLatLng);
      }
    });

    final isRoutePointsSafe = routePoints.every((p) {
      return !p.latitude.isNaN && !p.longitude.isNaN;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de cambio de ruta', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              '📝 Motivo: $reason',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            if (!samePickup)
              Text(
                '🚕 Nuevo punto de partida: ${pickup?['placeName'] ?? 'No disponible'}',
                style: const TextStyle(fontSize: 16),
              ),

            if (!sameStops && filteredStops.isNotEmpty)
              ...filteredStops.entries.map((e) {
                final placeName = e.value['placeName'] ?? 'Sin nombre';
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '🛑 Parada ${e.key + 1}: $placeName',
                    style: const TextStyle(fontSize: 16),
                    ),
                );
              }),

            if (!sameDestination)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '🏁 Nuevo destino: ${destination?['placeName'] ?? 'No disponible'}',
                  style: const TextStyle(fontSize: 16),
                  ),
              ),

            if (routePoints.length >= 2 && isRoutePointsSafe)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: routePoints.first,
                          zoom: 13,
                        ),
                        markers: routeMarkers,
                        polylines: _polylines,
                        zoomControlsEnabled: false,
                        myLocationEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitMapToRoute(routePoints);
                        },
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildLocationButtons(routePoints),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => _updateRouteStatus(context, trip['id'], 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Aprobar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _updateRouteStatus(context, trip['id'], 'rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Denegar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LatLng>> fetchPolylinePoints(LatLng origin, LatLng destination, List<LatLng> stops) async {
    final stopParams = stops.map((s) => '${s.latitude},${s.longitude}').join('|');

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&waypoints=$stopParams&key=AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final points = <LatLng>[];
      final steps = data['routes'][0]['legs'].expand((leg) => leg['steps']).toList();

      for (final step in steps) {
        final lat = step['end_location']['lat'];
        final lng = step['end_location']['lng'];
        points.add(LatLng(lat, lng));
      }

      return points;
    } else {
      throw Exception('Error al obtener ruta: ${response.body}');
    }
  }

  // ✅ Comparador de ubicación
  bool _isSameLocation(Map? a, Map? b) {
    if (a == null || b == null) return false;
    return a['latitude'] == b['latitude'] && a['longitude'] == b['longitude'];
  }

  // ✅ Comparador de stops
  bool _areStopsEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    // Normalizar ambos a listas ordenadas
    final List<Map<String, dynamic>> stopsA = _normalizeStops(a);
    final List<Map<String, dynamic>> stopsB = _normalizeStops(b);

    for (int i = 0; i < stopsA.length; i++) {
      if (!_isSameLocation(stopsA[i], stopsB[i])) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> _normalizeStops(dynamic rawStops) {
    if (rawStops is Map) {
      final entries = rawStops.entries.toList()
        ..sort((a, b) => int.parse(a.key.toString()).compareTo(int.parse(b.key.toString())));
      return entries.map((e) => Map<String, dynamic>.from(e.value)).toList();
    } else if (rawStops is List) {
      return rawStops.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  // ✅ Extrae los índices de paradas ya alcanzadas usando campos tipo stop_reached_1_at
  Set<int> _extractReachedStopIndexes(Map<String, dynamic> trip) {
    final reachedIndexes = <int>{};
    for (final key in trip.keys) {
      if (key.startsWith('stop_reached_') && key.endsWith('_at')) {
        final numStr = key.replaceAll('stop_reached_', '').replaceAll('_at', '');
        final index = int.tryParse(numStr);
        if (index != null) reachedIndexes.add(index);
      }
    }
    return reachedIndexes;
  }

  List<LatLng> _buildRoutePoints({
    required Map pickup,
    required Map? destination,
    required Map<int, dynamic> filteredStops,
  }) {
    final List<LatLng> points = [];

    // Agregar punto de partida
    if (pickup['latitude'] != null && pickup['longitude'] != null) {
      points.add(LatLng(pickup['latitude'], pickup['longitude']));
    }

    // Agregar paradas nuevas aún no visitadas
    final sortedStops = filteredStops.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key)); // Ordenar por índice

    for (final entry in sortedStops) {
      final stop = entry.value;
      final lat = stop['latitude'];
      final lng = stop['longitude'];

      if (lat is double && lng is double) {
        points.add(LatLng(lat, lng));
      } else {
        print('❌ Coordenadas inválidas en parada $entry');
      }
    }

    // Agregar destino (si existe y tiene coordenadas)
    if (destination != null &&
        destination['latitude'] != null &&
        destination['longitude'] != null) {
      points.add(LatLng(destination['latitude'], destination['longitude']));
    }

    return points;
  }

  Set<Marker> _buildRouteMarkers({
    required Map pickup,
    required Map? destination,
    required Map<int, dynamic> filteredStops,
  }) {
    final Set<Marker> markers = {};

    // 📍 Marker de inicio
    if (pickup['latitude'] != null && pickup['longitude'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(pickup['latitude'], pickup['longitude']),
        infoWindow: const InfoWindow(title: 'Inicio'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    // 🛑 Markers de paradas intermedias
    filteredStops.entries.forEach((entry) {
      final stop = entry.value;
      final index = entry.key;
      final lat = stop['latitude'];
      final lng = stop['longitude'];

      if (lat is double && lng is double) {
        markers.add(Marker(
          markerId: MarkerId('stop_$index'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: 'Parada ${index + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      } else {
        print('❌ Coordenadas inválidas para marcador de parada $index');
      }
    });

    // 🏁 Marker de destino
    if (destination != null &&
        destination['latitude'] != null &&
        destination['longitude'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(destination['latitude'], destination['longitude']),
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    return markers;
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    final bounds = _createLatLngBounds(points);

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  LatLngBounds _createLatLngBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _zoomTo(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, 16),
    );
  }

  Widget _buildLocationButtons(List<LatLng> routePoints) {
    if (routePoints.length < 2) return const SizedBox();

    return Container(
      height: 250,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FloatingActionButton(
                onPressed: () => _zoomTo(routePoints.first),
                mini: true,
                backgroundColor: Colors.red,
                child: const Text("1", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            for (int i = 1; i < routePoints.length - 1; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FloatingActionButton(
                  onPressed: () => _zoomTo(routePoints[i]),
                  mini: true,
                  backgroundColor: Colors.orange,
                  child: Text("${i + 1}", style: const TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FloatingActionButton(
                onPressed: () => _zoomTo(routePoints.last),
                mini: true,
                backgroundColor: Colors.red,
                child: Text("${routePoints.length}", style: const TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchPolylineSegment(LatLng start, LatLng end, String segmentId) async {
    const String proxyBaseUrl = "https://googleplacesproxy-3tomukm2tq-uc.a.run.app";
    const String apiKey = "AIzaSyAKW6JX-rpTCKFiEGJ3fLTg9lzM0GMHV4k";

    String url =
        '$proxyBaseUrl/directions/json?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        List<PointLatLng> points =
            PolylinePoints().decodePolyline(data['routes'][0]['overview_polyline']['points']);

        List<LatLng> segmentCoordinates = points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId(segmentId),
            color: Colors.blue,
            width: 5,
            points: segmentCoordinates,
          ));
          _polylineCoordinates.addAll(segmentCoordinates);
        });
      }
    }
  }

  Future<void> _fetchRouteWithStops(LatLng pickup, List<LatLng> stops, LatLng destination) async {
    _polylines.clear(); // Limpiar rutas previas

    LatLng prevPoint = pickup;

    for (int i = 0; i < stops.length; i++) {
      await _fetchPolylineSegment(prevPoint, stops[i], 'segment_$i');
      prevPoint = stops[i];
    }

    await _fetchPolylineSegment(prevPoint, destination, 'finalSegment');

  }

  void _updateRouteStatus(BuildContext context, String tripId, String newStatus) async {
    final ref = FirebaseDatabase.instance.ref().child('viajes_activos/$tripId/route_change_request');

    try {
      // 1. Actualizar el estado de la solicitud
      await ref.update({'status': newStatus});

      // 2. Solo si se aprueba, evaluar si se requiere retroceso de estado
      if (newStatus == 'approved') {
        final tripRef = FirebaseDatabase.instance.ref().child('viajes_activos/$tripId');
        final snapshot = await tripRef.get();
        if (snapshot.exists) {
          final tripData = Map<String, dynamic>.from(snapshot.value as Map);

          final currentStatus = tripData['status'];
          final pickedUpAt = tripData['picked_up_passenger_at'];
          final currentStops = tripData['stops'] as Map<dynamic, dynamic>? ?? {};

          final routeRequest = tripData['route_change_request'];
          final newStops = routeRequest?['stops'] as Map<dynamic, dynamic>? ?? {};
          final allStops = {...currentStops, ...newStops};
          final newStopIndex = allStops.length - 1; // Última parada agregada

          // Solo retroceder si ya recogió al pasajero
          if (pickedUpAt != null && currentStatus == 'picked up passenger') {
            final now = DateTime.now().toIso8601String();
            await tripRef.update({
              'status': 'on_stop_way_$newStopIndex',
              'on_stop_way_${newStopIndex}_at': now,
            });
          }
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Solicitud $newStatus exitosamente.'),
        backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al actualizar estado: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}