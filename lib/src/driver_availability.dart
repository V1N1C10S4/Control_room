import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DriverAvailability extends StatelessWidget {
  final String usuario;
  final String region; // Agregamos el parámetro region

  const DriverAvailability({
    super.key,
    required this.usuario,
    required this.region, // Aseguramos que sea requerido
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conductores Disponibles', style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(110, 191, 137, 1),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Conductores').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> availableDrivers = [];
          List<DocumentSnapshot> unavailableDrivers = [];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final bool isAvailable = data['Estatus'] == 'disponible' &&
                data['Viaje'] == false &&
                data['Ciudad']?.toLowerCase() == region.toLowerCase(); // Filtrar por región

            if (isAvailable) {
              availableDrivers.add(doc);
            } else if (data['Ciudad']?.toLowerCase() == region.toLowerCase()) {
              // Aseguramos que los no disponibles también sean de la región
              unavailableDrivers.add(doc);
            }
          }

          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Conductores disponibles:',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: availableDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = availableDrivers[index].data() as Map<String, dynamic>;
                          final foto = (driver['FotoPerfil'] ?? '').toString().trim();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: const BorderSide(color: Colors.green, width: 2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    (foto.isNotEmpty)
                                      ? CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.transparent,
                                          backgroundImage: CachedNetworkImageProvider(foto),
                                          onBackgroundImageError: (_, __) {}, // solo si hay imagen
                                        )
                                      : const CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.transparent,
                                          child: Icon(Icons.person, size: 40),
                                        ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nombre conductor: ${driver['NombreConductor']}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Ubicación: ${driver['Ciudad']}'),
                                          Text('Info. del vehículo: ${driver['InfoVehiculo']}'),
                                          Text('Placas: ${driver['Placas']}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Conductores no disponibles:',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unavailableDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = unavailableDrivers[index].data() as Map<String, dynamic>;
                          final bool isInProgress = driver['Estatus'] == 'disponible' && driver['Viaje'] == true;
                          final String reason = isInProgress ? 'Viaje en progreso' : 'Fuera de horario laboral';
                          final foto = (driver['FotoPerfil'] ?? '').toString().trim();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: const BorderSide(color: Colors.red, width: 2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.transparent,
                                      backgroundImage: foto.isNotEmpty ? CachedNetworkImageProvider(foto) : null,
                                      // si no hay imagen, mostramos un ícono
                                      child: foto.isEmpty ? const Icon(Icons.person, size: 40) : null,
                                      // evita que un URL roto tire la app; puedes loguear si quieres
                                      onBackgroundImageError: (_, __) {},
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nombre conductor: ${driver['NombreConductor']}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Ubicación: ${driver['Ciudad']}'),
                                          Text('Info. del vehículo: ${driver['InfoVehiculo']}'),
                                          Text('Placas: ${driver['Placas']}'),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                      decoration: BoxDecoration(
                                        color: isInProgress ? Colors.red : Colors.orange,
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        reason,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}