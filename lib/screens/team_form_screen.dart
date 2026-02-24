import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gesport/models/team.dart';
import 'package:gesport/services/team_service.dart';

class TeamFormScreen extends StatefulWidget {
  final TeamModel? team;
  const TeamFormScreen({super.key, this.team});

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _service = TeamService();

  bool _isLoading = false;
  bool _isLoadingUsers = true;

  List<Map<String, dynamic>> _allCoaches = [];
  List<Map<String, dynamic>> _allPlayers = [];

  String? _selectedCoachId;
  String? _selectedCoachName;
  final Set<String> _selectedPlayerIds = {};

  bool get isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.team!.nombre;
      _descCtrl.text = widget.team!.descripcion;
      _selectedCoachId = widget.team!.entrenadorId;
      _selectedCoachName = widget.team!.entrenadorNombre;
      _selectedPlayerIds.addAll(widget.team!.jugadoresIds);
    }
    _loadUsers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final snap =
    await FirebaseFirestore.instance.collection('usuarios').get();
    final coaches = <Map<String, dynamic>>[];
    final players = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final entry = {
        'id': doc.id,
        'nombre': data['nombre'] ?? 'Sin nombre',
        'email': data['email'] ?? '',
      };
      final rol = data['rol'] ?? 'jugador';
      if (rol == 'entrenador') coaches.add(entry);
      if (rol == 'jugador') players.add(entry);
    }

    if (mounted) {
      setState(() {
        _allCoaches = coaches;
        _allPlayers = players;
        _isLoadingUsers = false;
        if (_selectedCoachId != null &&
            !coaches.any((c) => c['id'] == _selectedCoachId)) {
          _selectedCoachId = null;
          _selectedCoachName = null;
        }
        _selectedPlayerIds
            .removeWhere((id) => !players.any((p) => p['id'] == id));
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final coach = _allCoaches.firstWhere(
          (c) => c['id'] == _selectedCoachId,
      orElse: () => {},
    );

    final team = TeamModel(
      id: isEditing ? widget.team!.id : '',
      nombre: _nameCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      entrenadorId: _selectedCoachId,
      entrenadorNombre:
      coach.isNotEmpty ? coach['nombre'] as String : null,
      jugadoresIds: _selectedPlayerIds.toList(),
    );

    try {
      if (isEditing) {
        await _service.updateTeam(team);
      } else {
        await _service.createTeam(team);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Bottom sheet: entrenador ────────────────────────────────────────────

  void _showCoachPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _sheetHandle(),
          const SizedBox(height: 16),
          const Text('Seleccionar entrenador',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_allCoaches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay entrenadores disponibles.\nAsigna el rol "Entrenador" a un usuario primero.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            )
          else ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white10,
                child: const Icon(Icons.person_off,
                    color: Colors.white38, size: 18),
              ),
              title: const Text('Sin entrenador',
                  style: TextStyle(color: Colors.white54)),
              onTap: () {
                setState(() {
                  _selectedCoachId = null;
                  _selectedCoachName = null;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ..._allCoaches.map((coach) {
              final isSelected = _selectedCoachId == coach['id'];
              return ListTile(
                leading: _avatar(
                    coach['nombre'] as String, Colors.blueAccent,
                    selected: isSelected),
                title: Text(coach['nombre'] as String,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(coach['email'] as String,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                    color: Colors.blueAccent)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCoachId = coach['id'] as String;
                    _selectedCoachName = coach['nombre'] as String;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Bottom sheet: jugadores ─────────────────────────────────────────────

  void _showPlayerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 12),
                _sheetHandle(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Seleccionar jugadores',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setSheet(
                                  () => _selectedPlayerIds.clear());
                          setState(() {});
                        },
                        child: const Text('Limpiar todo',
                            style: TextStyle(color: Colors.white38)),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                if (_allPlayers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay jugadores disponibles.\nAsigna el rol "Jugador" a un usuario primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _allPlayers.length,
                      itemBuilder: (_, i) {
                        final player = _allPlayers[i];
                        final id = player['id'] as String;
                        final selected =
                        _selectedPlayerIds.contains(id);
                        return ListTile(
                          onTap: () {
                            setSheet(() {
                              selected
                                  ? _selectedPlayerIds.remove(id)
                                  : _selectedPlayerIds.add(id);
                            });
                            setState(() {});
                          },
                          leading: _avatar(
                              player['nombre'] as String,
                              Colors.greenAccent,
                              selected: selected),
                          title: Text(player['nombre'] as String,
                              style:
                              const TextStyle(color: Colors.white)),
                          subtitle: Text(player['email'] as String,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          trailing: Checkbox(
                            value: selected,
                            activeColor: Colors.greenAccent,
                            checkColor: Colors.black,
                            side: const BorderSide(
                                color: Colors.white38),
                            onChanged: (val) {
                              setSheet(() {
                                val == true
                                    ? _selectedPlayerIds.add(id)
                                    : _selectedPlayerIds.remove(id);
                              });
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Confirmar · ${_selectedPlayerIds.length} seleccionado${_selectedPlayerIds.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Equipo' : 'Nuevo Equipo',
            style: const TextStyle(color: Colors.white)),
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
          child: _isLoadingUsers
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    validator: (val) =>
                    (val == null || val.isEmpty)
                        ? 'Campo obligatorio'
                        : null,
                    decoration: _fieldDeco(
                        'Nombre del equipo',
                        Icons.groups_rounded),
                  ),
                  const SizedBox(height: 20),

                  // Descripción
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                    _fieldDeco('Descripción (opcional)',
                        Icons.notes),
                  ),
                  const SizedBox(height: 28),

                  // ── Entrenador ──────────────────────────────
                  _sectionLabel('Entrenador',
                      Icons.person_pin, Colors.blueAccent),
                  const SizedBox(height: 10),
                  _SelectorCard(
                    onTap: _showCoachPicker,
                    child: _selectedCoachId == null
                        ? _PlaceholderRow(
                      icon: Icons.person_add_outlined,
                      text: 'Toca para asignar entrenador',
                      color: Colors.blueAccent,
                    )
                        : _SelectedUserRow(
                      name: _selectedCoachName ?? '',
                      color: Colors.blueAccent,
                      onRemove: () => setState(() {
                        _selectedCoachId = null;
                        _selectedCoachName = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Jugadores ───────────────────────────────
                  _sectionLabel('Jugadores',
                      Icons.sports_soccer, Colors.greenAccent),
                  const SizedBox(height: 10),
                  _SelectorCard(
                    onTap: _showPlayerPicker,
                    child: _selectedPlayerIds.isEmpty
                        ? _PlaceholderRow(
                      icon: Icons.group_add_outlined,
                      text:
                      'Toca para añadir jugadores',
                      color: Colors.greenAccent,
                    )
                        : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allPlayers
                          .where((p) =>
                          _selectedPlayerIds
                              .contains(p['id']))
                          .map((p) => RawChip(
                        avatar: CircleAvatar(
                          backgroundColor:
                          Colors.greenAccent
                              .withOpacity(0.25),
                          child: Text(
                            (p['nombre'] as String)[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight:
                                FontWeight.bold),
                          ),
                        ),
                        label: Text(
                          p['nombre'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12),
                        ),
                        backgroundColor:
                        const Color(0xFF1A3050),
                        deleteIcon: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white54),
                        onDeleted: () => setState(
                                () => _selectedPlayerIds
                                .remove(p['id'])),
                        side: BorderSide(
                            color: Colors.greenAccent
                                .withOpacity(0.3)),
                      ))
                          .toList(),
                    ),
                  ),
                  if (_selectedPlayerIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_selectedPlayerIds.length} jugador${_selectedPlayerIds.length == 1 ? '' : 'es'} seleccionado${_selectedPlayerIds.length == 1 ? '' : 's'} · Toca para editar',
                        style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11),
                      ),
                    ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : Text(
                          isEditing
                              ? 'Guardar Cambios'
                              : 'Crear Equipo',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _sheetHandle() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sectionLabel(String text, IconData icon, Color color) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(text,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
    ],
  );

  InputDecoration _fieldDeco(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );

  Widget _avatar(String name, Color color,
      {bool selected = false}) =>
      CircleAvatar(
        backgroundColor: color.withOpacity(selected ? 0.3 : 0.1),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: selected ? color : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      );
}

// ── Widgets reutilizables ────────────────────────────────────────────────────

class _SelectorCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _SelectorCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: child,
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _PlaceholderRow(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.5), size: 22),
        const SizedBox(width: 12),
        Text(text,
            style:
            TextStyle(color: color.withOpacity(0.5), fontSize: 14)),
        const Spacer(),
        const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
      ],
    );
  }
}

class _SelectedUserRow extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onRemove;
  const _SelectedUserRow(
      {required this.name,
        required this.color,
        required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.cancel,
              color: Colors.white38, size: 20),
        ),
      ],
    );
  }
}