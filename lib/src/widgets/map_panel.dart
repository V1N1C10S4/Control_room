// lib/src/widgets/map_panel.dart
// MapPanel actualizado: usa RTDB (/drivers/*/location) y marcador circular azul para conductores.
// Mantiene foco por coordenadas (MapFocus) y auto-follow del conductor.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/map_focus.dart';
import '../../utils/shift_utils.dart';

class MapPanel extends StatefulWidget {
  final String usuario;
  final String region;
  final ValueNotifier<String?> selectedDriverId;
  final ValueNotifier<MapFocus?> selectedMapFocus;
  final bool autoFollow;

  const MapPanel({
    super.key,
    required this.usuario,
    required this.region,
    required this.selectedDriverId,
    required this.selectedMapFocus,
    this.autoFollow = true,
  });

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  final double _driverFollowZoom = 18.0;
  final double _focusZoom = 17.0;
  GoogleMapController? _map;
  StreamSubscription<DatabaseEvent>? _tripsSub;
  Set<String> _activeDriverIds = <String>{};
  Set<String> get _activeDriverIdsLower => _activeDriverIds.map((e) => e.toLowerCase()).toSet();
  Map<String, dynamic>? _driversPrime; // cache del primer GET a /drivers
  bool _primedDrivers = false;
  bool _primedTrips = false;

  // Últimas posiciones RTDB por driverId
  final Map<String, LatLng> _lastPositions = {};

  // Marcador de foco (coords del TripMonitor)
  Marker? _focusMarker;

  // Icono cacheado para el punto azul de conductores
  BitmapDescriptor? _driverDot;

  final double _defaultZoom = 12.0;

  // Centro por región (heurística simple)
  LatLng get _regionCenter => (widget.region.toLowerCase().contains('tabasco'))
      ? const LatLng(17.989456, -92.947506)
      : const LatLng(19.432608, -99.133209);

  // === Streams ===
  Stream<DatabaseEvent> _activeDriversRtdb() {
    // why: RTDB es la fuente de posiciones en tiempo real
    return FirebaseDatabase.instance.ref('drivers').onValue;
  }

