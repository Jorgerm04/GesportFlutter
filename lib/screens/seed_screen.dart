import 'package:flutter/material.dart';
import 'package:gesport/services/seed_service.dart';

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  final _service = SeedService();

  bool _isRunning = false;
  String? _message;
  bool _isError = false;

  Future<void> _runSeed() async {
    setState(() {
      _isRunning = true;
      _message = null;
    });
    try {
      final result = await _service.seedAll();
      setState(() => _message = result);
    } catch (e) {
      setState(() {
        _message = '❌ Error al cargar datos:\n$e';
        _isError = true;
      });
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _runClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1A2F),
        title: const Text('¿Borrar todos los datos?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se eliminarán TODOS los documentos de usuarios, pistas, equipos y reservas. Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Borrar todo',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRunning = true;
      _message = null;
      _isError = false;
    });
    try {
      final result = await _service.clearAll();
      setState(() => _message = result);
    } catch (e) {
      setState(() {
        _message = '❌ Error al borrar datos:\n$e';
        _isError = true;
      });
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Datos de prueba',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                              Colors.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.dataset_rounded,
                                color: Colors.blueAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Cargar datos de prueba',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('Solo para desarrollo',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      const Text('Se insertarán los siguientes datos:',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 10),
                      _dataRow(Icons.people_alt_rounded,
                          '15 usuarios', Colors.blueAccent,
                          '10 jugadores · 3 entrenadores · 2 árbitros'),
                      _dataRow(Icons.stadium_rounded,
                          '10 pistas', Colors.redAccent,
                          'Pádel · Fútbol · Baloncesto · Tenis · Voley'),
                      _dataRow(Icons.groups_rounded,
                          '3 equipos', Colors.orangeAccent,
                          'Con entrenador y jugadores asignados'),
                      _dataRow(Icons.event_available_rounded,
                          '8 reservas', Colors.greenAccent,
                          '3 pasadas confirmadas · 5 futuras'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Resultado ────────────────────────────────────────
                if (_message != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_isError ? Colors.redAccent : Colors.greenAccent)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                        (_isError ? Colors.redAccent : Colors.greenAccent)
                            .withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),

                if (_message != null) const SizedBox(height: 24),

                // ── Botón seed ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runSeed,
                    icon: _isRunning
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.upload_rounded,
                        color: Colors.white),
                    label: Text(
                      _isRunning ? 'Cargando datos...' : 'Cargar datos de prueba',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E5CAD),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Botón clear ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isRunning ? null : _runClear,
                    icon: const Icon(Icons.delete_sweep_rounded,
                        color: Colors.redAccent),
                    label: const Text(
                      'Borrar todos los datos',
                      style: TextStyle(
                          color: Colors.redAccent, fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.redAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Aviso ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orangeAccent, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Los usuarios se crean en Firebase Auth y en Firestore con el mismo UID. Contraseña de todos: Gesport2024!\n\nLa sesión del admin no se ve afectada.',
                          style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataRow(
      IconData icon, String title, Color color, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}