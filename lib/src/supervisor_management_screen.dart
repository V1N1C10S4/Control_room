import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_supervisor_screen.dart';
import 'update_supervisor_screen.dart';

class SupervisorManagementScreen extends StatefulWidget {
  final String usuario;
  final String region;

  const SupervisorManagementScreen({
    super.key,
    required this.usuario,
    required this.region,
  });

  @override
  State<SupervisorManagementScreen> createState() => _SupervisorManagementScreenState();
}

class _SupervisorManagementScreenState extends State<SupervisorManagementScreen> {
  final Color _brand = const Color.fromRGBO(120, 170, 90, 1);
  late final StreamSubscription<QuerySnapshot> _sub;
  List<QueryDocumentSnapshot> _all = [];
  List<QueryDocumentSnapshot> _filtered = [];
  String _search = "";

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.collection('Supervisores').snapshots().listen((snapshot) {
      _all = snapshot.docs.where((doc) {
        final data = doc.data();
        final ciudad = (data['Ciudad'] ?? '').toString().toLowerCase();
        return ciudad == widget.region.toLowerCase();
      }).toList();
      _applySearch();
      if (mounted) setState(() {});
    });
  }

  void _applySearch() {
    if (_search.isEmpty) {
      _filtered = _all;
      return;
    }
    _filtered = _all.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id.toLowerCase();
      final ciudad = (data['Ciudad'] ?? '').toString().toLowerCase();
      final tel = (data['Número de teléfono'] ?? '').toString().toLowerCase();
      return id.contains(_search) || ciudad.contains(_search) || tel.contains(_search);
    }).toList();
  }

  void _confirmAndDelete(String supervisorId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Deseas eliminar este supervisor? Esta acción no se puede deshacer.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await FirebaseFirestore.instance.collection('Supervisores').doc(supervisorId).delete();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Supervisor eliminado exitosamente.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al eliminar el supervisor: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Supervisores', style: TextStyle(color: Colors.white)),
        backgroundColor: _brand,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar supervisores...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (q) {
                _search = q.toLowerCase();
                _applySearch();
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No se encontraron supervisores.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final doc = _filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final foto = (data['FotoPerfil'] ?? '').toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (foto.isNotEmpty) ? NetworkImage(foto) : null,
                            child: (foto.isEmpty) ? const Icon(Icons.person) : null,
                          ),
                          title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Ciudad: ${data['Ciudad'] ?? 'Sin Ciudad'}\n'
                            'Teléfono: ${data['Número de teléfono'] ?? 'Sin Teléfono'}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UpdateSupervisorScreen(
                                        usuario: widget.usuario,
                                        supervisorId: doc.id,
                                        supervisorData: data,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
                                child: const Text('Detalles'),
                              ),
                              ElevatedButton(
                                onPressed: () => _confirmAndDelete(doc.id),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Eliminar supervisor'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'supervisor_creation',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateSupervisorScreen(usuario: widget.usuario, region: widget.region),
            ),
          );
        },
        backgroundColor: _brand,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Crear Supervisor',
      ),
    );
  }
}
