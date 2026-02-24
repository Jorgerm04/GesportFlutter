import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gesport/models/booking.dart';
import 'package:gesport/models/court.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/services/booking_service.dart';
import 'package:intl/intl.dart';

class BookingFormScreen extends StatefulWidget {
  final BookingModel? booking;
  // Si viene de la home de un jugador/entrenador, pre-rellena el usuario
  final String? forUserId;
  final String? forUserName;
  final UserRole? forUserRole;

  const BookingFormScreen({
    super.key,
    this.booking,
    this.forUserId,
    this.forUserName,
    this.forUserRole,
  });

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _service   = BookingService();
  final _notasCtrl = TextEditingController();

  bool _isLoading  = false;
  bool _isSaving   = false;
  // true = el formulario lo abre el admin desde el panel
  bool _isAdminMode = true;

  List<Map<String, dynamic>>  _usuarios  = [];
  List<CourtModel>            _allCourts = [];
  // Equipos donde el usuario seleccionado es entrenador (o el admin elige)
  List<Map<String, String>>   _equiposDisponibles = [];

  // Tipo de reserva: individual o de equipo
  bool _esDeEquipo = false;

  // Selecciones
  String?    _selectedUserId;
  String?    _selectedUserName;
  String?    _selectedEquipoId;
  String?    _selectedEquipoNombre;
  CourtType? _selectedSport;
  CourtModel? _selectedCourt;
  DateTime?  _selectedDay;
  int?       _selectedSlotIndex;
  List<_TimeSlot> _slots        = [];
  bool            _loadingSlots = false;

  // Horario: 09:00 – 22:30 en slots de 1h 30min
  static const int _openHour    = 9;
  static const int _closeHour   = 22;
  static const int _closeMinute = 30;
  static const int _slotMinutes = 90;

  bool get isEditing => widget.booking != null;

  List<CourtModel> get _courtsForSport => _selectedSport == null
      ? []
      : _allCourts.where((c) => c.tipo == _selectedSport && c.activa).toList();

  @override
  void initState() {
    super.initState();

    // Determinar si es admin o usuario normal
    if (widget.forUserId != null) {
      _isAdminMode      = false;
      _selectedUserId   = widget.forUserId;
      _selectedUserName = widget.forUserName;
    }

    if (isEditing) {
      final b = widget.booking!;
      _selectedUserId     = b.usuarioId;
      _selectedUserName   = b.usuarioNombre;
      _esDeEquipo         = b.esDeEquipo;
      _selectedEquipoId   = b.equipoId;
      _selectedEquipoNombre = b.equipoNombre;
      _selectedDay        = DateTime(b.fecha.year, b.fecha.month, b.fecha.day);
      _notasCtrl.text     = b.notas ?? '';
    }

    _loadData();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final usersSnap  = await FirebaseFirestore.instance
        .collection('usuarios').get();
    final courtsSnap = await FirebaseFirestore.instance
        .collection('pistas')
        .where('activa', isEqualTo: true)
        .get();

    if (!mounted) return;
    setState(() {
      _usuarios = usersSnap.docs
          .map((d) => {
        'id':   d.id,
        'nombre': d.data()['nombre'] ?? '',
        'rol':  d.data()['rol'] ?? 'jugador',
      })
          .toList();
      _allCourts = courtsSnap.docs
          .map((d) => CourtModel.fromMap(d.id, d.data()))
          .toList();
      _isLoading = false;
    });

    // Cargar equipos del usuario seleccionado
    if (_selectedUserId != null) {
      await _loadEquiposParaUsuario(_selectedUserId!);
    }

    // Restaurar estado si editamos
    if (isEditing) {
      final b = widget.booking!;
      try {
        _selectedCourt = _allCourts.firstWhere((c) => c.id == b.pistaId);
        _selectedSport = _selectedCourt!.tipo;
      } catch (_) {}
      if (_selectedDay != null && _selectedCourt != null) _loadSlots();
      if (mounted) setState(() {});
    }
  }

