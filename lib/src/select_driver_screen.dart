import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'home_screen.dart';
import 'vehicle_selection_screen.dart';

class SelectDriverScreen extends StatefulWidget {
  final Map<dynamic, dynamic> tripRequest;
  final bool isSupervisor;
  final String region;
  final bool preassignMode;

  const SelectDriverScreen({
    super.key,
    required this.tripRequest,
    required this.isSupervisor,
    required this.region,
    this.preassignMode = false,
  });

  @override
  SelectDriverScreenState createState() => SelectDriverScreenState();
}

class SelectDriverScreenState extends State<SelectDriverScreen> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  final Logger _logger = Logger();
  String? _userCity;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _selectedDriver;
  Map<String, dynamic>? _selectedDriver2;
  bool _isSelectingSecondDriver = false;

  @override
  void initState() {
    super.initState();
    _fetchUserCityAndDrivers();
    if (widget.preassignMode) {
      _prefillFromPreassigned();
    }
  }

  Future<void> _fetchUserCityAndDrivers() async {
    _logger.i('Fetching city for user: ${widget.tripRequest['userId']}');
    try {
      // Fetch user city
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
          .collection('Usuarios')
          .doc(widget.tripRequest['userId'])
          .get();

      if (userDoc.exists) {
        _userCity = userDoc.data()?['Ciudad']?.toLowerCase();
        _logger.i('User city: $_userCity');
        _fetchAvailableDrivers();
      } else {
        _logger.w('User document does not exist');
      }
    } catch (error) {
      _logger.e('Error fetching user city: $error');
    }
  }

  Future<void> _fetchAvailableDrivers() async {
    if (_userCity == null) {
      _logger.w('User city is null, skipping driver fetch');
      return;
    }

    _logger.i('Fetching available drivers');
    try {
      QuerySnapshot<Map<String, dynamic>> driversSnapshot = await FirebaseFirestore.instance
          .collection('Conductores')
          .where('Estatus', isEqualTo: 'disponible')
          .where('Viaje', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> drivers = driversSnapshot.docs.map((doc) {
        Map<String, dynamic> driver = doc.data();
        driver['id'] = doc.id;
        return driver;
      }).where((driver) => driver['Ciudad']?.toLowerCase() == _userCity).toList();

      _logger.i('Available drivers: ${drivers.map((d) => d['NombreConductor']).toList()}');

      setState(() {
        _drivers = drivers;
        _filteredDrivers = drivers; // Inicializa la lista filtrada
      });
    } catch (error) {
      _logger.e('Error fetching drivers: $error');
      setState(() {
        _drivers = [];
        _filteredDrivers = [];
      });
    }
  }

  void _filterDrivers(String query) {
    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredDrivers = _drivers.where((driver) {
        final city = driver['Ciudad']?.toLowerCase() ?? '';
        final plates = driver['Placas']?.toLowerCase() ?? '';
        final vehicleInfo = driver['InfoVehiculo']?.toLowerCase() ?? '';
        final driverName = driver['NombreConductor']?.toLowerCase() ?? '';
        return city.contains(lowerCaseQuery) ||
            plates.contains(lowerCaseQuery) ||
            vehicleInfo.contains(lowerCaseQuery) ||
            driverName.contains(lowerCaseQuery);
      }).toList();
    });
  }

  void _assignDriver(String driverId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> driverDoc =
          await FirebaseFirestore.instance.collection('Conductores').doc(driverId).get();

      if (!driverDoc.exists) {
        _logger.e('Error: El documento del conductor no existe.');
        return;
      }

      Map<String, dynamic>? driverData = driverDoc.data();
      driverData?['id'] = driverId;
      String telefonoConductor = driverData?["NumeroTelefono"] ?? "No disponible";

      setState(() {
        if (_selectedDriver == null) {
          _selectedDriver = {
            "id": driverId,
            "NombreConductor": driverData?["NombreConductor"] ?? "Desconocido",
            "TelefonoConductor": telefonoConductor,
            "InfoVehiculo": driverData?["InfoVehiculo"] ?? "",
            "Placas": driverData?["Placas"] ?? "",
          };
        } else if (_selectedDriver2 == null && _selectedDriver!["id"] != driverId) {
          _selectedDriver2 = {
            "id": driverId,
            "NombreConductor": driverData?["NombreConductor"] ?? "Desconocido",
            "TelefonoConductor": telefonoConductor,
            "InfoVehiculo": driverData?["InfoVehiculo"] ?? "",
            "Placas": driverData?["Placas"] ?? "",
          };
          _isSelectingSecondDriver = false;
        }
      });

      _logger.i('Conductor seleccionado: ${driverData?["NombreConductor"]}');
    } catch (error) {
      _logger.e('Error al seleccionar conductor: $error');
    }
  }

  Widget _driverAvatar(dynamic fotoField) {
    final url = (fotoField ?? '').toString().trim();
    final ok = Uri.tryParse(url)?.hasScheme == true; // https/http válido

    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.grey.shade200,
      child: ok
          ? ClipOval(
              child: Image.network(
                url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                // Si la URL existe pero devuelve HTML/404, caemos aquí y no crashea
                errorBuilder: (_, err, __) {
                  debugPrint('❌ FotoPerfil inválida: "$url" · $err');
                  return const Icon(Icons.person, color: Colors.grey);
                },
              ),
            )
          : const Icon(Icons.person, color: Colors.grey),
    );
  }

  Future<void> _openVehicleSelector(Map<String, dynamic> driver) async {
    final String driverId = (driver['id'] ?? '').toString();

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleSelectionScreen(
          driverId: driverId,
          region: widget.region,
          userCity: _userCity,                           // si ya la tienes calculada
          currentVehicleId: (driver['vehicleId'] ?? ''), // opcional
        ),
      ),
    );

    // Si el usuario confirmó un vehículo, refrescamos la UI local
    if (result != null) {
      final newVid = (result['vehicleId'] ?? '').toString();
      final placas = (result['Placas'] ?? '').toString();
      final info   = (result['InfoVehiculo'] ?? '').toString();

      setState(() {
        void apply(Map<String, dynamic> d) {
          d['vehicleId']    = newVid;
          d['Placas']       = placas;
          d['InfoVehiculo'] = info;
        }

        for (final d in _drivers)         { if ((d['id'] ?? '') == driverId) apply(d); }
        for (final d in _filteredDrivers) { if ((d['id'] ?? '') == driverId) apply(d); }

        if (_selectedDriver  != null && (_selectedDriver!['id']  ?? '') == driverId) apply(_selectedDriver!);
        if (_selectedDriver2 != null && (_selectedDriver2!['id'] ?? '') == driverId) apply(_selectedDriver2!);
      });
    }
  }

  void _prefillFromPreassigned() {
    final m = widget.tripRequest;
    final d1 = (m['preassigned_driver'] ?? '').toString().trim();
    final d2 = (m['preassigned_driver2'] ?? '').toString().trim();

    if (d1.isNotEmpty) {
      _selectedDriver = {
        "id": d1,
        "NombreConductor": m['preassigned_driver_name'] ?? '',
        "TelefonoConductor": m['preassigned_driver_phone'] ?? '',
        "InfoVehiculo": m['preassigned_vehicle_info'] ?? '',
        "Placas": m['preassigned_vehicle_plates'] ?? '',
      };
      setState(() {});
    }
    if (d2.isNotEmpty) {
      _selectedDriver2 = {
        "id": d2,
        "NombreConductor": m['preassigned_driver2_name'] ?? '',
        "TelefonoConductor": m['preassigned_driver2_phone'] ?? '',
        "InfoVehiculo": m['preassigned_vehicle2_info'] ?? '',
        "Placas": m['preassigned_vehicle2_plates'] ?? '',
      };
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Solicitud #${widget.tripRequest['id']}: '
          '${widget.preassignMode ? 'Preasignar conductor' : 'Selección de conductor'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(152, 192, 131, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conductores disponibles:',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, ciudad, vehículo o placas...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onChanged: (value) {
                  _filterDrivers(value);
                },
              ),
            ),
            Expanded(
              child: _filteredDrivers.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay conductores disponibles.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredDrivers.length,
                      itemBuilder: (context, index) {
                        final driver = _filteredDrivers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: _driverAvatar(driver['FotoPerfil']),
                            title: Text(
                              'Nombre conductor: ${driver['NombreConductor']}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Ubicación: ${driver['Ciudad']}  Info. del vehículo: ${driver['InfoVehiculo']}  Placas: ${driver['Placas']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: ElevatedButton(
                              onPressed: (_selectedDriver == null ||
                                          (_isSelectingSecondDriver &&
                                          _selectedDriver2 == null &&
                                          _selectedDriver!["id"] != driver['id']))
                                  ? () => _assignDriver(driver['id'])
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                              child: const Text(
                                'Asignar conductor',
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selectedDriver != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(
                    'Conductor seleccionado: ${_selectedDriver!["NombreConductor"]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Teléfono: ${_selectedDriver!["TelefonoConductor"]}\n'
                    'Vehículo: ${_selectedDriver!["InfoVehiculo"]} · Placas: ${_selectedDriver!["Placas"]}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _openVehicleSelector(_selectedDriver!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF5A96C8)),
                      foregroundColor: const Color(0xFF5A96C8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    ),
                    child: const Text('Cambiar vehículo'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_selectedDriver2 != null) ...[
              const SizedBox(height: 10),
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: Text(
                    'Segundo conductor: ${_selectedDriver2!["NombreConductor"]}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Teléfono: ${_selectedDriver2!["TelefonoConductor"]}\n'
                    'Vehículo: ${_selectedDriver2!["InfoVehiculo"]} · Placas: ${_selectedDriver2!["Placas"]}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _openVehicleSelector(_selectedDriver2!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    ),
                    child: const Text('Cambiar vehículo'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_selectedDriver != null) ...[
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDriver = null;
                    _selectedDriver2 = null; // Se resetea también el segundo conductor
                    _filteredDrivers = List.from(_drivers); // Reactivar la lista de conductores
                    _isSelectingSecondDriver = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  "Cancelar selección",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_selectedDriver != null && _selectedDriver2 == null && !_isSelectingSecondDriver) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                  "Añadir otro conductor",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  setState(() {
                    _isSelectingSecondDriver = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectedDriver == null
                  ? null
                  : () async {
                      try {
                        final tripRef = FirebaseDatabase.instance
                            .ref()
                            .child('trip_requests')
                            .child(widget.tripRequest['id']);

                        final snapshot = await tripRef.get();
                        if (!snapshot.exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("El viaje ya no existe en la base de datos.")),
                          );
                          return;
                        }

                        final tripData = snapshot.value as Map;
                        final currentStatus = tripData['status'];
                        final hasDriver = tripData.containsKey('driver') &&
                            (tripData['driver']?.toString().isNotEmpty ?? false);

                        // Datos comunes a guardar (conductor/es + vehículo/s)
                        final Map<String, dynamic> updateData = {
                          'driver': _selectedDriver!["id"],
                          'driverName': _selectedDriver!["NombreConductor"],
                          'TelefonoConductor': _selectedDriver!["TelefonoConductor"],
                          'vehiclePlates': _selectedDriver!["Placas"] ?? '',
                          'vehicleInfo':   _selectedDriver!["InfoVehiculo"] ?? '',
                        };

                        if (_selectedDriver2 != null) {
                          updateData.addAll({
                            'driver2': _selectedDriver2!["id"],
                            'driver2Name': _selectedDriver2!["NombreConductor"],
                            'TelefonoConductor2': _selectedDriver2!["TelefonoConductor"],
                            'vehicle2Plates': _selectedDriver2!["Placas"] ?? '',
                            'vehicle2Info':   _selectedDriver2!["InfoVehiculo"] ?? '',
                          });
                        }

                        if (widget.preassignMode) {
                        // ✅ Guardar SOLO como preasignación, sin tocar status ni Firestore.Viaje
                        final preassign = <String, dynamic>{
                          'preassigned_driver': _selectedDriver!["id"],
                          'preassigned_driver_name': _selectedDriver!["NombreConductor"],
                          'preassigned_driver_phone': _selectedDriver!["TelefonoConductor"],
                          'preassigned_vehicle_plates': _selectedDriver!["Placas"] ?? '',
                          'preassigned_vehicle_info':   _selectedDriver!["InfoVehiculo"] ?? '',
                          if (_selectedDriver2 != null) ...{
                            'preassigned_driver2': _selectedDriver2!["id"],
                            'preassigned_driver2_name': _selectedDriver2!["NombreConductor"],
                            'preassigned_driver2_phone': _selectedDriver2!["TelefonoConductor"],
                            'preassigned_vehicle2_plates': _selectedDriver2!["Placas"] ?? '',
                            'preassigned_vehicle2_info':   _selectedDriver2!["InfoVehiculo"] ?? '',
                          } else ...{
                            // (opcional) limpia por si existían datos de una preasignación anterior
                            'preassigned_driver2': null,
                            'preassigned_driver2_name': null,
                            'preassigned_driver2_phone': null,
                            'preassigned_vehicle2_plates': null,
                            'preassigned_vehicle2_info': null,
                          },

                          // (opcional) asegúrate de no dejar canónicos si accidentalmente se guardaron antes
                          'driver': null,
                          'driverName': null,
                          'TelefonoConductor': null,
                          'vehiclePlates': null,
                          'vehicleInfo': null,
                        };

                        await tripRef.update(preassign);

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Conductor(es) preasignado(s).")),
                        );
                        Navigator.pop(context, true); // <- volver a ScheduledTripScreen
                        return;
                      }

                        // 🌐 FLUJO NORMAL (no preassign): mismo comportamiento de antes
                        if (currentStatus == 'in progress' && hasDriver) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Este viaje ya tiene un conductor asignado.")),
                          );
                          return;
                        }

                        // Marcar conductores como ocupados en Firestore
                        await FirebaseFirestore.instance
                            .collection('Conductores')
                            .doc(_selectedDriver!["id"])
                            .update({'Viaje': true});

                        if (_selectedDriver2 != null) {
                          await FirebaseFirestore.instance
                              .collection('Conductores')
                              .doc(_selectedDriver2!["id"])
                              .update({'Viaje': true});
                        }

                        // Viaje a in progress y guardar datos
                        await tripRef.update({
                          ...updateData,
                          'status': 'in progress',
                          'started_at': DateTime.now().toIso8601String(),
                        });

                        _logger.i('Conductores asignados correctamente.');

                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(
                              usuario: widget.tripRequest['userId'],
                              isSupervisor: widget.isSupervisor,
                              region: widget.region,
                            ),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      } catch (error) {
                        _logger.e('Error al asignar los conductores: $error');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Ocurrió un error al asignar el conductor.")),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.preassignMode ? Colors.orange : Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              ),
              child: Text(
                widget.preassignMode ? 'Preasignar y volver' : 'Asignar y Continuar',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}