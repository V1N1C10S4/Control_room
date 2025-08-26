import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/shift_utils.dart';
import '../trip_request_screen.dart';
import '../scheduled_trip_screen.dart';
import '../ongoing_trip_screen.dart';
import '../finished_trip_screen.dart';
import '../cancelled_trip_screen.dart';
import '../../models/map_focus.dart';

/// Bitácora de viajes activos, con filtro por turno vigente y selección.
/// Por qué: separa UI/negocio para no inflar HomeScreen.
class TripMonitorPanel extends StatefulWidget {
  final String usuario;
  final String region;
  final bool isSupervisor;
  final ValueNotifier<String?> selectedDriverId;
  final void Function(String driverId, Map<String, dynamic> data)? onDriverTap;
  final void Function(String vehicleId, Map<String, dynamic> data)? onVehicleTap;
  final void Function(String supervisorId, Map<String, dynamic> data)? onSupervisorTap;
  final double minTableWidth;
  final ValueNotifier<MapFocus?> selectedMapFocus;

  const TripMonitorPanel({
    super.key,
    required this.usuario,
    required this.selectedMapFocus,
    required this.region,
    required this.isSupervisor,
    required this.selectedDriverId,
    this.onDriverTap,
    this.onVehicleTap,
    this.onSupervisorTap,
    this.minTableWidth = 1100,
  });

  @override
  State<TripMonitorPanel> createState() => _TripMonitorPanelState();
}