  // === Helpers ===
  Future<BitmapDescriptor> _buildBlueDot({int size = 22, Color color = const Color(0xFF1E88E5)}) async {
    // why: reproducir el look del "my location layer" (círculo azul con borde blanco)
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    final r = size / 2.0;

    final fill = Paint()..color = color;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.18;

    canvas.drawCircle(center, r, fill);
    canvas.drawCircle(center, r - border.strokeWidth / 2, border);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  Future<void> _ensureDriverDot() async {
    if (_driverDot != null) return;
    _driverDot = await _buildBlueDot();
    if (mounted) setState(() {});
  }

  void _followSelected() {
    if (!widget.autoFollow) return;
    if (widget.selectedMapFocus.value != null) return; // foco coords tiene prioridad
    final id = widget.selectedDriverId.value;
    if (id == null || _map == null) return;

    final ll = _lastPositions[id];
    if (ll == null) return;

    _map!.animateCamera(CameraUpdate.newLatLngZoom(ll, _driverFollowZoom));
  }

  void _onFocusChanged() {
    final f = widget.selectedMapFocus.value;
    if (_map == null) return;

    if (f == null) {
      setState(() => _focusMarker = null);
      _followSelected();
      return;
    }

    final markerId = MarkerId('focus_${f.tripId}_${f.key}'); // id único
    setState(() {
      _focusMarker = Marker(
        markerId: markerId,
        position: f.target,
        infoWindow: InfoWindow(title: f.title, snippet: f.snippet),
        zIndexInt: 1000,
      );
    });

    _map!.animateCamera(CameraUpdate.newLatLngZoom(f.target, _focusZoom));
  }

  String _focusLabel(String key) {
    if (key == 'pickup_coords') return 'Partida';
    if (key == 'destination_coords') return 'Destino';
    final m = RegExp(r'^stop(\d+)_coords$').firstMatch(key);
    if (m != null) return 'Parada ${m.group(1)}';
    return key;
  }

  String _driverLabel(String id) {
    // RTDB no almacena nombre/placas en el nodo mostrado, usamos el id.
    return id;
  }

  @override
  void initState() {
    super.initState();
    _ensureDriverDot();
    _primeActiveDriverIdsOnce(); // precarga de trips para tener _activeDriverIds
    _primeDriversOnce();
    _tripsSub = _activeTripsByRegion().listen((ev) {
      final ids = (ev.snapshot.value != null)
          ? _extractActiveDriverIds(ev.snapshot.value)
          : <String>{};
      debugPrint('[MAP][trips] ${widget.region} activeDriverIds=${ids.length} -> ${ids.join(',')}');
      if (!mounted) return;
      setState(() => _activeDriverIds = ids);
    });
    widget.selectedDriverId.addListener(_followSelected);
    widget.selectedMapFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.selectedDriverId.removeListener(_followSelected);
    widget.selectedMapFocus.removeListener(_onFocusChanged);
    _tripsSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Stream<DatabaseEvent> _activeTripsByRegion() {
    return FirebaseDatabase.instance
        .ref('trip_requests')
        .orderByChild('city')
        .equalTo(widget.region)
        .onValue;
  }

  Future<void> _primeActiveDriverIdsOnce() async {
    if (_primedTrips) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('trip_requests')
          .orderByChild('city')
          .equalTo(widget.region)
          .get();
      final ids = snap.value != null ? _extractActiveDriverIds(snap.value) : <String>{};
      if (!mounted) return;
      setState(() {
        _activeDriverIds = ids;
        _primedTrips = true;
      });
    } catch (_) {}
  }

  Future<void> _primeDriversOnce() async {
    if (_primedDrivers) return;
    try {
      final snap = await FirebaseDatabase.instance.ref('drivers').get();
      if (!mounted) return;
      setState(() {
        _driversPrime = (snap.value is Map)
            ? Map<String, dynamic>.from(snap.value as Map)
            : <String, dynamic>{};
        _primedDrivers = true;
      });
    } catch (_) {}
  }

  bool _isActiveTripStatus(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();

    // Dinámicos: on_stop_way_N / stop_reached_N
    if (RegExp(r'^(on_stop_way|stop_reached)_\d+$').hasMatch(s)) return true;

    // Activos “core”
    const active = {
      'started',
      'passenger reached',
      'picked up passenger',
    };
    if (active.contains(s)) return true;

    // Inactivos (excluir)
    const inactive = {
      'in progress',
      'pending',
      'authorized',
      'denied',
      'trip cancelled',
      'scheduled',
      'scheduled canceled',
      'trip finished',
    };
    if (inactive.contains(s)) return false;

    // Conservador: lo que no reconozco, no lo dibujo
    return false;
  }

  Set<String> _extractActiveDriverIds(dynamic root) {
    final region = widget.region.trim();
    final ids = <String>{};

    void consider(Map v) {
      final city   = (v['city'] ?? '').toString().trim();
      if (city != region) return;
      final status = (v['status'] ?? '').toString();
      if (!_isActiveTripStatus(status)) return;

      final driverId = (v['driverUser'] ??
                        v['driver_id']  ??
                        v['driverId']   ??
                        v['driver']     ??
                        '').toString().trim();
      if (driverId.isNotEmpty) ids.add(driverId);
      debugPrint('[MAP] trip city=${v['city']} status=${(v['status'] ?? '').toString()} driver=${driverId.isEmpty ? '—' : driverId} active=${_isActiveTripStatus(status)}');
    }

    if (root is Map) {
      root.values.whereType<Map>().forEach(consider);
    } else if (root is List) {
      for (final v in root) {
        if (v is Map) consider(v);
      }
    }
    debugPrint('[MAP] region=${widget.region} activeDriverIds=${ids.length}');
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final window = currentShiftWindow();

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _MapHeader(
            region: widget.region,
            window: window,
            autoFollow: widget.autoFollow,
            backgroundColor: Colors.black87,
            iconColor: Colors.amber,
            iconSize: 18,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            infoStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            followIconColor: Colors.white,
            followIconSize: 18,
            gap: 6,
            rightGap: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          Expanded(
            child: Stack(
              children: [
                // ======= MAPA =======
                Positioned.fill(
                  child: StreamBuilder<DatabaseEvent>(
                    stream: _activeDriversRtdb(),
                    builder: (context, snap) {
                      debugPrint('[MAP] drivers builder: conn=${snap.connectionState} hasData=${snap.hasData} valType=${snap.data?.snapshot.value.runtimeType}');
                      final markers = <Marker>{};

                      // fuente: stream si hay; si no, PRIME
                      Map<String, dynamic>? rootMap;
                      if (snap.hasData && snap.data!.snapshot.value is Map) {
                        rootMap = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                      }
                      if (rootMap == null || rootMap.isEmpty) {
                        if (_driversPrime != null && _driversPrime!.isNotEmpty) {
                          debugPrint('[MAP] using PRIME drivers fallback count=${_driversPrime!.length}');
                          rootMap = _driversPrime;
                        } else {
                          debugPrint('[MAP] no RTDB data yet and no PRIME fallback');
                        }
                      }

                      if (rootMap != null && rootMap.isNotEmpty) {
                        debugPrint('[MAP] rtdb drivers total=${rootMap.length} activeFilter=${_activeDriverIds.length}');
                        rootMap.forEach((driverId, val) {
                          final id = driverId.toString();
                          final isActiveId = _activeDriverIds.contains(id) || _activeDriverIdsLower.contains(id.toLowerCase());
                          if (!isActiveId) return;
                          if (val is! Map) return;

                          final loc = (val['location'] ?? val['Location'] ?? val['Ubicacion'] ?? val['ubicacion']);
                          if (loc is! Map) return;

                          final lat = _asDouble(loc['lat'] ?? loc['latitude']);
                          final lng = _asDouble(loc['lng'] ?? loc['longitude']);
                          if (lat == null || lng == null) return;

                          final pos = LatLng(lat, lng);
                          _lastPositions[id] = pos;

                          markers.add(
                            Marker(
                              markerId: MarkerId(id),
                              position: pos,
                              icon: _driverDot ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                              zIndexInt: 1,
                              infoWindow: InfoWindow(title: id),
                              onTap: () {
                                if (widget.selectedMapFocus.value != null) widget.selectedMapFocus.value = null;
                                widget.selectedDriverId.value = id;
                                _followSelected();
                              },
                            ),
                          );
                        });
                      }

                      if (_focusMarker != null) markers.add(_focusMarker!);
                      if (widget.autoFollow) WidgetsBinding.instance.addPostFrameCallback((_) => _followSelected());
                      debugPrint('[MAP] markers=${markers.length} focus=${_focusMarker != null}');

                      return GoogleMap(
                        initialCameraPosition: CameraPosition(target: _regionCenter, zoom: _defaultZoom),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        tiltGesturesEnabled: false,
                        onMapCreated: (c) {
                          _map = c;
                          debugPrint('[MAP] onMapCreated: focusAtInit=${widget.selectedMapFocus.value != null}');
                          if (widget.selectedMapFocus.value != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) => _onFocusChanged());
                          }
                        },
                        markers: markers,
                      );
                    },
                  )
                ),

                // ======= BADGE INFERIOR =======
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: StreamBuilder<DatabaseEvent>(
                    stream: _activeDriversRtdb(),
                    builder: (context, snap) {
                      final hasMap = snap.hasData && snap.data!.snapshot.value is Map;
                      if (snap.connectionState == ConnectionState.waiting && !hasMap) {
                        return const _Badge(text: 'Cargando marcadores…');
                      }
                      if (snap.hasError) {
                        return const _Badge(text: 'Error de marcadores', color: Colors.red);
                      }

                      // Fuente: stream si hay; si no, PRIME fallback
                      Map<String, dynamic>? root = hasMap
                          ? Map<String, dynamic>.from(snap.data!.snapshot.value as Map)
                          : _driversPrime;

                      int inWindow = 0;
                      if (root != null && root.isNotEmpty) {
                        inWindow = root.keys
                            .map((k) => k.toString())
                            .where((id) =>
                                _activeDriverIds.contains(id) ||
                                _activeDriverIdsLower.contains(id.toLowerCase()))
                            .length;
                      }
                      debugPrint('[MAP] badge count=$inWindow (activeFilter=${_activeDriverIds.length}, hasMap=$hasMap)');

                      return ValueListenableBuilder<MapFocus?>(
                        valueListenable: widget.selectedMapFocus,
                        builder: (_, focus, __) {
                          return ValueListenableBuilder<String?>(
                            valueListenable: widget.selectedDriverId,
                            builder: (_, sel, __) {
                              String tail = '';
                              if (focus != null) {
                                tail = ' · Foco: ${_focusLabel(focus.key)}';
                              } else if (sel != null) {
                                tail = ' · Siguiendo: ${_driverLabel(sel)}';
                              }
                              return _Badge(text: 'Región ${widget.region} · Marcadores: $inWindow$tail');
                            },
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  final String region;
  final ShiftWindow window;
  final bool autoFollow;

  // Personalización
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final TextStyle titleStyle;
  final TextStyle infoStyle;
  final Color followIconColor;
  final double followIconSize;
  final double gap;
  final double rightGap;
  final EdgeInsetsGeometry padding;

  const _MapHeader({
    required this.region,
    required this.window,
    required this.autoFollow,
    this.backgroundColor = Colors.black,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.titleStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
    this.infoStyle = const TextStyle(color: Colors.white70, fontSize: 12),
    this.followIconColor = Colors.white70,
    this.followIconSize = 18,
    this.gap = 8,
    this.rightGap = 12,
    EdgeInsetsGeometry? padding,
  }) : padding = padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  @override
  Widget build(BuildContext context) {
    String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      color: backgroundColor,
      padding: padding,
      child: Row(
        children: [
          Icon(Icons.map, color: iconColor, size: iconSize),
          SizedBox(width: gap),
          Expanded(child: Text('Mapa · $region', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)),
          SizedBox(width: rightGap),
          Text('Turno: ${hhmm(window.start)} – ${hhmm(window.end)}', style: infoStyle),
          SizedBox(width: rightGap),
          Tooltip(
            message: autoFollow ? 'Auto-follow activo' : 'Auto-follow inactivo',
            child: Icon(autoFollow ? Icons.my_location : Icons.location_searching, color: followIconColor, size: followIconSize),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, this.color = const Color(0xAA000000)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
