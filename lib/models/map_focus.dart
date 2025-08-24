import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapFocus {
  final String tripId;
  final String key; // p.ej. pickup_coords / destination_coords / stop3_coords
  final LatLng target; // coordenadas destino del foco
  final String? title; // etiqueta legible p/ InfoWindow
  final String? snippet; // adicional (ciudad u otro)


  const MapFocus({
    required this.tripId,
    required this.key,
    required this.target,
    this.title,
    this.snippet,
  });
}