class _TripMonitorPanelState extends State<TripMonitorPanel> {
  late ShiftWindow _window;
  Timer? _cutoffTimer;
  late final ScrollController _hCtrl; // horizontal
  late final ScrollController _vCtrl; // vertical
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _window = currentShiftWindow();
    _scheduleCutoffRefresh();
     _debugCheckCityFeed();
    _hCtrl = ScrollController();
    _vCtrl = ScrollController();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    _cutoffTimer?.cancel();
    super.dispose();
  }

  void _scheduleCutoffRefresh() {
    _cutoffTimer?.cancel();
    final d = durationToNextCutoff();
    _cutoffTimer = Timer(d + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {
        _window = currentShiftWindow();
      });
      _scheduleCutoffRefresh();
    });
  }

  Future<void> _debugCheckCityFeed() async {
    final ss = await FirebaseDatabase.instance
        .ref('trip_requests')
        .orderByChild('city')
        .equalTo(widget.region)
        .limitToFirst(1)
        .get();
    debugPrint('RTDB city="${widget.region}" exists: ${ss.exists}');
  }

  Stream<DatabaseEvent> _tripRequestsStream() {
    final ref = FirebaseDatabase.instance.ref('trip_requests');
    // Ahora el servidor solo envía los viajes de la ciudad actual
    return ref.orderByChild('city').equalTo(widget.region).onValue;
  }

  /// ¿El estado cuenta como “viaje activo” para la bitácora?
  bool _isActiveStatus(String? s) {
    final t = (s ?? '').toLowerCase().trim();

    // 1) estados exactos que consideras válidos
    const exact = {
      'pending',
      'started',
      'passenger reached',
      'picked up passenger',
      'in progress',
      'trip finished',
      'trip cancelled',
      'scheduled canceled',
      'scheduled',
      'authorized',
      'denied',
    };
    if (exact.contains(t)) return true;

    // 2) estados dinámicos: on_stop_way_x  /  stop_reached_x   (x = número)
    final dyn = RegExp(r'^(on_stop_way|stop_reached)_(\d+)$');
    if (dyn.hasMatch(t)) return true;

    return false;
  }

  bool _isMapFollowableStatus(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    if (RegExp(r'^(on_stop_way|stop_reached)_\d+$').hasMatch(s)) return true;
    const active = {
      'started',
      'passenger reached',
      'picked up passenger',
    };
    return active.contains(s);
  }

  void _showSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// Convierte varios formatos comunes de timestamp de RTDB a DateTime.
  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is int)   return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) {
      // intenta ISO o milisegundos en string
      final ms = int.tryParse(v);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
      try { return DateTime.parse(v); } catch (_) {}
    }
    return null;
  }

  DateTime? _tripDate(Map<String, dynamic> m) {
  dynamic v =
        m['scheduled_at'] ??
        (m['pickup'] is Map ? (m['pickup']['scheduled_at']) : null) ??
        m['created_at'] ??
        m['createdAt'];
    return _toDate(v);
  }

  /// Valida que la fecha esté dentro del turno (día+horario) actual.
  bool _inWindowRTDB(Map<String, dynamic> m) {
    final dt = _tripDate(m);
    if (dt == null) return false; // sin fecha de referencia ⇒ no entra a la bitácora
    return dt.isAfterOrAt(_window.start) && dt.isBefore(_window.end);
  }

  final List<String> _staticFieldOrder = [
    "trip_id",
    "status",
    "driver_id",
    "driver_name",
    "TelefonoConductor",
    "vehicle_plates",
    "vehicle_info",
    "userId",
    "userName",
    "telefonoPasajero",
    "created_at",
    "city",
    "pickup",
    "pickup_coords",
    "destination",
    "destination_coords",
    "passengers",
    "luggage", //Dinámico
    "pets", //Dinámico
    "babySeats", //Dinámico
    "need_second_driver", //Dinámico
    "notes", //Dinámico
    "driver_feedback", //Dinámico
    "user_feedback", //Dinámico
    "emergency", 
    "emergency_at", //Dinámico
    "emergency_location", //Dinámico
    "emergency_reason", //Dinámico
    "attended_at", //Dinámico
    "started_at",
    "passenger_reached_at",
    "picked_up_passenger_at",
    "finished_at",
    "route_change_request", //Dinámico
    "scheduled_at", //Dinámico
    "cancellation_reason", //Dinámico
  ];

  final Map<String, String> _fieldTranslations = const {
    "trip_id": "Id de viaje",
    "status": "Estatus",
    "driver_id": "Id de conductor",
    "driver_name": "Nombre de conductor",
    "TelefonoConductor": "Teléfono de conductor",
    "vehicle_plates": "Placas del vehículo",
    "vehicle_info": "Info. del vehículo",
    "driver2": "Id de conductor 2",
    "driver2_name": "Nombre de conductor 2",
    "TelefonoConductor2": "Teléfono de conductor 2",
    "vehicle2_plates": "Placas del vehículo 2",
    "vehicle2_info": "Info. del vehículo 2",
    "userId": "Id de pasajero",
    "userName": "Nombre de pasajero",
    "telefonoPasajero": "Teléfono pasajero",
    "created_at": "Viaje creado",
    "city": "Ciudad",
    "pickup": "Punto de partida",
    "pickup_coords": "Coordenadas de partida",
    "destination": "Destino",
    "destination_coords": "Coordenadas de destino",
    "passengers": "Pasajeros",
    "luggage": "Equipaje",
    "pets": "Mascotas",
    "babySeats": "Sillas para bebé",
    "need_second_driver": "Segundo conductor requerido",
    "notes": "Notas adicionales",
    "driver_feedback": "Opinión de conductor",
    "user_feedback": "Opinión del pasajero",
    "emergency": "Emergencia activa",
    "attended_at": "Emergencia atendida",
    "emergency_at": "Emergencia presentada",
    "emergency_location": "Ubicación de emergencia",
    "emergency_reason": "Razón de emergencia",
    "started_at": "Viaje autorizado",
    "passenger_reached_at": "Pasajero alcanzado",
    "picked_up_passenger_at": "Pasajero recogido",
    "finished_at": "Viaje terminado",
    "route_change_request": "Solicitud cambio de ruta",
    "scheduled_at": "Fecha de viaje agendado",
    "cancellation_reason": "Razón de cancelación",
  };

  String _labelFromKey(String key) {
    // Etiquetas conocidas
    if (_fieldTranslations.containsKey(key)) return _fieldTranslations[key]!;

    // stopN  / stopN_coords
    final stopMatch = RegExp(r'^stop(\d+)$').firstMatch(key);
    if (stopMatch != null) {
      return 'Parada ${stopMatch.group(1)}';
    }
    final stopCoordsMatch = RegExp(r'^stop(\d+)_coords$').firstMatch(key);
    if (stopCoordsMatch != null) {
      return 'Coordenadas de parada ${stopCoordsMatch.group(1)}';
    }

    // on_stop_way_N_at
    final onWayMatch = RegExp(r'^on_stop_way_(\d+)_at$').firstMatch(key);
    if (onWayMatch != null) {
      return 'En camino a parada ${onWayMatch.group(1)} (hora)';
    }

    // stop_reached_N_at
    final reachedMatch = RegExp(r'^stop_reached_(\d+)_at$').firstMatch(key);
    if (reachedMatch != null) {
      return 'Parada ${reachedMatch.group(1)} alcanzada (hora)';
    }

    // Fallback: key “en crudo”
    return key;
  }

  Map<String, dynamic> _normalizeTrip(Map<String, dynamic> src) {
  final data = Map<String, dynamic>.from(src);

    // pickup
    if (data['pickup'] is Map) {
      final p = Map<String, dynamic>.from(data['pickup']);
      data['pickup'] = (p['placeName'] ?? '').toString();
      final lat = p['latitude']; final lng = p['longitude'];
      if (lat != null && lng != null) {
        data['pickup_coords'] = '$lat, $lng';
      }
      // si trae scheduled_at dentro de pickup, déjalo como está; _tripDate ya lo consume
    }

    // destination
    if (data['destination'] is Map) {
      final d = Map<String, dynamic>.from(data['destination']);
      data['destination'] = (d['placeName'] ?? '').toString();
      final lat = d['latitude']; final lng = d['longitude'];
      if (lat != null && lng != null) {
        data['destination_coords'] = '$lat, $lng';
      }
    }

    // stops dinámicos: stopN (Map -> placeName + coords)
    final stopKeys = data.keys.where((k) => RegExp(r'^stop\d+$').hasMatch(k)).toList();
    for (final key in stopKeys) {
      final v = data[key];
      if (v is Map) {
        final s = Map<String, dynamic>.from(v);
        data[key] = (s['placeName'] ?? '').toString();
        final lat = s['latitude']; final lng = s['longitude'];
        if (lat != null && lng != null) {
          data['${key}_coords'] = '$lat, $lng';
        }
      }
    }

    // driver_feedback (Map -> texto legible)
    if (data['driver_feedback'] is Map) {
      final f = Map<String, dynamic>.from(data['driver_feedback']);
      data['driver_feedback'] = '''
      Comportamiento general: ${f['comportamientoGeneral'] ?? ''}
      Es puntual: ${f['esPuntual'] ?? ''}
      Seguridad del vehículo: ${f['seguridadVehiculo'] ?? ''}
      Calificación: ${f['starRating'] ?? ''}
      Comentarios adicionales: ${f['comentariosAdicionales'] ?? ''}'''.trim();
    }

    // user_feedback (Map -> texto legible)
    if (data['user_feedback'] is Map) {
      final f = Map<String, dynamic>.from(data['user_feedback']);
      data['user_feedback'] = '''
      Siguió reglas de tránsito: ${f['followedTrafficRules'] ?? ''}
      Servicio general: ${f['generalService'] ?? ''}
      Seguridad del vehículo: ${f['vehicleSafety'] ?? ''}
      Calificación: ${f['starRating'] ?? ''}
      Comentarios adicionales: ${f['additionalComments'] ?? ''}'''.trim();
    }

    // emergency_location (Map -> "lat, lng")
    if (data['emergency_location'] is Map) {
      final e = Map<String, dynamic>.from(data['emergency_location']);
      final lat = e['latitude']; final lng = e['longitude'];
      if (lat != null && lng != null) {
        data['emergency_location'] = '$lat, $lng';
      }
    }

    // route_change_request (Map -> status)
    if (data['route_change_request'] is Map) {
      final r = Map<String, dynamic>.from(data['route_change_request']);
      data['route_change_request'] = (r['status'] ?? '').toString();
    }

    return data;
  }

  Map<String, List<String>> _extractDynamicKeys(List<Map<String, dynamic>> trips) {
    final stops = <String>{};
    final stopCoords = <String>{};
    final stopWays = <String>{};     // on_stop_way_N_at
    final stopReached = <String>{};  // stop_reached_N_at

    for (final t in trips) {
      for (final key in t.keys) {
        if (RegExp(r'^stop\d+$').hasMatch(key)) {
          stops.add(key);
          final cKey = '${key}_coords';
          if (t.containsKey(cKey)) stopCoords.add(cKey);
        } else if (RegExp(r'^on_stop_way_\d+_at$').hasMatch(key)) {
          stopWays.add(key);
        } else if (RegExp(r'^stop_reached_\d+_at$').hasMatch(key)) {
          stopReached.add(key);
        }
      }
    }

    // Orden numérico por índice
    int _numFrom(String s, RegExp re, int group) {
      final m = re.firstMatch(s);
      if (m == null) return 0;
      return int.tryParse(m.group(group) ?? '0') ?? 0;
    }

    final sortedStops = stops.toList()
      ..sort((a, b) => _numFrom(a, RegExp(r'^stop(\d+)$'), 1)
          .compareTo(_numFrom(b, RegExp(r'^stop(\d+)$'), 1)));

    final sortedStopCoords = stopCoords.toList()
      ..sort((a, b) => _numFrom(a, RegExp(r'^stop(\d+)_coords$'), 1)
          .compareTo(_numFrom(b, RegExp(r'^stop(\d+)_coords$'), 1)));

    final sortedStopWays = stopWays.toList()
      ..sort((a, b) => _numFrom(a, RegExp(r'^on_stop_way_(\d+)_at$'), 1)
          .compareTo(_numFrom(b, RegExp(r'^on_stop_way_(\d+)_at$'), 1)));

    final sortedStopReached = stopReached.toList()
      ..sort((a, b) => _numFrom(a, RegExp(r'^stop_reached_(\d+)_at$'), 1)
          .compareTo(_numFrom(b, RegExp(r'^stop_reached_(\d+)_at$'), 1)));

    return {
      'stops': sortedStops,
      'stopCoords': sortedStopCoords,
      'stopWays': sortedStopWays,
      'stopReached': sortedStopReached,
    };
  }

  bool _looksEmpty(dynamic v) {
    if (v == null) return true;
    if (v is bool) return !v;                       // solo mostramos si en algún viaje hay true
    if (v is num) return false;                     // cualquier número cuenta como no vacío
    if (v is String) return v.trim().isEmpty;       // string vacío => vacío
    if (v is Map) return v.isEmpty;
    if (v is Iterable) return v.isEmpty;
    return false;                                   // por defecto, considérese no vacío
  }

  bool _hasAnyNonEmpty(List<Map<String, dynamic>> trips, String key) {
    for (final t in trips) {
      if (t.containsKey(key) && !_looksEmpty(t[key])) return true;
    }
    return false;
  }

  List<String> _buildTableKeys(List<Map<String, dynamic>> trips) {
    final dyn = _extractDynamicKeys(trips);
    final keys = List<String>.from(_staticFieldOrder);

    // 1) Oculta campos dinámicos si nadie los usa
    const dynamicCandidates = <String>{
      'luggage',
      'pets',
      'babySeats',
      'need_second_driver',
      'notes',
      'driver_feedback',
      'user_feedback',
      'attended_at',
      'emergency_at',
      'emergency_location',
      'emergency_reason',
      'route_change_request',
      'scheduled_at',
      'cancellation_reason',
    };
    for (final k in dynamicCandidates) {
      if (!_hasAnyNonEmpty(trips, k)) keys.remove(k);
    }

    // 2) ¿hay algún dato del conductor 2?
    final hasDriver2 =
        _hasAnyNonEmpty(trips, 'driver2') ||
        _hasAnyNonEmpty(trips, 'driver2_name') || _hasAnyNonEmpty(trips, 'driver2Name') ||
        _hasAnyNonEmpty(trips, 'TelefonoConductor2') ||
        _hasAnyNonEmpty(trips, 'vehicle2_plates')  || _hasAnyNonEmpty(trips, 'vehicle2Plates') ||
        _hasAnyNonEmpty(trips, 'vehicle2_info')    || _hasAnyNonEmpty(trips, 'vehicle2Info');

    if (hasDriver2) {
      // devuelve SIEMPRE String ('' si no hay coincidencia) ⇒ no-nullable
      String chooseExisting(List<String> options) {
        for (final k in options) {
          if (_hasAnyNonEmpty(trips, k)) return k;
        }
        return '';
      }

      final driver2IdKey      = chooseExisting(['driver2']);
      final driver2NameKey    = chooseExisting(['driver2_name', 'driver2Name']);
      final driver2PhoneKey   = chooseExisting(['TelefonoConductor2']);
      final vehicle2PlatesKey = chooseExisting(['vehicle2_plates', 'vehicle2Plates']);
      final vehicle2InfoKey   = chooseExisting(['vehicle2_info', 'vehicle2Info']);

      int afterIdx = keys.indexOf('vehicle_info');
      if (afterIdx == -1) {
        afterIdx = keys.indexOf('TelefonoConductor');
        if (afterIdx == -1) afterIdx = keys.indexOf('driver_name');
        if (afterIdx == -1) afterIdx = keys.indexOf('driver_id');
        if (afterIdx == -1) afterIdx = 2;
      }

      final toInsert = <String>[];
      if (driver2IdKey.isNotEmpty) toInsert.add(driver2IdKey);
      if (driver2NameKey.isNotEmpty) toInsert.add(driver2NameKey);
      if (driver2PhoneKey.isNotEmpty) toInsert.add(driver2PhoneKey);
      if (vehicle2PlatesKey.isNotEmpty) toInsert.add(vehicle2PlatesKey);
      if (vehicle2InfoKey.isNotEmpty) toInsert.add(vehicle2InfoKey);

      if (toInsert.isNotEmpty) {
        keys.insertAll(afterIdx + 1, toInsert);
      }
    }

    // 3) Paradas dinámicas tras pickup/pickup_coords
    int insertAfter = keys.indexOf('pickup_coords');
    if (insertAfter == -1) insertAfter = keys.indexOf('pickup');
    if (insertAfter == -1) insertAfter = keys.indexOf('city');
    if (insertAfter == -1) insertAfter = 8;

    int offset = 1;
    for (final stopKey in dyn['stops']!) {
      final coordKey = '${stopKey}_coords';
      keys.insert(insertAfter + offset, stopKey);
      offset++;
      if (dyn['stopCoords']!.contains(coordKey)) {
        keys.insert(insertAfter + offset, coordKey);
        offset++;
      }
    }

    // 4) Timeline al final
    keys.addAll(dyn['stopWays']!);
    keys.addAll(dyn['stopReached']!);

    // 5) Deduplicar
    final seen = <String>{};
    final result = <String>[];
    for (final k in keys) {
      if (seen.add(k)) result.add(k);
    }
    return result;
  }

  void _toggleRowSelection(
    BuildContext ctx,
    String tripId,
    String driverId,
    Map<String, dynamic> rowData, {
    bool showSnack = true, // ← nuevo
  }) {
    final isSame    = _selectedTripId == tripId;
    final hasFocus  = widget.selectedMapFocus.value != null;
    final canFollow = _isMapFollowableStatus(rowData['status']?.toString());

    // Viaje NO seguible: selecciona, limpia focus/follow y (opcionalmente) avisa
    if (!canFollow) {
      if (isSame) {
        setState(() => _selectedTripId = null); // permite deseleccionar
      } else {
        setState(() => _selectedTripId = tripId);
      }
      widget.selectedDriverId.value = null;
      widget.selectedMapFocus.value = null;
      if (showSnack) {
        _showSnack(ctx, 'No se puede seguir la ubicación: el viaje no está activo.');
      }
      return;
    }

    // Con foco activo (coords) ⇒ cambiar a seguir conductor
    if (hasFocus) {
      setState(() => _selectedTripId = tripId);
      widget.selectedMapFocus.value = null;
      if (driverId.isNotEmpty) {
        widget.selectedDriverId.value = driverId;
      }
      widget.onDriverTap?.call(driverId, rowData);
      return;
    }

    // Toggle normal
    if (isSame) {
      setState(() => _selectedTripId = null);
      widget.selectedDriverId.value = null;
      return;
    }

    setState(() => _selectedTripId = tripId);
    if (driverId.isNotEmpty) {
      widget.selectedDriverId.value = driverId;
    }
    widget.onDriverTap?.call(driverId, rowData);
  }

  String _statusLabelFor(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();

    // Dinámicos
    final mOnWay = RegExp(r'^on_stop_way_(\d+)(?:_at)?$').firstMatch(s);
    if (mOnWay != null) return 'En camino a parada ${mOnWay.group(1)}';

    final mReached = RegExp(r'^stop_reached_(\d+)(?:_at)?$').firstMatch(s);
    if (mReached != null) return 'Esperando en parada ${mReached.group(1)}';

    switch (s) {
      case 'pending':              return 'Pendiente';
      case 'authorized':           return 'Autorizado';
      case 'in progress':          return 'Esperando conductor';

      case 'started':
      case 'trip started':         return 'Iniciado';
      case 'passenger reached':    return 'Conductor en sitio';
      case 'picked up passenger':  return 'Pasajero recogido';

      case 'scheduled':            return 'Agendado';

      case 'denied':               return 'Denegado';
      case 'trip cancelled':       return 'Viaje cancelado';
      case 'scheduled canceled':   return 'Viaje agendado cancelado';
      case 'trip finished':        return 'Viaje terminado';
    }
    return 'Desconocido';
  }

  // === Color por GRUPOS que definiste ===
  Color _statusColorFor(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();

    // Grupo 1 → TripRequestScreen
    if (s == 'pending' || s == 'authorized' || s == 'in progress') {
      return const Color.fromRGBO(152, 192, 131, 1);
    }

    // Grupo 2 → OngoingTripScreen (incluye dinámicos)
    if (s == 'started' ||
        s == 'trip started' ||
        s == 'passenger reached' ||
        s == 'picked up passenger' ||
        RegExp(r'^on_stop_way_\d+(?:_at)?$').hasMatch(s) ||
        RegExp(r'^stop_reached_\d+(?:_at)?$').hasMatch(s)) {
      return const Color.fromRGBO(207, 215, 107, 1);
    }

    // Grupo 3 → ScheduledTripScreen
    if (s == 'scheduled') {
      return const Color.fromRGBO(180, 180, 255, 1);
    }

    // Grupo 4 (mismo color para todos): denied / cancelled / scheduled canceled / finished
    if (s == 'denied' || s == 'trip cancelled' || s == 'scheduled canceled' || s == 'trip finished') {
      return const Color.fromRGBO(255, 99, 71, 1);
    }

    // Fallback
    return Colors.grey;
  }

  // === Navegación según status (usa el status crudo) ===
  void _navigateByStatus(BuildContext context, String statusRaw) {
    final s = statusRaw.toLowerCase().trim();

    // Grupo 1
    if (s == 'pending' || s == 'authorized' || s == 'in progress') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TripRequestScreen(
          usuario: widget.usuario,
          isSupervisor: widget.isSupervisor, // si aplica
          region: widget.region,
        ),
      ));
      return;
    }

    // Grupo 2 (incluye dinámicos)
    if (s == 'started' ||
        s == 'trip started' ||
        s == 'passenger reached' ||
        s == 'picked up passenger' ||
        s.startsWith('on_stop_way_') ||
        s.startsWith('stop_reached_')) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OngoingTripScreen(usuario: widget.usuario, region: widget.region),
      ));
      return;
    }

    // Grupo 3
    if (s == 'scheduled') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ScheduledTripScreen(region: widget.region),
      ));
      return;
    }

    // Grupo 4 (mismo color, rutas distintas)
    if (s == 'denied') {
      // No navega a ningún lado
      return;
    }
    if (s == 'trip cancelled') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CancelledTripsScreen(region: widget.region),
      ));
      return;
    }
    if (s == 'scheduled canceled') {
      // No navega a ningún lado
      return;
    }
    if (s == 'trip finished') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => FinishedTripScreen(usuario: widget.usuario, region: widget.region),
      ));
      return;
    }

    // Fallback: no navega
  }

  LatLng? _parseLatLng(String s) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _boolEs(dynamic v) {
    if (v == null) return 'No';
    if (v is bool) return v ? 'Sí' : 'No';
    final s = v.toString().trim().toLowerCase();
    return (s == 'true' || s == '1' || s == 'si' || s == 'sí' || s == 'yes') ? 'Sí' : 'No';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Header(
            region: widget.region,
            window: _window,
            backgroundColor: Colors.black87,
            iconColor: Colors.amber,
            iconSize: 16,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            infoStyle: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _tripRequestsStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final root = snap.data!.snapshot.value;
                if (root == null) {
                  return const Center(child: Text('Sin viajes en el turno vigente'));
                }

                // 1) Normaliza el árbol de RTDB a entries clave/valor
                final entries = <MapEntry<String, Map<String, dynamic>>>[];
                if (root is Map) {
                  root.forEach((k, v) {
                    if (v is Map) {
                      entries.add(MapEntry(k.toString(), Map<String, dynamic>.from(v)));
                    }
                  });
                } else if (root is List) {
                  for (var i = 0; i < root.length; i++) {
                    final v = root[i];
                    if (v is Map) {
                      entries.add(MapEntry(i.toString(), Map<String, dynamic>.from(v)));
                    }
                  }
                }

                // 2) Normaliza cada viaje con tu helper
                final normalizedAll = entries.map((e) {
                  final raw = e.value; // mapa crudo de RTDB
                  final n = _normalizeTrip(Map<String, dynamic>.from(raw));

                  // Completa identificadores y campos base
                  n['trip_id']         = e.key;
                  n['city']            = (raw['city'] ?? '').toString();
                  n['status']          = (raw['status'] ?? '').toString();

                  n['driver_id']   = (raw['driverUser'] ?? raw['driver_id'] ?? raw['driverId'] ?? raw['driver'] ?? '').toString();
                  n['driver_name'] = (raw['driverName'] ?? raw['driver_name'] ?? raw['NombreConductor'] ?? '').toString();
                  n['TelefonoConductor'] = (raw['TelefonoConductor'] ?? raw['driverPhone'] ?? '').toString();

                  n['vehicle_plates'] = (raw['vehiclePlates'] ?? raw['placas'] ?? raw['Placas'] ?? '').toString();
                  n['vehicle_info']   = (raw['vehicleInfo']   ?? raw['infoVehiculo'] ?? raw['InfoVehiculo'] ?? '').toString();

                  // Segundo conductor (si existe)
                  n['driver2']            = (raw['driver2'] ?? '').toString();
                  n['driver2_name']       = (raw['driver2Name'] ?? raw['driver2_name'] ?? '').toString();
                  n['TelefonoConductor2'] = (raw['TelefonoConductor2'] ?? raw['driver2Phone'] ?? '').toString();
                  n['vehicle2_plates']    = (raw['vehicle2Plates'] ?? raw['placas2'] ?? '').toString();
                  n['vehicle2_info']      = (raw['vehicle2Info'] ?? raw['infoVehiculo2'] ?? '').toString();

                  return n;
                }).toList();

                // 3) Filtra por status activo y ventana de turno
                //    (El filtro por ciudad ya lo hace el stream en servidor, pero dejamos
                //     una verificación defensiva por si acaso.)
                final city = widget.region.trim();
                final normalizedTrips = <Map<String, dynamic>>[];

                for (int i = 0; i < entries.length; i++) {
                  final raw = entries[i].value;
                  final n   = normalizedAll[i];

                  final okCity        = (n['city']?.toString().trim() ?? '') == city;
                  final statusStr     = n['status']?.toString();
                  final okStatus      = _isActiveStatus(statusStr);
                  final okWindow      = _inWindowRTDB(raw); // usa el mapa crudo para fechas
                  final followableNow = _isMapFollowableStatus(statusStr);

                  // Incluye si está en ventana Y con status permitido, O si es seguible ahora mismo
                  if (okCity && ((okStatus && okWindow) || followableNow)) {
                    normalizedTrips.add(n);
                  }
                }

                if (normalizedTrips.isEmpty) {
                  return const Center(child: Text('Sin viajes en el turno vigente'));
                }

                // 4) Llaves de tabla dinámicas con tu helper
                final tableKeys = _buildTableKeys(normalizedTrips);

                final displayTrips = normalizedTrips.reversed.toList();

                return ValueListenableBuilder<String?>(
                  valueListenable: widget.selectedDriverId,
                  builder: (context, selId, _) {
                    return Scrollbar(
                      controller: _hCtrl,            // 👈 barra horizontal
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _hCtrl,          // 👈 mismo controller
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: widget.minTableWidth),
                          child: Scrollbar(
                            controller: _vCtrl,      // 👈 barra vertical
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _vCtrl,    // 👈 mismo controller
                              scrollDirection: Axis.vertical,
                              child: DataTableTheme(
                                data: DataTableThemeData(
                                  headingRowColor: const WidgetStatePropertyAll(Color(0x11000000)),
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  columnSpacing: 16,
                                  headingRowHeight: 34,
                                  dataRowMinHeight: 36,
                                  dataRowMaxHeight: 44,
                                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w600),

                                  // Encabezados usando _labelFromKey
                                  columns: tableKeys
                                      .map((k) => DataColumn(label: Text(_labelFromKey(k))))
                                      .toList(),

                                  // Filas dinámicas
                                  rows: displayTrips.map((m) {
                                    final tripId = (m['trip_id'] ?? '').toString();
                                    final driverId   = (m['driver_id'] ?? '').toString();
                                    final driverName = (m['driver_name'] ?? '').toString();
                                    final ciudad     = (m['city'] ?? '').toString();
                                    final status     = (m['status'] ?? '').toString();

                                    final placas     = (m['vehicle_plates'] ?? '').toString();
                                    final infoVeh    = (m['vehicle_info'] ?? '').toString();

                                    final supId      = (m['supervisor_id'] ?? '').toString();
                                    final supName    = (m['supervisor_name'] ?? '').toString();
                                    final supPhone   = (m['supervisor_phone'] ?? '').toString();

                                    String fmtShort(DateTime d) {
                                      String two(int x) => x.toString().padLeft(2, '0');
                                      return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
                                    }

                                    String fmtValue(dynamic v) {
                                      final dt = _toDate(v);
                                      if (dt != null) return fmtShort(dt);
                                      if (v is bool) return v ? '✓' : '—';
                                      return (v ?? '').toString();
                                    }

                                    Widget cellText(String text, {double? maxW, TextStyle? style}) {
                                      final child = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
                                      return (maxW != null) ? SizedBox(width: maxW, child: child) : child;
                                    }
                                    DataCell buildCell(String key) {
                                      switch (key) {
                                        case 'emergency':
                                        case 'need_second_driver':
                                          return DataCell(
                                            cellText(_boolEs(m[key]), maxW: 90),
                                            onTap: () => _toggleRowSelection(context, tripId, driverId, m),
                                          );
                                        case 'driver_name':
                                          final canFollow = _isMapFollowableStatus(status);
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow ? 'Seguir conductor en mapa' : 'Ubicación no disponible (viaje inactivo)',
                                              child: cellText(
                                                driverName.isEmpty ? '—' : driverName,
                                                maxW: 180,
                                                style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            onTap: () => _toggleRowSelection(context, tripId, driverId, m),
                                          );
                                        case 'driver_id': {
                                          final canFollow = _isMapFollowableStatus(status);
                                          final child = cellText(
                                            driverId.isEmpty ? '—' : driverId,
                                            maxW: 140,
                                            style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic), // why: indicar inactivo
                                          );
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow
                                                  ? 'Seguir conductor en el mapa'
                                                  : 'Ubicación no disponible: viaje inactivo',
                                              child: child,
                                            ),
                                            onTap: () => _toggleRowSelection(context, tripId, driverId, m), // ← pasa context
                                          );
                                        }
                                        case 'city': {
                                          final canFollow = _isMapFollowableStatus(status);
                                          final child = cellText(
                                            ciudad,
                                            maxW: 110,
                                            style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                          );
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow
                                                  ? 'Seguir conductor en el mapa'
                                                  : 'Ubicación no disponible: viaje inactivo',
                                              child: child,
                                            ),
                                            onTap: () => _toggleRowSelection(context, tripId, driverId, m), // ← pasa context
                                          );
                                        }
                                        case 'status': {
                                          final raw = status; // el crudo de RTDB
                                          final label = _statusLabelFor(raw);
                                          final color = _statusColorFor(raw);

                                          return DataCell(
                                            _StatusChip(
                                              text: label,
                                              color: color,
                                              onTap: () {
                                                _toggleRowSelection(context, tripId, driverId, m, showSnack: false); // ahora pasa context
                                                _navigateByStatus(context, raw);
                                              },
                                            ),
                                          );
                                        }
                                        case 'TelefonoConductor':
                                          return DataCell(cellText((m['TelefonoConductor'] ?? '').toString().isEmpty ? '—' : (m['TelefonoConductor'] ?? '').toString(), maxW: 140));

                                        case 'vehicle_plates':
                                          return DataCell(
                                            cellText(placas.isEmpty ? '—' : placas, maxW: 120),
                                            onTap: () => widget.onVehicleTap?.call(
                                              placas.isEmpty ? '—' : placas,
                                              {'Placas': placas, 'InfoVehiculo': infoVeh, 'Ciudad': ciudad},
                                            ),
                                          );

                                        case 'vehicle_info':
                                          return DataCell(
                                            cellText(infoVeh.isEmpty ? '—' : infoVeh, maxW: 220),
                                            onTap: () => widget.onVehicleTap?.call(
                                              placas.isEmpty ? '—' : placas,
                                              {'Placas': placas, 'InfoVehiculo': infoVeh, 'Ciudad': ciudad},
                                            ),
                                          );

                                        // ====== Segundo conductor ======
                                        case 'driver2_name': {
                                          final id2  = (m['driver2'] ?? '').toString();
                                          final name = (m['driver2_name'] ?? '').toString();
                                          final canFollow = _isMapFollowableStatus(status);
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow ? 'Seguir conductor 2 en mapa' : 'Ubicación no disponible (viaje inactivo)',
                                              child: cellText(
                                                name.isEmpty ? '—' : name,
                                                maxW: 180,
                                                style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            onTap: () => _toggleRowSelection(context, tripId, id2, m),
                                          );
                                        }

                                        case 'driver2': {
                                          final id2 = (m['driver2'] ?? '').toString();
                                          final canFollow = _isMapFollowableStatus(status);
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow ? 'Seguir conductor 2 en mapa' : 'Ubicación no disponible (viaje inactivo)',
                                              child: cellText(
                                                id2.isEmpty ? '—' : id2,
                                                maxW: 140,
                                                style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            onTap: () => _toggleRowSelection(context, tripId, id2, m),
                                          );
                                        }

                                        case 'TelefonoConductor2': {
                                          final phone2 = (m['TelefonoConductor2'] ?? '').toString();
                                          return DataCell(cellText(phone2.isEmpty ? '—' : phone2, maxW: 140));
                                        }

                                        case 'vehicle2_plates': {
                                          final placas2 = (m['vehicle2_plates'] ?? '').toString();
                                          final info2   = (m['vehicle2_info'] ?? '').toString();
                                          return DataCell(
                                            cellText(placas2.isEmpty ? '—' : placas2, maxW: 120),
                                            onTap: () => widget.onVehicleTap?.call(
                                              placas2,
                                              {'Placas': placas2, 'InfoVehiculo': info2, 'Ciudad': ciudad},
                                            ),
                                          );
                                        }

                                        case 'vehicle2_info': {
                                          final info2   = (m['vehicle2_info'] ?? '').toString();
                                          final placas2 = (m['vehicle2_plates'] ?? '').toString();
                                          return DataCell(
                                            cellText(info2.isEmpty ? '—' : info2, maxW: 220),
                                            onTap: () => widget.onVehicleTap?.call(
                                              placas2,
                                              {'Placas': placas2, 'InfoVehiculo': info2, 'Ciudad': ciudad},
                                            ),
                                          );
                                        }
                                        case 'supervisor_name': {
                                          final canFollow = _isMapFollowableStatus(status);
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow
                                                  ? 'Seleccionar viaje y abrir supervisor (seguirá al conductor si está activo)'
                                                  : 'Seleccionar viaje · Ubicación no disponible (viaje inactivo)',
                                              child: cellText(
                                                supName.isEmpty ? '—' : supName,
                                                maxW: 180,
                                                style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            onTap: () {
                                              // 1) Selección (y follow si el viaje está activo)
                                              _toggleRowSelection(context, tripId, driverId, m);

                                              // 2) Navegar al supervisor (si hay identificador)
                                              final id = supId.isNotEmpty ? supId : supName;
                                              if (id.isEmpty) return;
                                              widget.onSupervisorTap?.call(id, {
                                                'Ciudad': ciudad,
                                                'Número de teléfono': supPhone,
                                              });
                                            },
                                          );
                                        }
                                        case 'supervisor_phone': {
                                          final canFollow = _isMapFollowableStatus(status);
                                          return DataCell(
                                            Tooltip(
                                              message: canFollow
                                                  ? 'Seleccionar viaje y abrir supervisor (seguirá al conductor si está activo)'
                                                  : 'Seleccionar viaje · Ubicación no disponible (viaje inactivo)',
                                              child: cellText(
                                                supPhone.isEmpty ? '—' : supPhone,
                                                maxW: 140,
                                                style: canFollow ? null : const TextStyle(color: Colors.black45, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            onTap: () {
                                              _toggleRowSelection(context, tripId, driverId, m); // ← pasa context
                                              final id = supId.isNotEmpty ? supId : supName;
                                              if (id.isEmpty) return;
                                              widget.onSupervisorTap?.call(id, {
                                                'Ciudad': ciudad,
                                                'Número de teléfono': supPhone,
                                              });
                                            },
                                          );
                                        }
                                        default:
                                          final raw = m[key];

                                          // 🔹 considera emergency_location como campo de coordenadas
                                          final bool isCoords   = key.endsWith('_coords') || key == 'emergency_location';
                                          final bool isTimeLike = key.endsWith('_at');

                                          final value = isTimeLike ? fmtValue(raw) : (raw ?? '').toString();

                                          double? w;
                                          if (RegExp(r'^stop\d+$').hasMatch(key)) w = 220;
                                          if (isCoords) w = 180;
                                          if (RegExp(r'^(on_stop_way|stop_reached)_(\d+)(_at)?$').hasMatch(key)) {
                                            w = isTimeLike ? 150 : 130;
                                          }

                                          if (isCoords) {
                                            final coords = value.trim();
                                            final ll = coords.isEmpty ? null : _parseLatLng(coords);
                                            final enabled = ll != null;

                                            // 🔴 rojo solo para emergency_location, 🔵 azul para el resto
                                            final Color chipColor = (key == 'emergency_location') ? Colors.red : Colors.blue;

                                            return DataCell(
                                              _StatusChip(
                                                text: enabled ? coords : '—',
                                                color: chipColor,
                                                onTap: !enabled ? null : () {
                                                  setState(() => _selectedTripId = tripId);

                                                  final f = widget.selectedMapFocus.value;
                                                  final sameFocus = f != null && f.tripId == tripId && f.key == key;
                                                  if (sameFocus) {
                                                    widget.selectedMapFocus.value = null;
                                                    return;
                                                  }

                                                  widget.selectedMapFocus.value = MapFocus(
                                                    tripId: tripId,
                                                    key: key,
                                                    target: ll,
                                                    title: _labelFromKey(key), // mostrará “Ubicación de emergencia”
                                                    snippet: ciudad,
                                                  );
                                                },
                                              ),
                                            );
                                          }

                                          return DataCell(
                                            cellText(value.isEmpty ? '—' : value, maxW: w),
                                            onTap: () => _toggleRowSelection(context, tripId, driverId, m),
                                          );
                                      }
                                    }

                                    final isSelected = _selectedTripId == tripId;

                                    return DataRow(
                                      key: ValueKey(tripId),                    // key estable
                                      selected: isSelected,                     // ahora sí, por tripId
                                      onSelectChanged: null,                    // sin checkbox
                                      color: WidgetStateProperty.resolveWith<Color?>(
                                        (states) => isSelected ? const Color(0xFF95BD40) : null,
                                      ),
                                      cells: tableKeys.map(buildCell).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String region;
  final ShiftWindow window;

  // Personalización
  final Color? backgroundColor;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? titleStyle;   // “Monitor de viajes · …”
  final TextStyle? infoStyle;    // “Turno: … – …”

  const _Header({
    required this.region,
    required this.window,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.titleStyle,
    this.infoStyle,
  });

  @override
  Widget build(BuildContext context) {
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      color: backgroundColor ?? Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.list_alt, color: iconColor ?? Colors.white, size: iconSize ?? 18),
          const SizedBox(width: 8),
          Text(
            'Monitor de viajes · $region',
            style: titleStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
          const SizedBox(width: 12),
          Text(
            'Turno: ${hhmm(window.start)} – ${hhmm(window.end)}',
            style: infoStyle ??
                const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback? onTap;

  const _StatusChip({
    required this.text,
    this.color,
    this.onTap,
  });

  Color _bg() {
    if (color != null) return color!;
    final t = text.toLowerCase();
    if (t.contains('disponible') || t.contains('progreso')) return const Color(0xFF95BD40);
    if (t.contains('no disponible') || t.contains('cancel')) return const Color(0xFFD9534F);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );

    if (onTap == null) return chip;

    // Toque con ripple
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: chip,
      ),
    );
  }
}