  /// Carga los equipos donde el userId es entrenador.
  /// Si es admin, carga TODOS los equipos.
  Future<void> _loadEquiposParaUsuario(String userId) async {
    List<Map<String, String>> equipos;
    if (_isAdminMode) {
      final snap = await FirebaseFirestore.instance.collection('equipos').get();
      equipos = snap.docs
          .map((d) => {'id': d.id, 'nombre': d.data()['nombre'] as String? ?? ''})
          .toList();
    } else {
      equipos = await _service.getEquiposComoEntrenador(userId);
    }
    if (mounted) setState(() => _equiposDisponibles = equipos);
  }

  Future<void> _loadSlots() async {
    if (_selectedCourt == null || _selectedDay == null) return;
    setState(() {
      _loadingSlots      = true;
      _slots             = [];
      _selectedSlotIndex = null;
    });

    final bookings = await _service.getCourtBookingsForDay(
        _selectedCourt!.id, _selectedDay!);

    final slots   = <_TimeSlot>[];
    var   current = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day, _openHour);
    final limit   = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
        _closeHour, _closeMinute);

    while (current.isBefore(limit)) {
      final end = current.add(const Duration(minutes: _slotMinutes));
      if (end.isAfter(limit)) break;

      bool    occupied   = false;
      String? occupiedBy;
      for (final b in bookings) {
        if (isEditing && b.id == widget.booking!.id) continue;
        if (current.isBefore(b.fechaFin) && end.isAfter(b.fechaInicio)) {
          occupied   = true;
          occupiedBy = b.usuarioNombre;
          break;
        }
      }

      if (isEditing) {
        final b = widget.booking!;
        if (current.hour   == b.horaInicio.hour &&
            current.minute == b.horaInicio.minute) {
          _selectedSlotIndex = slots.length;
        }
      }

      slots.add(_TimeSlot(
        inicio: current, fin: end,
        occupied: occupied, occupiedBy: occupiedBy,
      ));
      current = end;
    }

    if (mounted) setState(() { _slots = slots; _loadingSlots = false; });
  }

  Future<void> _pickDay() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDay ?? now,
      firstDate:   now,
      lastDate:    now.add(const Duration(days: 90)),
      builder:     (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0E5CAD),
            surface: Color(0xFF0A1A2F),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedDay       = DateTime(picked.year, picked.month, picked.day);
      _selectedSlotIndex = null;
    });
    _loadSlots();
  }

  Future<void> _save() async {
    if (_selectedUserId == null) {
      _showError('Selecciona un usuario'); return;
    }
    if (_esDeEquipo && _selectedEquipoId == null) {
      _showError('Selecciona un equipo'); return;
    }
    if (_selectedCourt == null) {
      _showError('Selecciona una pista'); return;
    }
    if (_selectedDay == null || _selectedSlotIndex == null) {
      _showError('Selecciona un horario disponible'); return;
    }

    final slot = _slots[_selectedSlotIndex!];
    if (slot.occupied) { _showError('Este horario ya está ocupado'); return; }

    setState(() => _isSaving = true);
    try {
      final booking = BookingModel(
        id:            isEditing ? widget.booking!.id : '',
        usuarioId:     _selectedUserId!,
        usuarioNombre: _selectedUserName!,
        pistaId:       _selectedCourt!.id,
        pistaNombre:   _selectedCourt!.nombre,
        fecha:         _selectedDay!,
        horaInicio:    slot.inicio,
        horaFin:       slot.fin,
        cancelada:     isEditing ? widget.booking!.cancelada : false,
        notas:         _notasCtrl.text.trim().isEmpty
            ? null : _notasCtrl.text.trim(),
        creadaPorAdminId: _isAdminMode ? 'admin' : null,
        equipoId:      _esDeEquipo ? _selectedEquipoId   : null,
        equipoNombre:  _esDeEquipo ? _selectedEquipoNombre : null,
      );

      if (isEditing) {
        await _service.updateBooking(booking);
      } else {
        await _service.createBooking(booking);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.redAccent,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Determinar si el usuario actual puede hacer reservas de equipo:
    // admin siempre, entrenador si tiene equipos
    final puedeHacerEquipo = _isAdminMode ||
        (widget.forUserRole == UserRole.entrenador &&
            _equiposDisponibles.isNotEmpty);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Reserva' : 'Nueva Reserva',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation:       0,
        iconTheme:       const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── PASO 0: Usuario (solo admin) ─────────
                if (_isAdminMode) ...[
                  _stepHeader('1', 'Usuario', Icons.person,
                      Colors.blueAccent,
                      done: _selectedUserId != null),
                  const SizedBox(height: 10),
                  _buildUserDropdown(),
                  const SizedBox(height: 24),
                ],

                // ── TIPO DE RESERVA ──────────────────────
                if (puedeHacerEquipo) ...[
                  _stepHeader(
                      _isAdminMode ? '2' : '1',
                      'Tipo de reserva', Icons.category,
                      Colors.tealAccent,
                      done: true),
                  const SizedBox(height: 10),
                  _buildTipoToggle(),
                  const SizedBox(height: 24),

                  // ── Selector de equipo ───────────────
                  if (_esDeEquipo) ...[
                    _stepHeader(
                        _isAdminMode ? '3' : '2',
                        'Equipo', Icons.groups,
                        Colors.cyanAccent,
                        done: _selectedEquipoId != null,
                        locked: _selectedUserId == null && _isAdminMode),
                    const SizedBox(height: 10),
                    if (_equiposDisponibles.isEmpty)
                      _lockedHint(
                          _isAdminMode && _selectedUserId == null
                              ? 'Selecciona un usuario primero'
                              : 'No hay equipos disponibles')
                    else
                      _buildEquipoSelector(),
                    const SizedBox(height: 24),
                  ],
                ],

                // ── DEPORTE ──────────────────────────────
                _stepHeader(
                    _stepNum(puedeHacerEquipo, 'deporte'),
                    'Deporte', Icons.sports, Colors.purpleAccent,
                    done: _selectedSport != null),
                const SizedBox(height: 10),
                _buildSportSelector(),
                const SizedBox(height: 24),

                // ── PISTA ────────────────────────────────
                _stepHeader(
                    _stepNum(puedeHacerEquipo, 'pista'),
                    'Pista', Icons.stadium, Colors.redAccent,
                    done:   _selectedCourt != null,
                    locked: _selectedSport == null),
                const SizedBox(height: 10),
                if (_selectedSport == null)
                  _lockedHint('Selecciona un deporte primero')
                else if (_courtsForSport.isEmpty)
                  _lockedHint(
                      'No hay pistas de ${_selectedSport!.label} disponibles')
                else
                  _buildCourtSelector(),
                const SizedBox(height: 24),

                // ── DÍA ──────────────────────────────────
                _stepHeader(
                    _stepNum(puedeHacerEquipo, 'dia'),
                    'Día', Icons.calendar_today, Colors.orangeAccent,
                    done:   _selectedDay != null,
                    locked: _selectedCourt == null),
                const SizedBox(height: 10),
                if (_selectedCourt == null)
                  _lockedHint('Selecciona una pista primero')
                else
                  _buildDayPicker(),
                const SizedBox(height: 24),

                // ── HORARIO ───────────────────────────────
                _stepHeader(
                    _stepNum(puedeHacerEquipo, 'horario'),
                    'Horario', Icons.schedule, Colors.greenAccent,
                    done:   _selectedSlotIndex != null,
                    locked: _selectedDay == null),
                const SizedBox(height: 10),
                if (_selectedDay == null)
                  _lockedHint('Selecciona un día primero')
                else
                  _buildSlotsGrid(),
                const SizedBox(height: 24),

                // ── NOTAS ────────────────────────────────
                TextFormField(
                  controller: _notasCtrl,
                  maxLines:   3,
                  style:      const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText:  'Notas (opcional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.notes, color: Colors.white70),
                    filled:     true,
                    fillColor:  Colors.white.withOpacity(0.05),
                    border:     OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:   BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                // ── BOTÓN GUARDAR ────────────────────────
                SizedBox(
                  width:  double.infinity,
                  height: 52,
                  child:  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E5CAD),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                        isEditing ? 'Guardar Cambios' : 'Crear Reserva',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Número de paso dinámico ───────────────────────────────────────────────

  String _stepNum(bool puedeEquipo, String paso) {
    // Pasos base cuando no hay modo equipo visible
    final baseMap = {
      'deporte': _isAdminMode ? '2' : '1',
      'pista':   _isAdminMode ? '3' : '2',
      'dia':     _isAdminMode ? '4' : '3',
      'horario': _isAdminMode ? '5' : '4',
    };
    // Pasos cuando hay toggle de equipo (y posible selector de equipo)
    final equipoMap = {
      'deporte': _isAdminMode
          ? (_esDeEquipo ? '4' : '3')
          : (_esDeEquipo ? '3' : '2'),
      'pista':   _isAdminMode
          ? (_esDeEquipo ? '5' : '4')
          : (_esDeEquipo ? '4' : '3'),
      'dia':     _isAdminMode
          ? (_esDeEquipo ? '6' : '5')
          : (_esDeEquipo ? '5' : '4'),
      'horario': _isAdminMode
          ? (_esDeEquipo ? '7' : '6')
          : (_esDeEquipo ? '6' : '5'),
    };
    return puedeEquipo ? equipoMap[paso]! : baseMap[paso]!;
  }

  // ── Toggle tipo reserva ───────────────────────────────────────────────────

  Widget _buildTipoToggle() {
    return Row(children: [
      _tipoChip('Individual', Icons.person, !_esDeEquipo, () {
        setState(() {
          _esDeEquipo           = false;
          _selectedEquipoId     = null;
          _selectedEquipoNombre = null;
        });
      }),
      const SizedBox(width: 10),
      _tipoChip('Equipo', Icons.groups, _esDeEquipo, () async {
        setState(() {
          _esDeEquipo           = true;
          _selectedEquipoId     = null;
          _selectedEquipoNombre = null;
        });
        // Si el admin ya eligió usuario, cargar sus equipos
        if (_isAdminMode && _selectedUserId != null) {
          await _loadEquiposParaUsuario(_selectedUserId!);
        }
      }),
    ]);
  }

  Widget _tipoChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    final color = selected ? Colors.tealAccent : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? Colors.tealAccent.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? Colors.tealAccent
                  : Colors.white.withOpacity(0.1),
              width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize:   14)),
        ]),
      ),
    );
  }

  // ── Selector de equipo ────────────────────────────────────────────────────

  Widget _buildEquipoSelector() {
    return Column(
      children: _equiposDisponibles.map((eq) {
        final selected = _selectedEquipoId == eq['id'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedEquipoId     = eq['id'];
            _selectedEquipoNombre = eq['nombre'];
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin:   const EdgeInsets.only(bottom: 10),
            padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.cyanAccent.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Colors.cyanAccent
                    : Colors.white.withOpacity(0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.groups,
                  color: selected ? Colors.cyanAccent : Colors.white38,
                  size:  22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(eq['nombre']!,
                    style: TextStyle(
                        color:      selected ? Colors.white : Colors.white70,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize:   14)),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: Colors.cyanAccent, size: 18),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Selector de deporte ───────────────────────────────────────────────────

  Widget _buildSportSelector() {
    final availableSports = CourtType.values
        .where((t) => _allCourts.any((c) => c.tipo == t && c.activa))
        .toList();

    return Wrap(
      spacing: 10, runSpacing: 10,
      children: availableSports.map((sport) {
        final selected = _selectedSport == sport;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedSport     = sport;
            _selectedCourt     = null;
            _selectedDay       = null;
            _selectedSlotIndex = null;
            _slots             = [];
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.purpleAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.purpleAccent : Colors.white.withOpacity(0.1),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_sportIcon(sport), size: 18,
                  color: selected ? Colors.purpleAccent : Colors.white54),
              const SizedBox(width: 8),
              Text(sport.label,
                  style: TextStyle(
                      color:      selected ? Colors.purpleAccent : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize:   14)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Selector de pista ─────────────────────────────────────────────────────

  Widget _buildCourtSelector() {
    return Column(
      children: _courtsForSport.map((court) {
        final selected = _selectedCourt?.id == court.id;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedCourt     = court;
            _selectedDay       = null;
            _selectedSlotIndex = null;
            _slots             = [];
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin:   const EdgeInsets.only(bottom: 10),
            padding:  const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.redAccent.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.redAccent : Colors.white.withOpacity(0.08),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.stadium,
                  color: selected ? Colors.redAccent : Colors.white38, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(court.nombre,
                      style: TextStyle(
                          color:      selected ? Colors.white : Colors.white70,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize:   14)),
                  if (court.descripcion.isNotEmpty)
                    Text(court.descripcion,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Text('${court.precioPorHora.toStringAsFixed(0)}€/h',
                  style: TextStyle(
                      color:      selected ? Colors.redAccent : Colors.white38,
                      fontSize:   12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.redAccent, size: 18),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Selector de día ───────────────────────────────────────────────────────

  Widget _buildDayPicker() {
    final fmt = DateFormat('EEEE d \'de\' MMMM', 'es');
    return GestureDetector(
      onTap: _pickDay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedDay != null
              ? Colors.orangeAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDay != null
                ? Colors.orangeAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              color: _selectedDay != null ? Colors.orangeAccent : Colors.white38,
              size:  20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedDay != null
                  ? _capitalize(fmt.format(_selectedDay!))
                  : 'Toca para seleccionar el día',
              style: TextStyle(
                  color:    _selectedDay != null ? Colors.white : Colors.white38,
                  fontSize: 14),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  // ── Grid de slots ─────────────────────────────────────────────────────────

  Widget _buildSlotsGrid() {
    if (_loadingSlots) {
      return Container(
        height: 80, alignment: Alignment.center,
        child: const CircularProgressIndicator(
            color: Colors.white38, strokeWidth: 2),
      );
    }
    if (_slots.isEmpty) {
      return _lockedHint(
          'No hay horarios disponibles (${_openHour}:00 – '
              '${_closeHour}:${_closeMinute.toString().padLeft(2, '0')})');
    }

    final timeFmt = DateFormat('HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _legendDot(Colors.greenAccent, 'Disponible'),
          const SizedBox(width: 16),
          _legendDot(Colors.redAccent, 'Ocupado'),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 10,
            crossAxisSpacing: 10, childAspectRatio: 1.8,
          ),
          itemCount:   _slots.length,
          itemBuilder: (_, i) {
            final slot       = _slots[i];
            final isSelected = _selectedSlotIndex == i;
            final color      = slot.occupied ? Colors.redAccent : Colors.greenAccent;
            return GestureDetector(
              onTap: slot.occupied
                  ? () => _showOccupiedInfo(slot)
                  : () => setState(() => _selectedSlotIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.greenAccent.withOpacity(0.25)
                      : slot.occupied
                      ? Colors.redAccent.withOpacity(0.12)
                      : Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.greenAccent
                        : slot.occupied
                        ? Colors.redAccent.withOpacity(0.5)
                        : Colors.greenAccent.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(timeFmt.format(slot.inicio),
                        style: TextStyle(
                            color:      isSelected ? Colors.greenAccent : color,
                            fontSize:   13, fontWeight: FontWeight.bold)),
                    Text(timeFmt.format(slot.fin),
                        style: TextStyle(
                            color:    (isSelected ? Colors.greenAccent : color)
                                .withOpacity(0.7),
                            fontSize: 11)),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Colors.greenAccent, size: 14),
                  ],
                ),
              ),
            );
          },
        ),
        if (_selectedSlotIndex != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent, size: 18),
              const SizedBox(width: 10),
              Text(
                'Reserva: ${timeFmt.format(_slots[_selectedSlotIndex!].inicio)}'
                    ' — ${timeFmt.format(_slots[_selectedSlotIndex!].fin)}  (1h 30min)',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  void _showOccupiedInfo(_TimeSlot slot) {
    final timeFmt = DateFormat('HH:mm');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${timeFmt.format(slot.inicio)}–${timeFmt.format(slot.fin)} '
              'ocupado por ${slot.occupiedBy ?? "otro usuario"}'),
      backgroundColor: Colors.redAccent,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Dropdown usuario (modo admin) ─────────────────────────────────────────

  Widget _buildUserDropdown() {
    return Container(
      padding:      const EdgeInsets.symmetric(horizontal: 12),
      decoration:   BoxDecoration(
        color:        Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.person, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:         _selectedUserId,
              hint:          const Text('Selecciona un usuario',
                  style: TextStyle(color: Colors.white54)),
              dropdownColor: const Color(0xFF0A1A2F),
              isExpanded:    true,
              style:         const TextStyle(color: Colors.white),
              items: _usuarios.map((u) => DropdownMenuItem(
                value: u['id'] as String,
                child: Text(u['nombre'] as String),
              )).toList(),
              onChanged: (id) async {
                final user = _usuarios.firstWhere((u) => u['id'] == id);
                setState(() {
                  _selectedUserId       = id;
                  _selectedUserName     = user['nombre'];
                  _selectedEquipoId     = null;
                  _selectedEquipoNombre = null;
                  _equiposDisponibles   = [];
                });
                await _loadEquiposParaUsuario(id!);
              },
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _stepHeader(String step, String title, IconData icon, Color color,
      {bool done = false, bool locked = false}) {
    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done   ? color.withOpacity(0.25)
              : locked ? Colors.white10
              : color.withOpacity(0.1),
          border: Border.all(
              color: done ? color : locked ? Colors.white24 : color,
              width: 1.5),
        ),
        child: Center(
          child: done
              ? Icon(Icons.check, color: color, size: 14)
              : Text(step,
              style: TextStyle(
                  color:      locked ? Colors.white24 : color,
                  fontSize:   12,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 16, color: locked ? Colors.white24 : color),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              color:      locked ? Colors.white24 : Colors.white,
              fontSize:   14, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _lockedHint(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child:   Text(text,
        style: const TextStyle(color: Colors.white24, fontSize: 13)),
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color:  color.withOpacity(0.3),
              shape:  BoxShape.circle,
              border: Border.all(color: color))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
    ],
  );

  IconData _sportIcon(CourtType type) {
    switch (type) {
      case CourtType.padel:      return Icons.sports_tennis;
      case CourtType.futbol:     return Icons.sports_soccer;
      case CourtType.baloncesto: return Icons.sports_basketball;
      case CourtType.tenis:      return Icons.sports_tennis;
      case CourtType.voley:      return Icons.sports_volleyball;
      case CourtType.otro:       return Icons.stadium;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Modelo auxiliar de slot ───────────────────────────────────────────────────

class _TimeSlot {
  final DateTime inicio;
  final DateTime fin;
  final bool     occupied;
  final String?  occupiedBy;

  const _TimeSlot({
    required this.inicio,
    required this.fin,
    required this.occupied,
    this.occupiedBy,
  });
}