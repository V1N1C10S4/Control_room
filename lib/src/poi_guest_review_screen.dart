import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PoiGuestReviewScreen extends StatefulWidget {
  final String tripId;
  final String region;

  const PoiGuestReviewScreen({
    super.key,
    required this.tripId,
    required this.region,
  });

  @override
  State<PoiGuestReviewScreen> createState() => _PoiGuestReviewScreenState();
}

class _PoiGuestReviewScreenState extends State<PoiGuestReviewScreen> {
  final _rootRef = FirebaseDatabase.instance.ref();
  bool _loading = true;
  Map<String, dynamic> _requests = {}; // reqId -> { guests:{guestId:{name,status,submitted_at,submitted_by}}, ... }
  final Map<String, Map<String, String>> _decisions = {}; // reqId -> guestId -> status (approved/denied)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tripRef = _rootRef.child('trip_requests/${widget.tripId}');
    final snap = await tripRef.get();
    final data = (snap.value is Map) ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
    final gar = (data['guest_add_requests'] is Map) ? Map<String, dynamic>.from(data['guest_add_requests']) : <String, dynamic>{};

    // Normaliza estructura
    final normalized = <String, dynamic>{};
    gar.forEach((reqId, rawReq) {
      if (rawReq is! Map) return;
      final req = Map<String, dynamic>.from(rawReq);
      final guests = (req['guests'] is Map) ? Map<String, dynamic>.from(req['guests']) : <String, dynamic>{};
      if (guests.isEmpty) return;

      normalized[reqId] = {
        ...req,
        'guests': guests.map((gid, gv) => MapEntry(gid, Map<String, dynamic>.from(gv))),
      };

      // Semilla de decisiones = estado actual (solo los pending quedarán accionables)
      _decisions[reqId] = {};
      guests.forEach((gid, gv) {
        final st = (gv is Map) ? ((gv['status'] ?? '').toString().trim()) : '';
        if (st.isEmpty || st == 'pending') {
          _decisions[reqId]![gid] = 'pending';
        }
      });
    });

