import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteChangeReviewScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const RouteChangeReviewScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<RouteChangeReviewScreen> createState() => _RouteChangeReviewScreenState();
}

class _RouteChangeReviewScreenState extends State<RouteChangeReviewScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final routeRequest = trip['route_change_request'];
    if (routeRequest == null) {
      return const Scaffold(
        body: Center(child: Text("No hay solicitud de cambio de ruta.")),
      );
    }

    final pickup = routeRequest['pickup'];
    final destination = routeRequest['destination'];
    final allStops = routeRequest['stops'] ?? {};
    final reason = routeRequest['reason'] ?? 'Sin motivo proporcionado';

    final originalPickup = trip['pickup'];
    final originalDestination = trip['destination'];
    final originalStops = trip['stops'] ?? [];

    final samePickup = _isSameLocation(originalPickup, pickup);
    final sameDestination = _isSameLocation(originalDestination, destination);
    final sameStops = _areStopsEqual(originalStops, allStops);

    final reachedIndexes = _extractReachedStopIndexes(trip);

    final filteredStops = <int, dynamic>{};
    if (allStops is Map) {
      allStops.forEach((key, value) {
        final index = int.tryParse(key);
        if (index != null && !reachedIndexes.contains(index)) {
          filteredStops[index] = value;
        }
      });
    }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de Cambio de Ruta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 Solicitud de Cambio de Ruta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('📝 Motivo: $reason'),
            const SizedBox(height: 16),

            if (!samePickup)
              Text('🚕 Nuevo punto de partida: ${pickup?['placeName'] ?? 'No disponible'}'),

            if (!sameStops && filteredStops.isNotEmpty)
              ...filteredStops.entries.map((e) {
                final placeName = e.value['placeName'] ?? 'Sin nombre';
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('🛑 Parada ${e.key + 1}: $placeName'),
                );
              }),

            if (!sameDestination)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('🏁 Nuevo destino: ${destination?['placeName'] ?? 'No disponible'}'),
              ),

//            if (routePoints.length >= 2)
//              Padding(
//                padding: const EdgeInsets.symmetric(vertical: 16.0),
//                child: SizedBox(
//                  height: 280,
//                  child: Stack(
//                    children: [
//                      GoogleMap(
//                        initialCameraPosition: CameraPosition(
//                          target: routePoints.first,
//                          zoom: 13,
//                        ),
//                        markers: routeMarkers,
//                        polylines: {
//                          Polyline(
//                            polylineId: const PolylineId('route'),
//                            points: routePoints,
//                            color: Colors.blue,
//                            width: 4,
//                          ),
//                        },
//                        zoomControlsEnabled: false,
//                        myLocationEnabled: false,
//                        onMapCreated: (controller) {
//                          _mapController = controller;
//                          _fitMapToRoute(routePoints);
//                        },
//                      ),
//                      Positioned(
//                        top: 10,
//                        right: 10,
//                        child: _buildLocationButtons(routePoints),
//                      ),
//                    ],
//                  ),
//                ),
//              ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _updateRouteStatus(context, trip['id'], 'approved'),
                  icon: const Icon(Icons.check),
                  label: const Text('Aprobar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: () => _updateRouteStatus(context, trip['id'], 'rejected'),
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

    List<Map<String, dynamic>> stopsA = a is Map
        ? a.entries.map((e) => Map<String, dynamic>.from(e.value)).toList()
        : (a as List).map((e) => Map<String, dynamic>.from(e)).toList();

    List<Map<String, dynamic>> stopsB = b is Map
        ? b.entries.map((e) => Map<String, dynamic>.from(e.value)).toList()
        : (b as List).map((e) => Map<String, dynamic>.from(e)).toList();

    for (int i = 0; i < stopsA.length; i++) {
      if (!_isSameLocation(stopsA[i], stopsB[i])) return false;
    }
    return true;
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
      if (stop['latitude'] != null && stop['longitude'] != null) {
        points.add(LatLng(stop['latitude'], stop['longitude']));
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
      if (stop['latitude'] != null && stop['longitude'] != null) {
        markers.add(Marker(
          markerId: MarkerId('stop_$index'),
          position: LatLng(stop['latitude'], stop['longitude']),
          infoWindow: InfoWindow(title: 'Parada ${index + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
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
            FloatingActionButton(
              onPressed: () => _zoomTo(routePoints.first),
              mini: true,
              backgroundColor: Colors.green,
              child: const Text("1", style: TextStyle(fontSize: 18, color: Colors.white)),
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
            FloatingActionButton(
              onPressed: () => _zoomTo(routePoints.last),
              mini: true,
              backgroundColor: Colors.red,
              child: Text("${routePoints.length}", style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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