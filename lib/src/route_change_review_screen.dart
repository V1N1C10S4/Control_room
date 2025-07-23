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
  bool _loadingRoute = true;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> trip = Map<String, dynamic>.from(widget.trip);
    final routeRequest = trip['route_change_request'];
    if (routeRequest == null) {
      return const Scaffold(
        body: Center(child: Text("No hay solicitud de cambio de ruta.")),
      );
    }

    final newPickup = routeRequest['pickup'];
    final newDestination = routeRequest['destination'];
    final dynamic rawStops = routeRequest['stops'];
    late final Map<String, dynamic> allStops;

    if (rawStops is Map) {
      allStops = Map<String, dynamic>.from(rawStops);
    } else if (rawStops is List) {
      allStops = {
        for (int i = 0; i < rawStops.length; i++)
          if (rawStops[i] != null) '$i': rawStops[i],
      };
    } else {
      allStops = {};
    }

    final reason = routeRequest['reason'] ?? 'Sin motivo proporcionado';

    final originalPickup = trip['pickup'];
    final originalDestination = trip['destination'];
    final originalStops = trip['stops'] ?? [];

    final samePickup = _isSameLocation(originalPickup, newPickup);
    final sameDestination = _isSameLocation(originalDestination, newDestination);
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
      newPickup: newPickup,
      newDestination: newDestination,
      filteredStops: filteredStops,
    );

    final routeMarkers = _buildRouteMarkers(
      newPickup: newPickup,
      newDestination: newDestination,
      filteredStops: filteredStops,
    );

    final pickupLatLng = LatLng(newPickup['latitude'], newPickup['longitude']);
    final destinationLatLng = LatLng(newDestination['latitude'], newDestination['longitude']);
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
              '📝 Motivo de cambio de ruta: $reason',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 8),

            Text(
              '🚕 Punto de partida: ${newPickup?['placeName'] ?? 'No disponible'}${!samePickup ? ' - Nuevo punto de partida' : ''}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),

            if (filteredStops.isNotEmpty)
              ...filteredStops.entries.map((e) {
                final placeName = e.value['placeName'] ?? 'Sin nombre';
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '🛑 Parada ${e.key}: $placeName${!sameStops ? ' - Nueva parada' : ''}',
                    style: const TextStyle(fontSize: 20),
                  ),
                );
              }),

            const SizedBox(height: 8),

            Text(
              '🏁 Destino: ${newDestination?['placeName'] ?? 'No disponible'}${!sameDestination ? ' - Nuevo destino' : ''}',
              style: const TextStyle(fontSize: 20),
            ),
            

            if (_loadingRoute)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (routePoints.length >= 2 && isRoutePointsSafe)
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

  bool _isSameLocation(Map? a, Map? b) {
    if (a == null || b == null) return false;

    final placeA = a['placeName']?.toString().trim().toLowerCase();
    final placeB = b['placeName']?.toString().trim().toLowerCase();

    if (placeA == null || placeB == null) return false;

    return placeA == placeB;
  }

  // ✅ Comparador de stops
  bool _areStopsEqual(dynamic a, dynamic b) {
    if (a == null || b == null) return false;

    // Normalizar ambos a listas ordenadas
    final List<Map<String, dynamic>> stopsA = _normalizeStops(a);
    final List<Map<String, dynamic>> stopsB = _normalizeStops(b);

    if (a.length != b.length) return false;

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
    required Map newPickup,
    required Map? newDestination,
    required Map<int, dynamic> filteredStops,
  }) {
    final List<LatLng> points = [];

    // Agregar punto de partida
    if (newPickup['latitude'] != null && newPickup['longitude'] != null) {
      points.add(LatLng(newPickup['latitude'], newPickup['longitude']));
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
    if (newDestination != null &&
        newDestination['latitude'] != null &&
        newDestination['longitude'] != null) {
      points.add(LatLng(newDestination['latitude'], newDestination['longitude']));
    }

    print('📌 Puntos construidos: ${points.map((p) => '(${p.latitude}, ${p.longitude})').toList()}');
    return points;
  }

  Set<Marker> _buildRouteMarkers({
    required Map newPickup,
    required Map? newDestination,
    required Map<int, dynamic> filteredStops,
  }) {
    final Set<Marker> markers = {};

    // 📍 Marker de inicio
    if (newPickup['latitude'] != null && newPickup['longitude'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(newPickup['latitude'], newPickup['longitude']),
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
    if (newDestination != null &&
        newDestination['latitude'] != null &&
        newDestination['longitude'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(newDestination['latitude'], newDestination['longitude']),
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
    print('📍 Marcadores construidos: ${markers.map((m) => '${m.markerId.value}: ${m.position}').toList()}');
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
                heroTag: 'pickup_location',
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
                  heroTag: 'stop_location_$i',
                  onPressed: () => _zoomTo(routePoints[i]),
                  mini: true,
                  backgroundColor: Colors.orange,
                  child: Text("${i + 1}", style: const TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FloatingActionButton(
                heroTag: 'destination_location',
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
    setState(() {
      _loadingRoute = true;
    });

    _polylines.clear();

    LatLng prevPoint = pickup;

    for (int i = 0; i < stops.length; i++) {
      await _fetchPolylineSegment(prevPoint, stops[i], 'segment_$i');
      prevPoint = stops[i];
    }

    await _fetchPolylineSegment(prevPoint, destination, 'finalSegment');

    setState(() {
      _loadingRoute = false;
    });
  }

  Future<void> loadTripData(String tripId) async {
    final tripRef = FirebaseDatabase.instance.ref().child('trip_requests/$tripId');
    final snapshot = await tripRef.get();

    if (snapshot.exists) {
      final tripData = Map<String, dynamic>.from(snapshot.value as Map);

      final status = tripData['status'] as String?;
      final stopsData = Map<String, dynamic>.from(tripData['stops'] ?? {});
      final destinationData = Map<String, dynamic>.from(tripData['destination'] ?? {});

      // Convertir stops a lista ordenada por clave
      final sortedStops = stopsData.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final stopLatLngs = sortedStops.map((e) {
        final lat = e.value['location']['lat'];
        final lng = e.value['location']['lng'];
        return LatLng(lat, lng);
      }).toList();

      final destinationLat = destinationData['location']['lat'];
      final destinationLng = destinationData['location']['lng'];
      final destinationLatLng = LatLng(destinationLat, destinationLng);

      if (status != null && status.startsWith('on_stop_way_')) {
        final stopIndex = int.tryParse(status.split('_').last) ?? 1;
        if (stopIndex - 1 < stopLatLngs.length) {
          final from = stopLatLngs[stopIndex - 1];
          final to = stopIndex < stopLatLngs.length ? stopLatLngs[stopIndex] : destinationLatLng;
          await _fetchRouteWithStops(from, [], to);
        }
      } else if (status == 'picked up passenger' && stopLatLngs.isNotEmpty) {
        await _fetchRouteWithStops(stopLatLngs.last, [], destinationLatLng);
      } else {
        // Otro caso, no trazar ruta
      }
    }
  }

  Future<void> applyApprovedRouteChange(String tripId) async {
    final tripRef = FirebaseDatabase.instance.ref().child('trip_requests/$tripId');
    final routeRequestRef = tripRef.child('route_change_request');

    try {
      final tripSnapshot = await tripRef.get();
      final routeRequestSnapshot = await routeRequestRef.get();

      if (!tripSnapshot.exists || !routeRequestSnapshot.exists) return;

      final tripData = Map<String, dynamic>.from(tripSnapshot.value as Map);
      final routeData = Map<String, dynamic>.from(routeRequestSnapshot.value as Map);

      final updates = <String, dynamic>{};

      // Detectar stops actuales (stop1, stop2, ...)
      final currentStops = <String, dynamic>{};
      for (final entry in tripData.entries) {
        if (RegExp(r'^stop\d+\$').hasMatch(entry.key)) {
          currentStops[entry.key] = entry.value;
        }
      }

      // Generar backup: pickup, destination, stops existentes
      final backupData = <String, dynamic>{};
      if (tripData.containsKey('pickup')) backupData['pickup'] = tripData['pickup'];
      if (tripData.containsKey('destination')) backupData['destination'] = tripData['destination'];
      backupData.addAll(currentStops);
      backupData['timestamp'] = DateTime.now().toIso8601String();

      // Calcular índice disponible: original_trip_data_X
      final backupIndices = tripData.keys
          .where((k) => k.startsWith('original_trip_data_'))
          .map((k) => int.tryParse(k.split('_').last))
          .whereType<int>();
      final nextBackupIndex =
          (backupIndices.isEmpty ? 1 : (backupIndices.reduce((a, b) => a > b ? a : b) + 1));
      final backupKey = 'original_trip_data_$nextBackupIndex';

      updates[backupKey] = backupData;

      // Actualizar pickup y destination si vienen en la solicitud
      if (routeData.containsKey('pickup')) {
        updates['pickup'] = routeData['pickup'];
      }
      if (routeData.containsKey('destination')) {
        updates['destination'] = routeData['destination'];
      }

      // Normalizar newStops desde routeData['stops']
      final Object? rawStops = routeData['stops'];
      final Map<String, dynamic> newStops = {};
      if (rawStops is Map) {
        newStops.addAll(Map<String, dynamic>.from(rawStops));
      } else if (rawStops is List) {
        int stopNumber = 1;
        for (int i = 0; i < rawStops.length; i++) {
          final stop = rawStops[i];
          if (stop != null) {
            newStops['$stopNumber'] = stop;
            stopNumber++;
          }
        }
      }

      // Actualizar stops del 1 al N
      for (final entry in newStops.entries) {
        final stopIndex = entry.key;
        final stopValue = entry.value;
        if (stopValue != null) {
          updates['stop$stopIndex'] = stopValue;
        }
      }

      // Eliminar stops sobrantes
      final newKeys = newStops.keys.map((k) => 'stop$k').toSet();
      final extraStops = currentStops.keys.where((k) => !newKeys.contains(k));
      for (final key in extraStops) {
        updates[key] = null;
      }

      await tripRef.update(updates);
      print('🟢 Cambios de ruta aplicados correctamente para el viaje $tripId');
    } catch (e) {
      print('🔴 Error al aplicar cambios de ruta: $e');
    }
  }

  void _updateRouteStatus(BuildContext context, String tripId, String newStatus) async {
    final tripRef = FirebaseDatabase.instance.ref().child('trip_requests/$tripId');
    final routeRequestRef = tripRef.child('route_change_request');

    try {
      // 1. Leer la solicitud actual
      final routeRequestSnap = await routeRequestRef.get();
      if (!routeRequestSnap.exists) throw 'No se encontró la solicitud de cambio';

      final rawRequest = Map<String, dynamic>.from(routeRequestSnap.value as Map);
      rawRequest.remove('status');
      rawRequest.remove('timestamp');
      rawRequest['result'] = newStatus;

      // 🔍 Sanear stops para evitar undefined/null
      if (rawRequest.containsKey('stops')) {
        final rawStopsRaw = rawRequest['stops'];

        final cleanedStops = <String, dynamic>{};

        if (rawStopsRaw is Map) {
          final rawStops = Map<String, dynamic>.from(rawStopsRaw);
          for (final entry in rawStops.entries) {
            final key = entry.key.toString();
            final value = entry.value;
            final parsedKey = int.tryParse(key);

            if (parsedKey != null && parsedKey >= 1 && value != null) {
              cleanedStops['$parsedKey'] = value;
            }
          }
        } else if (rawStopsRaw is List) {
          int stopNumber = 1;
          for (int i = 0; i < rawStopsRaw.length; i++) {
            final stop = rawStopsRaw[i];
            if (stop != null) {
              cleanedStops['$stopNumber'] = stop;
              stopNumber++;
            }
          }
        }

        rawRequest['stops'] = cleanedStops;
      }

      final filteredRequest = rawRequest;

      // 2. Buscar el siguiente índice disponible para "route_change_result_X"
      final tripSnap = await tripRef.get();
      final tripData = Map<String, dynamic>.from(tripSnap.value as Map);
      final resultKeys = tripData.keys.where((k) => k.startsWith('route_change_result_'));
      final existingIndices = resultKeys.map((k) => int.tryParse(k.split('_').last)).whereType<int>();
      final nextIndex = (existingIndices.isEmpty ? 1 : (existingIndices.reduce((a, b) => a > b ? a : b) + 1));

      final resultKey = 'route_change_result_$nextIndex';

      // 3. Guardar el resultado numerado
      await tripRef.child(resultKey).set(filteredRequest);

      // 4. Actualizar el estado de la solicitud
      await routeRequestRef.update({'status': newStatus});

      // 5. Si se aprueba, aplicar los cambios al nodo principal
      if (newStatus == 'approved') {
        // ✅ NUEVO: Llamada a la función especializada
        await applyApprovedRouteChange(tripId);

        // 6. Retroceder el estado si corresponde
        final currentStatus = tripData['status'];
        final pickedUpAt = tripData['picked_up_passenger_at'];
        final newStops = filteredRequest['stops'] as Map<dynamic, dynamic>? ?? {};

        final newStopIndices = newStops.keys
            .map((k) => int.tryParse(k.toString()))
            .whereType<int>()
            .toList()
          ..sort();

        if (pickedUpAt != null &&
            currentStatus == 'picked up passenger' &&
            newStopIndices.isNotEmpty) {
          final targetIndex = newStopIndices.first;
          final now = DateTime.now().toIso8601String();
          await tripRef.update({
            'status': 'on_stop_way_$targetIndex',
            'on_stop_way_${targetIndex}_at': now,
          });
        }
      }

      // 7. Cerrar pantalla y mostrar confirmación
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          newStatus == 'approved'
              ? 'Solicitud aprobada exitosamente'
              : 'Solicitud denegada exitosamente',
        ),
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