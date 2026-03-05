import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gesport/models/booking.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/services/auth_service.dart';
import 'package:gesport/services/booking_service.dart';
import 'package:gesport/screens/booking_form_screen.dart';
import 'package:gesport/screens/teams_screen.dart';
import 'package:intl/intl.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';
import 'package:gesport/utils/app_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth           = FirebaseAuth.instance;
  final _bookingService = BookingService();

  UserModel? _currentUser;
  String?    _firestoreUserId;
  bool       _loadingUser = true;

  // IDs de equipos a los que pertenece el usuario (jugador o entrenador)
  List<String> _equipoIds = [];
  bool         _loadingEquipos = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    final db = FirebaseFirestore.instance;

    // 1. Intentar por UID
    final byUid = await db.collection('usuarios').doc(firebaseUser.uid).get();
    if (byUid.exists) {
      if (mounted) {
        setState(() {
          _currentUser     = UserModel.fromMap(firebaseUser.uid, byUid.data()!);
          _firestoreUserId = firebaseUser.uid;
          _loadingUser     = false;
        });
      }
      await _loadEquipos(firebaseUser.uid);
      return;
    }

    // 2. Fallback por email
    final byEmail = await db
        .collection('usuarios')
        .where('email', isEqualTo: firebaseUser.email)
        .limit(1)
        .get();

    if (mounted) {
      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        setState(() {
          _currentUser     = UserModel.fromMap(doc.id, doc.data());
          _firestoreUserId = doc.id;
          _loadingUser     = false;
        });
        await _loadEquipos(doc.id);
      } else {
        setState(() {
          _currentUser = UserModel(
            uid:    firebaseUser.uid,
            nombre: firebaseUser.displayName ?? firebaseUser.email ?? 'Usuario',
            email:  firebaseUser.email ?? '',
          );
          _firestoreUserId = firebaseUser.uid;
          _loadingUser     = false;
        });
        if (mounted) setState(() => _loadingEquipos = false);
      }
    }
  }

  Future<void> _loadEquipos(String userId) async {
    final equipos = await _bookingService.getEquiposDelUsuario(userId);
    if (mounted) {
      setState(() {
        _equipoIds      = equipos.map((e) => e['id']!).toList();
        _loadingEquipos = false;
      });
    }
  }

  Future<void> _cancelarReserva(BookingModel b) async {
    // Solo puede cancelar reservas individuales propias,
    // o de equipo si es el entrenador/admin
    final confirm = await ConfirmDialog.show(
      context,
      title:        'Cancelar reserva',
      content:      b.esDeEquipo
          ? '¿Cancelar la reserva del equipo \${b.equipoNombre} en \${b.pistaNombre}?'
          : '¿Seguro que quieres cancelar la reserva en \${b.pistaNombre}?',
      confirmLabel: 'Sí, cancelar',
    );
    if (confirm == true) {
      await _bookingService.setCancelada(b.id, true);
    }
  }

  bool _puedeCrearReservaEquipo() {
    final rol = _currentUser?.rol;
    return rol == UserRole.admin ||
        (rol == UserRole.entrenador && _equipoIds.isNotEmpty);
  }

  bool _puedeCancelarReserva(BookingModel b) =>
      _firestoreUserId != null && b.usuarioId == _firestoreUserId;

  @override
  Widget build(BuildContext context) {
    final uid     = _firestoreUserId ?? _auth.currentUser?.uid ?? '';
    final now     = DateTime.now();
    final fmtDate = DateFormat('EEE d MMM', 'es');
    final fmtTime = DateFormat('HH:mm');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('GESPORT',
            style: TextStyle(
                color:       Colors.white,
                fontWeight:  FontWeight.bold,
                letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip:  'Mi perfil',
            icon:     const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () => _showProfileSheet(context),
          ),
          IconButton(
            tooltip:   'Cerrar sesión',
            icon:      const Icon(Icons.logout, color: Colors.white),
            onPressed: () async => await AuthService().signOut(),
          ),
        ],
      ),
      floatingActionButton: _currentUser?.rol == UserRole.arbitro ? null : FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon:  const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva reserva',
            style: TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingFormScreen(
              forUserId:   uid,
              forUserName: _currentUser?.nombre ?? '',
              forUserRole: _currentUser?.rol,
            ),
          ),
        ),
      ),
      body: Container(
        height:     double.infinity,
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(
          child: (_loadingUser || _loadingEquipos)
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : StreamBuilder<List<BookingModel>>(
            stream: _currentUser?.rol == UserRole.arbitro
                ? _bookingService.getPartidosArbitro(uid)
                : _bookingService.getAllUserRelatedBookings(uid, _equipoIds),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              final all = snap.data ?? [];

              // Próximas: no canceladas y fin en el futuro
              final proximas = all
                  .where((b) => !b.cancelada && b.fechaFin.isAfter(now))
                  .toList()
                ..sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));

              // Historial: canceladas o ya pasadas
              final historial = all
                  .where((b) => b.cancelada || b.fechaFin.isBefore(now))
                  .toList()
                ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo
                    const SizedBox(height: 8),
                    Text(
                      'Hola, ${_currentUser?.nombre.split(' ').first ?? 'jugador'} 👋',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser?.rol.label ?? '',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    // ── Próximas reservas ──────────────────
                    SectionHeader(
                        title: _currentUser?.rol == UserRole.arbitro
                            ? 'Mis partidos'
                            : 'Próximas reservas',
                        icon:_currentUser?.rol == UserRole.arbitro
                            ? Icons.sports
                            : Icons.event_available,
                        color:_currentUser?.rol == UserRole.arbitro
                            ? Colors.yellowAccent
                            : Colors.greenAccent,
                        badge: proximas.length),
                    const SizedBox(height: 12),
                    if (proximas.isEmpty)
                      EmptyState(
                          icon:Icons.event_note,
                          text:'No tienes reservas próximas',
                          subtitle: 'Pulsa + para hacer una nueva reserva')
                    else
                      ...proximas.map((b) => _buildProximaCard(
                          b, fmtDate, fmtTime, context)),

                    const SizedBox(height: 32),

                    // ── Historial ──────────────────────────
                    SectionHeader(
                        title: 'Historial',
                        icon: Icons.history,
                        color:Colors.white38,
                        badge: historial.length),
                    const SizedBox(height: 12),
                    if (historial.isEmpty)
                      EmptyState(
                          icon: Icons.history_toggle_off,
                          text: 'Sin historial todavía',
                          subtitle: null)
                    else
                      ...historial.map((b) =>
                          _buildHistorialCard(b, fmtDate, fmtTime)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Card próxima reserva ─────────────────────────────────────────────────

  Widget _buildProximaCard(BookingModel b, DateFormat fmtDate,
      DateFormat fmtTime, BuildContext context) {
    final inicio  = b.fecha;
    final now     = DateTime.now();
    final isToday = inicio.day   == now.day &&
        inicio.month == now.month &&
        inicio.year  == now.year;

    final cardColor   = b.esPartido  ? Colors.yellowAccent
        : b.esDeEquipo ? Colors.cyanAccent
        : Colors.greenAccent;
    final borderColor = b.esPartido  ? Colors.yellowAccent.withOpacity(0.4)
        : b.esDeEquipo ? Colors.cyanAccent.withOpacity(0.4)
        : Colors.greenAccent.withOpacity(0.2);

    // Badge tipo pill (equipo o partido) — no se muestra al árbitro
    final rol = _currentUser?.rol;
    final showBadge = rol != UserRole.arbitro &&
        (b.esDeEquipo || b.esPartido);

    Widget badgePill(String label, Color color, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color:       color,
                  fontSize:    10,
                  fontWeight:  FontWeight.w700,
                  letterSpacing: 0.4)),
        ]),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin:     const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
            child: Row(
              children: [
                // Badge día
                Container(
                  width: 52, height: 60,
                  decoration: BoxDecoration(
                    color:        cardColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isToday)
                        Text('HOY',
                            style: TextStyle(
                                color:      cardColor,
                                fontSize:   10,
                                fontWeight: FontWeight.bold))
                      else ...[
                        Text(inicio.day.toString().padLeft(2, '0'),
                            style: TextStyle(
                                color:      cardColor,
                                fontSize:   20,
                                fontWeight: FontWeight.bold)),
                        Text(
                          capitalize(
                              DateFormat('MMM', 'es').format(inicio)),
                          style: TextStyle(
                              color: cardColor.withOpacity(0.7),
                              fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Datos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contenido partido (marcador)
                      if (b.esPartido) ...[
                        const SizedBox(height: 2),
                        // Marcador
                        Row(children: [
                          Expanded(
                            child: Text(b.equipoLocalNombre ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.yellowAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.yellowAccent.withOpacity(0.3)),
                            ),
                            child: Text(
                              b.resultado ?? 'vs',
                              style: const TextStyle(
                                  color:      Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize:   14),
                            ),
                          ),
                          Expanded(
                            child: Text(b.equipoVisitanteNombre ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                textAlign: TextAlign.end,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        // Pista del partido
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.stadium,
                              color: Colors.white38, size: 12),
                          const SizedBox(width: 4),
                          Text(b.pistaNombre,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ]),
                        // Árbitro solo si NO es el usuario logado
                        if (b.arbitroNombre != null &&
                            _currentUser?.rol != UserRole.arbitro) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.sports_handball,
                                color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Text(b.arbitroNombre!,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ]),
                        ],
                        const SizedBox(height: 4),
                      ],
                      // (badge de equipo mostrado como pill en Stack)
                      if (!b.esPartido)
                        Text(b.pistaNombre,
                            style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize:   15)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtTime.format(b.horaInicio)} – ${fmtTime.format(b.horaFin)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      if (!isToday) ...[
                        const SizedBox(height: 2),
                        Text(
                          capitalize(fmtDate.format(inicio)),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                      if (b.notas != null && b.notas!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          b.notas!,
                          style: const TextStyle(
                              color:      Colors.white38,
                              fontSize:   11,
                              fontStyle:  FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Botón cancelar (solo si puede)
                if (_puedeCancelarReserva(b))
                  IconButton(
                    tooltip:     'Cancelar reserva',
                    padding:     EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.cancel_outlined,
                        color: Colors.redAccent, size: 22),
                    onPressed:   () => _cancelarReserva(b),
                  ),
              ],
            ),
          ),
        ),

        // ── Badge pill posicionado arriba a la derecha ──────────────────
        if (showBadge)
          Positioned(
            top:   -1,
            right: 12,
            child: b.esPartido
                ? badgePill('PARTIDO', Colors.yellowAccent, Icons.sports)
                : badgePill('EQUIPO',  Colors.cyanAccent,   Icons.groups),
          ),
      ],
    );
  }

  // ── Card historial ───────────────────────────────────────────────────────

  Widget _buildHistorialCard(
      BookingModel b, DateFormat fmtDate, DateFormat fmtTime) {
    final color = b.cancelada ? Colors.redAccent : Colors.white38;

    return Opacity(
      opacity: 0.6,
      child: Container(
        margin:     const EdgeInsets.only(bottom: 8),
        padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border:       Border(left: BorderSide(
              color: b.esDeEquipo ? Colors.cyanAccent.withOpacity(0.5) : color,
              width: 3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge equipo
                if (b.esDeEquipo) ...[
                  Row(children: [
                    const Icon(Icons.groups,
                        color: Colors.cyanAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(b.equipoNombre ?? '',
                        style: const TextStyle(
                            color: Colors.cyanAccent, fontSize: 10)),
                  ]),
                  const SizedBox(height: 2),
                ],
                Text(
                  b.pistaNombre,
                  style: TextStyle(
                    color:           Colors.white70,
                    fontWeight:      FontWeight.w600,
                    fontSize:        14,
                    decoration:      b.cancelada ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white38,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${capitalize(fmtDate.format(b.fecha))}  ·  '
                      '${fmtTime.format(b.horaInicio)} – ${fmtTime.format(b.horaFin)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:     const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration:  BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              b.cancelada ? 'CANCELADA' : 'PASADA',
              style: TextStyle(
                  color:      color,
                  fontSize:   10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Perfil bottom sheet ──────────────────────────────────────────────────

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    AppTheme.modalBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primary.withOpacity(0.25),
              child: Text(
                _currentUser?.nombre.isNotEmpty == true
                    ? _currentUser!.nombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   30,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentUser?.nombre ?? 'Usuario',
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentUser?.rol.label.toUpperCase() ?? '',
                style: const TextStyle(
                    color:      Colors.blueAccent,
                    fontSize:   11,
                    fontWeight: FontWeight.bold),
              ),
            ),
            // Badge equipos si tiene
            if (_equipoIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color:        Colors.cyanAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_equipoIds.length} equipo${_equipoIds.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      color:      Colors.cyanAccent,
                      fontSize:   11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
            // Botón mis equipos para entrenador
            if (_currentUser?.rol == UserRole.entrenador &&
                _equipoIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamsScreen(
                      coachId:     _firestoreUserId ?? '',
                      coachNombre: _currentUser?.nombre,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:        Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.groups_rounded,
                        color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    const Text('Gestionar mis equipos',
                        style: TextStyle(
                            color:      Colors.orangeAccent,
                            fontSize:   13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        color: Colors.orangeAccent, size: 16),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            _profileRow(Icons.email_outlined, 'Email',    _currentUser?.email ?? '—'),
            if (_currentUser?.phone.isNotEmpty == true)
              _profileRow(Icons.phone_outlined, 'Teléfono', _currentUser!.phone),
            if (_currentUser?.age != null)
              _profileRow(Icons.cake_outlined,  'Edad',    '${_currentUser!.age} años'),
            const SizedBox(height: 24),
            SizedBox(
              width:  double.infinity,
              height: 48,
              child:  OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
                },
                icon:  const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                label: const Text('Cerrar sesión',
                    style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side:  BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  // _sectionHeader → SectionHeader widget de app_widgets.dart

  // _emptyState → EmptyState widget de app_widgets.dart

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child:   Row(children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ]),
    );
  }

}