    setState(() {
      _requests = normalized;
      _loading  = false;
    });
  }

  // Traducción de estados a etiqueta
  String _poiStatusLabel(String? raw) {
    final s = (raw ?? '').toLowerCase().trim();
    switch (s) {
      case 'approved': return 'Aprobado';
      case 'denied':   return 'Denegado';
      case 'pending':  return 'Pendiente';
      case 'partial':  return 'Parcial';
      default:         return s.isEmpty ? 'Desconocido' : s;
    }
  }

  // Estado agregado de una lista de estados
  String _aggregateStatus(Iterable<String> statuses) {
    bool anyPending = false, anyApproved = false, anyDenied = false;
    for (final s in statuses) {
      final v = s.isEmpty ? 'pending' : s;
      if (v == 'pending') anyPending = true;
      if (v == 'approved') anyApproved = true;
      if (v == 'denied') anyDenied = true;
    }
    if (anyPending) return 'pending';
    if (anyApproved && !anyDenied) return 'approved';
    if (anyDenied && !anyApproved) return 'denied';
    if (anyApproved && anyDenied) return 'partial';
    return 'pending';
  }

  // Agregado global (todas las solicitudes de este viaje)
  String _aggregateGlobal(Map<String, dynamic> requests) {
    final all = <String>[];
    requests.forEach((_, req) {
      final guests = (req['guests'] as Map).values.map((gv) => (gv['status'] ?? '').toString());
      all.addAll(guests);
    });
    // Aplica decisiones locales (lo que el usuario ya eligió en UI)
    _decisions.forEach((reqId, map) {
      map.forEach((guestId, st) {
        if (st == 'approved' || st == 'denied') {
          all.remove('pending'); // redundante; solo para claridad mental
          all.add(st);
        }
      });
    });
    return _aggregateStatus(all);
  }

  Future<void> _applyBulk(String reqId, String toStatus) async {
    setState(() {
      _decisions[reqId] ??= {};
      final req = _requests[reqId] as Map<String, dynamic>;
      final guests = (req['guests'] as Map<String, dynamic>);
      guests.forEach((gid, gv) {
        final st = (gv['status'] ?? '').toString();
        if (st.isEmpty || st == 'pending') {
          _decisions[reqId]![gid] = toStatus; // approved | denied
        }
      });
    });
  }

  Future<void> _save() async {
    final updates = <String, Object?>{};

    // 👉 cuantos aprobamos que ANTES estaban pending
    int deltaApproved = 0;

    // 1) Aplica decisiones a trip_requests y calcula deltaApproved
    _decisions.forEach((reqId, map) {
      map.forEach((guestId, newSt) {
        if (newSt == 'approved' || newSt == 'denied') {
          // paths de cada guest
          final basePath =
              'trip_requests/${widget.tripId}/guest_add_requests/$reqId/guests/$guestId';
          updates['$basePath/status'] = newSt;
          updates['$basePath/reviewed_at'] = ServerValue.timestamp;

          // si aprobamos y el estado original era pending (o vacío) => cuenta para incrementar
          if (newSt == 'approved') {
            final req = _requests[reqId] as Map<String, dynamic>?;
            final guests = (req?['guests'] as Map?) ?? const {};
            final gv = guests[guestId];
            final oldSt = (gv is Map ? (gv['status'] ?? '') : '').toString().trim().toLowerCase();
            if (oldSt.isEmpty || oldSt == 'pending') {
              deltaApproved++;
            }
          }
        }
      });
    });

    // ⬆️ incrementa passengers de forma atómica si hubo aprobaciones nuevas
    if (deltaApproved > 0) {
      updates['trip_requests/${widget.tripId}/passengers'] =
          ServerValue.increment(deltaApproved);
    }

    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios por guardar.')),
      );
      return;
    }

    setState(() => _loading = true);
    await _rootRef.update(updates);

    // ✅ Usa tu helper que ya considera _decisions para el estado agregado
    final overallAgg = _requests.isEmpty
        ? 'approved' // sin solicitudes -> nada pendiente
        : _aggregateGlobal(_requests);

    // 3) Atiende poi_inbox de esta región para este tripId
    final regionKey = widget.region.trim().toUpperCase();
    final inboxRef  = _rootRef.child('poi_inbox/$regionKey');
    final inboxSnap = await inboxRef.get();
    final inboxUpdates = <String, Object?>{};

    if (inboxSnap.value is Map) {
      final m = Map<String, dynamic>.from(inboxSnap.value as Map);
      m.forEach((inboxId, raw) {
        if (raw is! Map) return;
        final x = Map<String, dynamic>.from(raw);
        final status = (x['status'] ?? '').toString();
        final tripId = (x['tripId'] ?? '').toString();
        if (status == 'pending' && tripId == widget.tripId) {
          inboxUpdates['poi_inbox/$regionKey/$inboxId/status'] = overallAgg;
          inboxUpdates['poi_inbox/$regionKey/$inboxId/attended_at'] =
              ServerValue.timestamp;
        }
      });
    }
    if (inboxUpdates.isNotEmpty) {
      await _rootRef.update(inboxUpdates);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deltaApproved > 0
                ? 'Cambios guardados, $deltaApproved pasajero(s) añadido(s), POI atendidos.'
                : 'Cambios guardados y POI atendidos.',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  bool _hasChanges() {
    for (final reqMap in _decisions.values) {
      for (final v in reqMap.values) {
        if (v == 'approved' || v == 'denied') return true;
      }
    }
    return false;
  }

  Widget _buildSaveButton() {
    final enabled = _hasChanges() && !_loading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Guardar cambios',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  ButtonStyle _outlineBtn(Color c) => OutlinedButton.styleFrom(
    foregroundColor: c,                         // texto/ícono
    side: BorderSide(color: c, width: 1.6),    // borde
    overlayColor: c,         // ripple al presionar
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobación de abordajes (POI)', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No hay solicitudes de abordaje para este viaje.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ..._buildRequestCards(theme),
                    const SizedBox(height: 16),
                    _buildSaveButton(),
                  ],  
                ),
    );
  }

  List<Widget> _buildRequestCards(ThemeData theme) {
    // Ordena solicitudes por la fecha mínima de sus invitados (submitted_at)
    final items = _requests.entries.toList()
      ..sort((a, b) {
        DateTime? minA, minB;
        if (a.value['guests'] is Map) {
          (a.value['guests'] as Map).forEach((_, gv) {
            final s = (gv['submitted_at'] ?? '').toString();
            final dt = DateTime.tryParse(s);
            if (dt != null && (minA == null || dt.isBefore(minA!))) minA = dt;
          });
        }
        if (b.value['guests'] is Map) {
          (b.value['guests'] as Map).forEach((_, gv) {
            final s = (gv['submitted_at'] ?? '').toString();
            final dt = DateTime.tryParse(s);
            if (dt != null && (minB == null || dt.isBefore(minB!))) minB = dt;
          });
        }
        return (minA ?? DateTime.now()).compareTo(minB ?? DateTime.now());
      });

    int idx = 0;
    return items.map((e) {
      idx++;
      final reqId = e.key;
      final req   = e.value as Map<String, dynamic>;
      final guests = Map<String, dynamic>.from(req['guests'] as Map);

      final statuses = guests.values.map((gv) => (gv['status'] ?? '').toString());
      final agg = _aggregateStatus(statuses);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.black12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Text('Solicitud $idx -', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  _labelChip(text: _poiStatusLabel(agg), fontSize: 16),
                  const Spacer(),
                  // Acciones masivas
                  ElevatedButton(
                    onPressed: () => _applyBulk(reqId, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white, // color del texto
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Text('Aprobar pendientes'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _applyBulk(reqId, 'denied'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white, // color del texto
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Text('Denegar pendientes'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Invitados
              ...guests.entries.map((g) {
                final guestId = g.key;
                final gv = Map<String, dynamic>.from(g.value as Map);
                final name = (gv['name'] ?? '').toString();
                final status = (gv['status'] ?? '').toString().trim().isEmpty
                    ? 'pending'
                    : (gv['status'] ?? '').toString();
                final pending = status == 'pending';
                final decided = _decisions[reqId]?[guestId];
                final preview = (decided == 'approved' || decided == 'denied') ? decided! : status;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name.isEmpty ? '(Sin nombre)' : name),
                  subtitle: Text('Estado actual: ${_poiStatusLabel(status)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _labelChip(text: _poiStatusLabel(preview), fontSize: 16),
                      const SizedBox(width: 8),
                      if (pending) ...[
                        OutlinedButton(
                          style: _outlineBtn(Colors.green),
                          onPressed: () {
                            setState(() {
                              _decisions[reqId] ??= {};
                              _decisions[reqId]![guestId] = 'approved';
                            });
                          },
                          child: const Text('Aprobar'),
                        ),

                        const SizedBox(width: 6),

                        OutlinedButton(
                          style: _outlineBtn(Colors.red),
                          onPressed: () {
                            setState(() {
                              _decisions[reqId] ??= {};
                              _decisions[reqId]![guestId] = 'denied';
                            });
                          },
                          child: const Text('Denegar'),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }).toList();
  }
}

Widget _labelChip({
  required String text,
  double fontSize = 12,                 // 👈 tamaño configurable
  Color color = Colors.black,           // opcional
  FontWeight weight = FontWeight.w700,  // opcional (negritas por defecto)
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
}) {
  return Padding(
    padding: padding,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: weight,
        fontSize: fontSize,             // 👈 se aplica aquí
      ),
    ),
  );
}