import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gesport/models/booking.dart';
import 'package:gesport/models/court.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/services/booking_service.dart';
import 'package:intl/intl.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/utils/app_utils.dart';

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

  // Tipo de reserva
  TipoReserva _tipoReserva = TipoReserva.individual;
  bool get _esDeEquipo   => _tipoReserva == TipoReserva.equipo;
  bool get _esPartido    => _tipoReserva == TipoReserva.partido;
  bool get _esIndividual => _tipoReserva == TipoReserva.individual;

  // Selecciones comunes
  String?    _selectedUserId;
  String?    _selectedUserName;
  String?    _selectedEquipoId;
  String?    _selectedEquipoNombre;

  // Deporte unificado (equipo y partido comparten el mismo selector)
  String?    _selectedDeporte;

  // Selecciones de partido
  String?    _equipoLocalId;
  String?    _equipoLocalNombre;
  String?    _equipoVisitanteId;
  String?    _equipoVisitanteNombre;
  String?    _arbitroId;
  String?    _arbitroNombre;
  final _puntosLocalCtrl     = TextEditingController();
  final _puntosVisitanteCtrl = TextEditingController();
  List<Map<String, dynamic>> _arbitros = [];
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
      _selectedUserName = widget.forUserName ?? '';
    }

    if (isEditing) {
      final b = widget.booking!;
      _selectedUserId     = b.usuarioId;
      _selectedUserName   = b.usuarioNombre;
      _tipoReserva          = b.tipo;
      _selectedEquipoId     = b.equipoId;
      _selectedEquipoNombre = b.equipoNombre;
      _equipoLocalId        = b.equipoLocalId;
      _equipoLocalNombre    = b.equipoLocalNombre;
      _equipoVisitanteId    = b.equipoVisitanteId;
      _equipoVisitanteNombre = b.equipoVisitanteNombre;
      _arbitroId            = b.arbitroId;
      _arbitroNombre        = b.arbitroNombre;
      _selectedDeporte       = b.deporte;
      if (b.puntosLocal     != null) _puntosLocalCtrl.text     = b.puntosLocal.toString();
      if (b.puntosVisitante != null) _puntosVisitanteCtrl.text = b.puntosVisitante.toString();
      _selectedDay        = DateTime(b.fecha.year, b.fecha.month, b.fecha.day);
      _notasCtrl.text     = b.notas ?? '';
    }

    _loadData();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    _puntosLocalCtrl.dispose();
    _puntosVisitanteCtrl.dispose();
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
      final allUsers = usersSnap.docs
          .map((d) => {
        'id':     d.id,
        'nombre': d.data()['nombre'] ?? '',
        'email':  d.data()['email']  ?? '',
        'rol':    d.data()['rol']    ?? 'jugador',
      })
          .toList();
      _arbitros = allUsers
          .where((u) => u['rol'] == 'arbitro')
          .toList();
      // El selector de usuario individual excluye árbitros
      _usuarios = allUsers
          .where((u) => u['rol'] != 'arbitro')
          .toList();
      _allCourts = courtsSnap.docs
          .map((d) => CourtModel.fromMap(d.id, d.data()))
          .toList();
      _isLoading = false;
    });

    // Admin: cargar todos los equipos al iniciar (no depende del usuario)
    // Entrenador: cargar sus equipos
    if (_isAdminMode || _selectedUserId != null) {
      await _loadEquipos();
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
  /// En admin: carga TODOS los equipos (sin depender de usuario seleccionado).
  /// En entrenador: carga solo sus equipos.
  Future<void> _loadEquipos() async {
    List<Map<String, String>> equipos;
    if (_isAdminMode) {
      final snap = await FirebaseFirestore.instance.collection('equipos').get();
      equipos = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':               d.id,
          'nombre':           data['nombre']           as String? ?? '',
          'entrenadorId':     data['entrenadorId']     as String? ?? '',
          'entrenadorNombre': data['entrenadorNombre'] as String? ?? '',
          'deporte':          data['deporte']          as String? ?? '',
        };
      }).toList();
    } else {
      equipos = await _service.getEquiposComoEntrenador(_selectedUserId!);
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

      final isPast = end.isBefore(DateTime.now());
      slots.add(_TimeSlot(
        inicio: current, fin: end,
        occupied: occupied, occupiedBy: occupiedBy,
        isPast: isPast,
      ));
      current = end;
    }

    if (mounted) setState(() { _slots = slots; _loadingSlots = false; });
  }

  Future<void> _pickDay() async {
    final now    = DateTime.now();
    final minDay = DateTime(now.year, now.month, now.day);
    final maxDay = _isAdminMode
        ? minDay.add(const Duration(days: 365))
        : minDay.add(const Duration(days: 15));
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDay ?? minDay,
      firstDate:   minDay,
      lastDate:    maxDay,
      builder:     (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0E5CAD),
            surface: AppTheme.bg1,
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
    // Validaciones por tipo
    if (_esPartido) {
      if (_selectedDeporte == null)      { _showError('Selecciona el deporte'); return; }
      if (_equipoLocalId == null)       { _showError('Selecciona el equipo local'); return; }
      if (_equipoVisitanteId == null)   { _showError('Selecciona el equipo visitante'); return; }
      if (_equipoLocalId == _equipoVisitanteId) {
        _showError('El equipo local y visitante no pueden ser el mismo'); return;
      }
      if (_arbitroId == null)           { _showError('Selecciona un árbitro'); return; }
    } else {
      if (_isAdminMode && _selectedUserId == null) { _showError('Selecciona un usuario'); return; }
      if (_esDeEquipo && _selectedEquipoId == null) {
        _showError('Selecciona un equipo'); return;
      }
    }
    if (_selectedCourt == null)         { _showError('Selecciona una pista'); return; }
    if (_selectedDay == null || _selectedSlotIndex == null) {
      _showError('Selecciona un horario disponible'); return;
    }

    final slot = _slots[_selectedSlotIndex!];
    if (slot.occupied) { _showError('Este horario ya está ocupado'); return; }

    setState(() => _isSaving = true);
    try {
      final booking = BookingModel(
        id:                    isEditing ? widget.booking!.id : '',
        usuarioId:             _esPartido ? ''
            : _isAdminMode
            ? (_selectedUserId   ?? '')
            : (widget.forUserId  ?? ''),
        usuarioNombre:         _esPartido ? ''
            : _isAdminMode
            ? (_selectedUserName ?? '')
            : (widget.forUserName ?? ''),
        pistaId:               _selectedCourt!.id,
        pistaNombre:           _selectedCourt!.nombre,
        fecha:                 _selectedDay!,
        horaInicio:            slot.inicio,
        horaFin:               slot.fin,
        cancelada:             isEditing ? widget.booking!.cancelada : false,
        notas:                 _notasCtrl.text.trim().isEmpty
            ? null : _notasCtrl.text.trim(),
        creadaPorAdminId:      'admin',
        tipo:                  _tipoReserva,
        // Equipo
        equipoId:              _esDeEquipo ? _selectedEquipoId     : null,
        equipoNombre:          _esDeEquipo ? _selectedEquipoNombre : null,
        // Partido
        equipoLocalId:         _esPartido ? _equipoLocalId         : null,
        equipoLocalNombre:     _esPartido ? _equipoLocalNombre     : null,
        equipoVisitanteId:     _esPartido ? _equipoVisitanteId     : null,
        equipoVisitanteNombre: _esPartido ? _equipoVisitanteNombre : null,
        arbitroId:             _esPartido ? _arbitroId             : null,
        arbitroNombre:         _esPartido ? _arbitroNombre         : null,
        deporte:               _esPartido ? _selectedDeporte        : null,
        puntosLocal:           _esPartido && _puntosLocalCtrl.text.isNotEmpty
            ? int.tryParse(_puntosLocalCtrl.text)
            : null,
        puntosVisitante:       _esPartido && _puntosVisitanteCtrl.text.isNotEmpty
            ? int.tryParse(_puntosVisitanteCtrl.text)
            : null,
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
    final puedeMultiTipo = _isAdminMode ||
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
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(
          child: _isLoading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── PASO 1: Tipo de reserva (admin y entrenador con equipos) ──
                if (puedeMultiTipo) ...[
                  _stepHeader('1', 'Tipo de reserva', Icons.category,
                      Colors.tealAccent, done: true),
                  const SizedBox(height: 10),
                  _buildTipoToggle(),
                  const SizedBox(height: 24),
                ],

                // ── PASO 2a: Usuario (admin + individual) ────────────
                if (_isAdminMode && !_esDeEquipo && !_esPartido) ...[
                  _stepHeader(
                      puedeMultiTipo ? '2' : '1',
                      'Usuario', Icons.person, Colors.blueAccent,
                      done: _selectedUserId != null),
                  const SizedBox(height: 10),
                  _buildUserDropdown(),
                  const SizedBox(height: 24),
                ],

                // ── PASO 2: Deporte (todos los tipos) ─────────────
                _stepHeader(
                    _esIndividual
                        ? (puedeMultiTipo ? '3' : '2')
                        : '2',
                    'Deporte', Icons.sports, Colors.purpleAccent,
                    done: _selectedDeporte != null),
                const SizedBox(height: 10),
                _buildSportSelector(),
                const SizedBox(height: 24),

                // ── PASO 3: Equipo (reserva equipo) ──────────────
                if (_esDeEquipo) ...[
                  _stepHeader('3', 'Equipo', Icons.groups,
                      Colors.cyanAccent,
                      done:   _selectedEquipoId != null,
                      locked: _selectedDeporte == null),
                  const SizedBox(height: 10),
                  if (_selectedDeporte == null)
                    _lockedHint('Selecciona un deporte primero')
                  else if (_equiposFiltrados.isEmpty)
                    _lockedHint('No hay equipos de este deporte')
                  else
                    _buildEquipoSelector(),
                  const SizedBox(height: 24),
                ],

                // ── PASOS partido ─────────────────────────
                if (_esPartido) ...[

                  // Equipo local
                  _stepHeader('3', 'Equipo local', Icons.home,
                      Colors.blueAccent,
                      done:   _equipoLocalId != null,
                      locked: _selectedDeporte == null),
                  const SizedBox(height: 10),
                  if (_selectedDeporte == null)
                    _lockedHint('Selecciona un deporte primero')
                  else if (_equiposFiltrados.isEmpty)
                    _lockedHint('No hay equipos de este deporte')
                  else
                    _buildEquipoPartidoSelector(
                      isLocal: true,
                      selectedId: _equipoLocalId,
                      selectedNombre: _equipoLocalNombre,
                      onSelect: (id, nombre) => setState(() {
                        _equipoLocalId     = id;
                        _equipoLocalNombre = nombre;
                      }),
                    ),
                  const SizedBox(height: 24),

                  // Equipo visitante
                  _stepHeader('4', 'Equipo visitante', Icons.flight_land,
                      Colors.orangeAccent,
                      done:   _equipoVisitanteId != null,
                      locked: _selectedDeporte == null),
                  const SizedBox(height: 10),
                  if (_selectedDeporte == null)
                    _lockedHint('Selecciona un deporte primero')
                  else if (_equiposFiltrados.isEmpty)
                    _lockedHint('No hay equipos de este deporte')
                  else
                    _buildEquipoPartidoSelector(
                      isLocal: false,
                      selectedId: _equipoVisitanteId,
                      selectedNombre: _equipoVisitanteNombre,
                      onSelect: (id, nombre) => setState(() {
                        _equipoVisitanteId     = id;
                        _equipoVisitanteNombre = nombre;
                      }),
                    ),
                  const SizedBox(height: 24),

                  // Árbitro
                  _stepHeader('5', 'Árbitro', Icons.sports_handball,
                      Colors.yellowAccent,
                      done: _arbitroId != null),
                  const SizedBox(height: 10),
                  _buildArbitroSelector(),
                  const SizedBox(height: 24),

                  // Puntos (opcionales)
                  _stepHeader('', 'Resultado (opcional)',
                      Icons.scoreboard, Colors.white38,
                      done: _puntosLocalCtrl.text.isNotEmpty ||
                          _puntosVisitanteCtrl.text.isNotEmpty),
                  const SizedBox(height: 10),
                  _buildPuntosRow(),
                  const SizedBox(height: 24),
                ],


                // ── PISTA ────────────────────────────────
                _stepHeader(
                    _stepNum(puedeMultiTipo, 'pista'),
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
                    _stepNum(puedeMultiTipo, 'dia'),
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
                    _stepNum(puedeMultiTipo, 'horario'),
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
                      backgroundColor: AppTheme.primary,
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

  String _stepNum(bool puedeMultiTipo, String paso) {
    if (_esPartido) {
      // Partido: 2=deporte 3=local 4=visitante 5=arbitro 6=resultado → pista=7 dia=8 horario=9
      const m = {'deporte': '7', 'pista': '7', 'dia': '8', 'horario': '9'};
      return m[paso]!;
    }
    if (!puedeMultiTipo) {
      // Solo jugador sin equipos: sin toggle
      const m = {'deporte': '1', 'pista': '2', 'dia': '3', 'horario': '4'};
      return m[paso]!;
    }
    // Admin o entrenador con equipos
    if (_isAdminMode) {
      if (_esDeEquipo) {
        const m = {'deporte': '4', 'pista': '5', 'dia': '6', 'horario': '7'};
        return m[paso]!;
      }
      const m = {'deporte': '3', 'pista': '4', 'dia': '5', 'horario': '6'};
      return m[paso]!;
    }
    if (_esDeEquipo) {
      const m = {'deporte': '3', 'pista': '4', 'dia': '5', 'horario': '6'};
      return m[paso]!;
    }
    const m = {'deporte': '2', 'pista': '3', 'dia': '4', 'horario': '5'};
    return m[paso]!;
  }

  // ── Toggle tipo reserva ───────────────────────────────────────────────────

  Widget _buildTipoToggle() {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _tipoChip('Individual', Icons.person,
          _tipoReserva == TipoReserva.individual, () {
            setState(() {
              _tipoReserva             = TipoReserva.individual;
              _selectedEquipoId        = null;
              _selectedEquipoNombre    = null;
              _selectedDeporte   = null;
              if (_isAdminMode) {
                _selectedUserId   = null;
                _selectedUserName = null;
              }
            });
          }),
      _tipoChip('Equipo', Icons.groups,
          _tipoReserva == TipoReserva.equipo, () async {
            setState(() {
              _tipoReserva          = TipoReserva.equipo;
              _selectedEquipoId     = null;
              _selectedEquipoNombre = null;
              _selectedUserId       = null;
              _selectedUserName     = null;
            });
            await _loadEquipos();
          }),
      if (_isAdminMode)
        _tipoChip('Partido', Icons.sports,
            _tipoReserva == TipoReserva.partido, () async {
              setState(() {
                _tipoReserva           = TipoReserva.partido;
                _selectedUserId        = null;
                _selectedUserName      = null;
                _selectedEquipoId      = null;
                _selectedEquipoNombre  = null;
                _selectedDeporte = null;
              });
              await _loadEquipos();
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


  // ── Equipos filtrados por deporte (equipo y partido) ─────────────────────

  List<Map<String, String>> get _equiposFiltrados {
    if (_selectedDeporte == null) return [];
    return _equiposDisponibles
        .where((e) => e['deporte'] == _selectedDeporte)
        .toList();
  }



  // ── Selector equipo local/visitante ───────────────────────────────────────

  Widget _buildEquipoPartidoSelector({
    required bool     isLocal,
    required String?  selectedId,
    required String?  selectedNombre,
    required void Function(String id, String nombre) onSelect,
  }) {
    final color = isLocal ? Colors.blueAccent : Colors.orangeAccent;
    return GestureDetector(
      onTap: () => _showEquipoPartidoSheet(
          isLocal: isLocal, onSelect: onSelect,
          excludeId: isLocal ? _equipoVisitanteId : _equipoLocalId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selectedId != null
              ? color.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedId != null
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          Icon(isLocal ? Icons.home : Icons.flight_land,
              color: selectedId != null ? color : Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedNombre ??
                  (isLocal
                      ? 'Toca para seleccionar equipo local'
                      : 'Toca para seleccionar equipo visitante'),
              style: TextStyle(
                  color:    selectedId != null ? Colors.white : Colors.white38,
                  fontSize: 14),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Future<void> _showEquipoPartidoSheet({
    required bool     isLocal,
    required void Function(String, String) onSelect,
    String? excludeId,
  }) async {
    final color = isLocal ? Colors.blueAccent : Colors.orangeAccent;
    final titulo = isLocal ? 'Equipo local' : 'Equipo visitante';
    final disponibles = _equiposFiltrados
        .where((e) => e['id'] != excludeId)
        .toList();

    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        expand: false,
        builder: (_, sc) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(titulo, style: const TextStyle(color: Colors.white,
              fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: disponibles.map((eq) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(eq['id']!, eq['nombre']!);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color:        color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.groups, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(eq['nombre']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            if ((eq['entrenadorNombre'] ?? '').isNotEmpty)
                              Text(eq['entrenadorNombre']!,
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Selector árbitro ──────────────────────────────────────────────────────

  Widget _buildArbitroSelector() {
    return GestureDetector(
      onTap: () => _showArbitroSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _arbitroId != null
              ? Colors.yellowAccent.withOpacity(0.08)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _arbitroId != null
                ? Colors.yellowAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          Icon(Icons.sports_handball,
              color: _arbitroId != null ? Colors.yellowAccent : Colors.white38,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _arbitroNombre ?? 'Toca para seleccionar un árbitro',
              style: TextStyle(
                  color:    _arbitroId != null ? Colors.white : Colors.white38,
                  fontSize: 14),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Future<void> _showArbitroSheet() async {
    final searchCtrl = TextEditingController();
    String query = '';

    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize:     0.4,
          maxChildSize:     0.9,
          expand: false,
          builder: (_, sc) => Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Selecciona un árbitro',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchCtrl,
                autofocus:  true,
                style:      const TextStyle(color: Colors.white),
                onChanged:  (v) => setModal(() => query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText:   'Buscar árbitro...',
                  hintStyle:  const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled:     true,
                  fillColor:  Colors.white.withOpacity(0.07),
                  border:     OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _arbitros
                    .where((a) =>
                query.isEmpty ||
                    (a['nombre'] as String).toLowerCase().contains(query))
                    .map((a) {
                  final isSelected = _arbitroId == a['id'];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _arbitroId     = a['id'];
                        _arbitroNombre = a['nombre'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.yellowAccent.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.yellowAccent
                              : Colors.white.withOpacity(0.07),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius:          18,
                          backgroundColor: Colors.yellowAccent.withOpacity(0.15),
                          child: Icon(Icons.sports_handball,
                              color: Colors.yellowAccent, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(a['nombre'] as String,
                              style: TextStyle(
                                  color:      isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize:   14)),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.yellowAccent, size: 18),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  // ── Puntos ────────────────────────────────────────────────────────────────

  Widget _buildPuntosRow() {
    return Row(children: [
      Expanded(child: _buildPuntosField(
          ctrl:  _puntosLocalCtrl,
          label: 'Pts. local',
          color: Colors.blueAccent)),
      const SizedBox(width: 12),
      const Text('–', style: TextStyle(color: Colors.white38, fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: _buildPuntosField(
          ctrl:  _puntosVisitanteCtrl,
          label: 'Pts. visitante',
          color: Colors.orangeAccent)),
    ]);
  }

  Widget _buildPuntosField({
    required TextEditingController ctrl,
    required String label,
    required Color color,
  }) {
    return TextField(
      controller:   ctrl,
      keyboardType: TextInputType.number,
      style:        const TextStyle(color: Colors.white, fontSize: 18,
          fontWeight: FontWeight.bold),
      textAlign:    TextAlign.center,
      decoration:   InputDecoration(
        labelText:   label,
        labelStyle:  TextStyle(color: color.withOpacity(0.7), fontSize: 12),
        filled:      true,
        fillColor:   color.withOpacity(0.08),
        border:      OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(color: color.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(color: color.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide(color: color)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildEquipoSelector() {
    return GestureDetector(
      onTap: () => _showEquipoPickerSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedEquipoId != null
              ? Colors.cyanAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedEquipoId != null
                ? Colors.cyanAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          Icon(Icons.groups,
              color: _selectedEquipoId != null
                  ? Colors.cyanAccent
                  : Colors.white38,
              size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedEquipoNombre ?? 'Toca para seleccionar un equipo',
                  style: TextStyle(
                      color:    _selectedEquipoId != null
                          ? Colors.white
                          : Colors.white38,
                      fontSize: 14),
                ),
                if (_selectedEquipoId != null &&
                    _selectedUserName != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.person_pin,
                        color: Colors.cyanAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(_selectedUserName!,
                        style: const TextStyle(
                            color:    Colors.cyanAccent,
                            fontSize: 11)),
                  ]),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Future<void> _showEquipoPickerSheet() async {
    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize:     0.4,
        maxChildSize:     0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Selecciona un equipo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: (_esDeEquipo ? _equiposFiltrados : _equiposDisponibles).map((eq) {
                final isSelected = _selectedEquipoId == eq['id'];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedEquipoId     = eq['id'];
                      _selectedEquipoNombre = eq['nombre'];
                      _selectedUserId       = eq['entrenadorId'];
                      _selectedUserName     = eq['entrenadorNombre'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.cyanAccent.withOpacity(0.12)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent
                            : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color:        Colors.cyanAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.groups,
                            color: Colors.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(eq['nombre']!,
                                style: TextStyle(
                                    color:      isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize:   14)),
                            if ((eq['entrenadorNombre'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.person_pin,
                                    color: Colors.white38, size: 12),
                                const SizedBox(width: 4),
                                Text(eq['entrenadorNombre']!,
                                    style: const TextStyle(
                                        color:    Colors.white38,
                                        fontSize: 11)),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: Colors.cyanAccent, size: 18),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── Selector de deporte ───────────────────────────────────────────────────

  Widget _buildSportSelector() {
    // Individual: solo deportes con pistas activas disponibles
    // Equipo / Partido: todos los deportes (sin filtrar por pistas)
    final sports = _esIndividual
        ? CourtType.values
        .where((t) =>
    t != CourtType.otro &&
        _allCourts.any((c) => c.tipo == t && c.activa))
        .toList()
        : CourtType.values.where((t) => t != CourtType.otro).toList();

    return Wrap(
      spacing: 10, runSpacing: 10,
      children: sports.map((sport) {
        final selected = _selectedSport == sport;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedSport   = sport;
            _selectedDeporte = sport.name; // sincroniza filtro equipos
            // Resetear selecciones dependientes
            _selectedCourt     = null;
            _selectedDay       = null;
            _selectedSlotIndex = null;
            _slots             = [];
            _selectedEquipoId      = null;
            _selectedEquipoNombre  = null;
            if (_esIndividual) {
              _selectedUserId   = null;
              _selectedUserName = null;
            }
            _equipoLocalId         = null;
            _equipoLocalNombre     = null;
            _equipoVisitanteId     = null;
            _equipoVisitanteNombre = null;
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
                color: selected
                    ? Colors.purpleAccent
                    : Colors.white.withOpacity(0.1),
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
          onTap: () {
            final today = DateTime.now();
            setState(() {
              _selectedCourt     = court;
              _selectedDay       = DateTime(today.year, today.month, today.day);
              _selectedSlotIndex = null;
              _slots             = [];
            });
            _loadSlots();
          },
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
    final fmt     = DateFormat('EEEE d \'de\' MMMM', 'es');
    final today   = DateTime.now();
    final minDay  = DateTime(today.year, today.month, today.day);
    final maxDay  = _isAdminMode
        ? minDay.add(const Duration(days: 365))
        : minDay.add(const Duration(days: 15));

    final canGoPrev = _selectedDay != null &&
        _selectedDay!.isAfter(minDay);
    final canGoNext = _selectedDay != null &&
        _selectedDay!.isBefore(maxDay);

    return Row(children: [
      // Flecha izquierda
      _dayArrowButton(
        icon:    Icons.chevron_left,
        enabled: canGoPrev,
        onTap: () {
          final prev = _selectedDay!.subtract(const Duration(days: 1));
          setState(() {
            _selectedDay       = prev;
            _selectedSlotIndex = null;
            _slots             = [];
          });
          _loadSlots();
        },
      ),
      const SizedBox(width: 8),

      // Selector central (toca para abrir calendario)
      Expanded(
        child: GestureDetector(
          onTap: _pickDay,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                  color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  capitalize(fmt.format(_selectedDay!)),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ]),
          ),
        ),
      ),

      const SizedBox(width: 8),
      // Flecha derecha
      _dayArrowButton(
        icon:    Icons.chevron_right,
        enabled: canGoNext,
        onTap: () {
          final next = _selectedDay!.add(const Duration(days: 1));
          setState(() {
            _selectedDay       = next;
            _selectedSlotIndex = null;
            _slots             = [];
          });
          _loadSlots();
        },
      ),
    ]);
  }

  Widget _dayArrowButton({
    required IconData  icon,
    required bool      enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:  42,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.orangeAccent.withOpacity(0.12)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? Colors.orangeAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Icon(icon,
            color: enabled ? Colors.orangeAccent : Colors.white12,
            size:  22),
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
          _legendDot(Colors.redAccent, 'Ocupado / Pasado'),
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
            final isBlocked  = slot.occupied || slot.isPast;
            final color = isBlocked ? Colors.redAccent : Colors.greenAccent;

            return GestureDetector(
              onTap: isBlocked
                  ? (slot.occupied ? () => _showOccupiedInfo(slot) : null)
                  : () => setState(() => _selectedSlotIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.greenAccent.withOpacity(0.25)
                      : isBlocked
                      ? Colors.redAccent.withOpacity(0.10)
                      : Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.greenAccent
                        : isBlocked
                        ? Colors.redAccent.withOpacity(0.4)
                        : Colors.greenAccent.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Opacity(
                  opacity: slot.isPast && !slot.occupied ? 0.45 : 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(timeFmt.format(slot.inicio),
                          style: TextStyle(
                              color:      isSelected ? Colors.greenAccent : color,
                              fontSize:   13,
                              fontWeight: FontWeight.bold)),
                      Text(timeFmt.format(slot.fin),
                          style: TextStyle(
                              color: (isSelected ? Colors.greenAccent : color)
                                  .withOpacity(0.7),
                              fontSize: 11)),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 14)
                      else if (slot.isPast && !slot.occupied)
                        const Icon(Icons.access_time,
                            color: Colors.redAccent, size: 11),
                    ],
                  ),
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
    return GestureDetector(
      onTap: () => _showUserPickerSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedUserId != null
              ? Colors.blueAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedUserId != null
                ? Colors.blueAccent.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          Icon(Icons.person,
              color: _selectedUserId != null ? Colors.blueAccent : Colors.white38,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedUserName ?? 'Toca para seleccionar un usuario',
              style: TextStyle(
                  color:    _selectedUserId != null ? Colors.white : Colors.white38,
                  fontSize: 14),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Future<void> _showUserPickerSheet() async {
    final searchCtrl = TextEditingController();
    String query = '';

    await showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.modalBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize:     0.5,
          maxChildSize:     0.95,
          expand: false,
          builder: (_, scrollCtrl) => Column(children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Selecciona un usuario',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Buscador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchCtrl,
                autofocus:  true,
                style:      const TextStyle(color: Colors.white),
                onChanged:  (v) => setModal(() => query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText:   'Buscar usuario...',
                  hintStyle:  const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled:     true,
                  fillColor:  Colors.white.withOpacity(0.07),
                  border:     OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:   BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Lista filtrada
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _usuarios
                    .where((u) =>
                query.isEmpty ||
                    (u['nombre'] as String)
                        .toLowerCase()
                        .contains(query) ||
                    (u['email'] as String? ?? '')
                        .toLowerCase()
                        .contains(query))
                    .map((u) {
                  final isSelected = _selectedUserId == u['id'];
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedUserId       = u['id'];
                        _selectedUserName     = u['nombre'];
                        _selectedEquipoId     = null;
                        _selectedEquipoNombre = null;
                        _equiposDisponibles   = [];
                      });
                      await _loadEquipos();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.white.withOpacity(0.07),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius:          18,
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Text(
                            (u['nombre'] as String).isNotEmpty
                                ? (u['nombre'] as String)[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color:      Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize:   14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['nombre'] as String,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14)),
                              Text(u['email'] as String? ?? '',
                                  style: const TextStyle(
                                      color:    Colors.white38,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Colors.blueAccent, size: 18),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
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

}

// ── Modelo auxiliar de slot ───────────────────────────────────────────────────

class _TimeSlot {
  final DateTime inicio;
  final DateTime fin;
  final bool     occupied;
  final String?  occupiedBy;
  final bool     isPast;

  const _TimeSlot({
    required this.inicio,
    required this.fin,
    required this.occupied,
    this.occupiedBy,
    this.isPast = false,
  });
}