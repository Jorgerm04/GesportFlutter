import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Servicio para cargar datos de prueba.
/// Usa la REST API de Firebase Auth para crear usuarios SIN cerrar la sesión
/// del admin activo. El UID resultante se usa como ID del doc en Firestore.
///
/// Contraseña de todos los usuarios de prueba: Gesport2024!
class SeedService {
  final _db = FirebaseFirestore.instance;

  static const _defaultPassword = 'Gesport2024!';

  // API key del proyecto Firebase (se lee de FirebaseOptions en runtime)
  static String get _apiKey {
    final app = Firebase.app();
    return app.options.apiKey;
  }

  CollectionReference get _usuarios => _db.collection('usuarios');
  CollectionReference get _pistas   => _db.collection('pistas');
  CollectionReference<Map<String, dynamic>> get _equipos =>
      _db.collection('equipos');
  CollectionReference get _reservas => _db.collection('reservas');

  // ── Seed principal ───────────────────────────────────────────────────────

  Future<String> seedAll() async {
    final userIds = await _seedUsuarios();

    final jugadorIds    = userIds['jugadores']!;
    final entrenadorIds = userIds['entrenadores']!;

    final courtIds = await _seedPistas();
    await _seedEquipos(jugadorIds, entrenadorIds);
    await _seedReservas(jugadorIds, courtIds);

    return '✅ Seed completado:\n'
        '• ${jugadorIds.length} jugadores\n'
        '• ${entrenadorIds.length} entrenadores\n'
        '• ${userIds['arbitros']!.length} árbitros\n'
        '• ${courtIds.length} pistas\n'
        '• 3 equipos\n'
        '• ~28 reservas (individuales + equipo)\n\n'
        '🔑 Contraseña de todos: $_defaultPassword';
  }

  // ── Usuarios ─────────────────────────────────────────────────────────────

  Future<Map<String, List<String>>> _seedUsuarios() async {
    final jugadorIds    = <String>[];
    final entrenadorIds = <String>[];
    final arbitroIds    = <String>[];

    final lista = [
      (nombre: 'Carlos Martínez',  email: 'carlos.martinez@gesport.es',  phone: '612 345 678', age: 22, rol: 'jugador'),
      (nombre: 'Lucía Fernández',  email: 'lucia.fernandez@gesport.es',  phone: '623 456 789', age: 20, rol: 'jugador'),
      (nombre: 'Marcos Iglesias',  email: 'marcos.iglesias@gesport.es',  phone: '634 567 890', age: 25, rol: 'jugador'),
      (nombre: 'Sofía Ruiz',       email: 'sofia.ruiz@gesport.es',       phone: '645 678 901', age: 19, rol: 'jugador'),
      (nombre: 'Adrián López',     email: 'adrian.lopez@gesport.es',     phone: '656 789 012', age: 23, rol: 'jugador'),
      (nombre: 'Elena Torres',     email: 'elena.torres@gesport.es',     phone: '667 890 123', age: 21, rol: 'jugador'),
      (nombre: 'Pablo Sánchez',    email: 'pablo.sanchez@gesport.es',    phone: '678 901 234', age: 24, rol: 'jugador'),
      (nombre: 'Natalia Gómez',    email: 'natalia.gomez@gesport.es',    phone: '689 012 345', age: 20, rol: 'jugador'),
      (nombre: 'Javier Moreno',    email: 'javier.moreno@gesport.es',    phone: '690 123 456', age: 26, rol: 'jugador'),
      (nombre: 'Marta Díaz',       email: 'marta.diaz@gesport.es',       phone: '601 234 567', age: 22, rol: 'jugador'),
      (nombre: 'Roberto Alonso',   email: 'roberto.alonso@gesport.es',   phone: '611 111 111', age: 38, rol: 'entrenador'),
      (nombre: 'Patricia Vega',    email: 'patricia.vega@gesport.es',    phone: '622 222 222', age: 42, rol: 'entrenador'),
      (nombre: 'Fernando Ortiz',   email: 'fernando.ortiz@gesport.es',   phone: '633 333 333', age: 35, rol: 'entrenador'),
      (nombre: 'Luis Herrera',     email: 'luis.herrera@gesport.es',     phone: '644 444 444', age: 45, rol: 'arbitro'),
      (nombre: 'Carmen Jiménez',   email: 'carmen.jimenez@gesport.es',   phone: '655 555 555', age: 39, rol: 'arbitro'),
    ];

    for (final u in lista) {
      // Crear en Firebase Auth mediante REST API (no afecta la sesión activa)
      String? uid = await _createAuthUserRest(u.email, _defaultPassword, u.nombre);

      // Si ya existe en Auth, obtener su UID iniciando sesión via REST
      uid ??= await _getUidBySignInRest(u.email, _defaultPassword);

      if (uid == null) {
        debugPrint('SeedService: no se pudo obtener UID para ${u.email}');
        continue;
      }

      // Crear (o sobreescribir) doc en Firestore con el UID como ID
      await _usuarios.doc(uid).set({
        'nombre':    u.nombre,
        'email':     u.email,
        'phone':     u.phone,
        'age':       u.age,
        'rol':       u.rol,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _addToRole(uid, u.rol, jugadorIds, entrenadorIds, arbitroIds);
    }

    return {
      'jugadores':    jugadorIds,
      'entrenadores': entrenadorIds,
      'arbitros':     arbitroIds,
    };
  }

  void _addToRole(String uid, String rol, List<String> jugadores,
      List<String> entrenadores, List<String> arbitros) {
    switch (rol) {
      case 'jugador':    jugadores.add(uid);
      case 'entrenador': entrenadores.add(uid);
      case 'arbitro':    arbitros.add(uid);
    }
  }

  /// Crea un usuario en Firebase Auth usando la REST API.
  /// Devuelve el UID si tiene éxito, null si el email ya existe.
  Future<String?> _createAuthUserRest(
      String email, String password, String displayName) async {
    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
      );

      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode({
        'email':             email,
        'password':          password,
        'displayName':       displayName,
        'returnSecureToken': false,
      }));

      final response  = await request.close();
      final body      = await response.transform(utf8.decoder).join();
      final json      = jsonDecode(body) as Map<String, dynamic>;
      client.close();

      if (response.statusCode == 200) {
        return json['localId'] as String?;
      }

      // EMAIL_EXISTS → ya estaba creado
      final errorCode = json['error']?['message'] as String?;
      if (errorCode == 'EMAIL_EXISTS') return null;

      debugPrint('SeedService Auth error [$email]: $errorCode');
      return null;
    } catch (e) {
      debugPrint('SeedService REST error [$email]: $e');
      return null;
    }
  }

  /// Si el email ya existe en Auth, inicia sesión via REST para obtener el UID.
  /// No afecta la sesión activa de la app.
  Future<String?> _getUidBySignInRest(String email, String password) async {
    try {
      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey',
      );

      final client  = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode({
        'email':             email,
        'password':          password,
        'returnSecureToken': false,
      }));

      final response = await request.close();
      final body     = await response.transform(utf8.decoder).join();
      final json     = jsonDecode(body) as Map<String, dynamic>;
      client.close();

      if (response.statusCode == 200) {
        return json['localId'] as String?;
      }

      debugPrint('SeedService signIn error [$email]: ${json['error']?['message']}');
      return null;
    } catch (e) {
      debugPrint('SeedService signIn REST error [$email]: $e');
      return null;
    }
  }

  // ── Pistas ───────────────────────────────────────────────────────────────

  Future<List<String>> _seedPistas() async {
    final ids = <String>[];

    final pistas = [
      _pista('Pádel Central 1',     'padel',      'Pista cubierta con iluminación LED. Aforo: 4 jugadores.',         true,  12.0),
      _pista('Pádel Central 2',     'padel',      'Pista exterior con vistas al jardín. Aforo: 4 jugadores.',        true,  10.0),
      _pista('Pádel VIP',           'padel',      'Pista premium con vestuarios privados y pantalla marcador.',       true,  18.0),
      _pista('Fútbol 7 Norte',      'futbol',     'Campo de césped artificial homologado. Iluminación nocturna.',     true,  45.0),
      _pista('Fútbol 7 Sur',        'futbol',     'Campo de tierra compactada. Ideal para entrenamientos.',           true,  35.0),
      _pista('Cancha Baloncesto A', 'baloncesto', 'Pista interior parquet. Tableros regulables en altura.',           true,  20.0),
      _pista('Cancha Baloncesto B', 'baloncesto', 'Pista exterior asfalto. Disponible solo en horario diurno.',       true,  10.0),
      _pista('Tenis Rafa',          'tenis',      'Pista de tierra batida profesional. Preparada para torneos.',      true,  15.0),
      _pista('Tenis Express',       'tenis',      'Pista dura para sesiones rápidas de entrenamiento.',               false, 12.0),
      _pista('Voley Playa',         'voley',      'Arena fina importada. 2 redes disponibles. Duchas exteriores.',    true,   8.0),
    ];

    for (final p in pistas) {
      final ref = await _pistas.add(p);
      ids.add(ref.id);
    }

    return ids;
  }

  Map<String, dynamic> _pista(String nombre, String tipo, String desc,
      bool activa, double precio) {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'descripcion': desc,
      'activa': activa,
      'precioPorHora': precio,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Equipos ──────────────────────────────────────────────────────────────

  Future<void> _seedEquipos(
      List<String> jugIds, List<String> entIds) async {
    await _equipos.add({
      'nombre': 'Leones del Sur',
      'descripcion': 'Equipo de pádel masculino. Competición regional liga federada.',
      'entrenadorId':     entIds.isNotEmpty ? entIds[0] : null,
      'entrenadorNombre': 'Roberto Alonso',
      'jugadoresIds':     jugIds.length >= 4 ? jugIds.sublist(0, 4) : jugIds,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _equipos.add({
      'nombre': 'Panteras FC',
      'descripcion': 'Equipo femenino de fútbol 7. Entrenamiento martes y jueves.',
      'entrenadorId':     entIds.length >= 2 ? entIds[1] : null,
      'entrenadorNombre': 'Patricia Vega',
      'jugadoresIds':     jugIds.length >= 8 ? jugIds.sublist(4, 8) : [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _equipos.add({
      'nombre': 'Águilas Basket',
      'descripcion': 'Equipo mixto de baloncesto 3x3. Participan en liga municipal.',
      'entrenadorId':     entIds.length >= 3 ? entIds[2] : null,
      'entrenadorNombre': 'Fernando Ortiz',
      'jugadoresIds':     jugIds.length >= 10 ? jugIds.sublist(6, 10) : [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Reservas ─────────────────────────────────────────────────────────────

  Future<void> _seedReservas(
      List<String> jugIds, List<String> courtIds) async {

    // Helpers: acceso seguro a listas y construcción de slots exactos
    String jug(int i) => jugIds.length > i ? jugIds[i] : 'u$i';
    String pis(int i) => courtIds.length > i ? courtIds[i] : 'c$i';

    // Crea un DateTime en una fecha base con la hora del slot
    DateTime slot(DateTime base, int h, int m) =>
        DateTime(base.year, base.month, base.day, h, m);
    // Fin del slot = inicio + 1h30min
    DateTime fin(DateTime s) => s.add(const Duration(hours: 1, minutes: 30));

    final today = DateTime.now();
    DateTime d(int days) => today.subtract(Duration(days: days)); // pasado
    DateTime f(int days) => today.add(Duration(days: days));       // futuro

    // Slots válidos: 09:00 10:30 12:00 13:30 15:00 16:30 18:00 19:30 21:00
    final pasadas = [
      // ── Carlos (jug 0) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(0), usuarioNombre: 'Carlos Martínez',
        pistaId: pis(0),   pistaNombre: 'Pádel Central 1',
        inicio: slot(d(14), 9, 0),  fin: fin(slot(d(14), 9, 0)),
        notas: 'Torneo de liga, ronda clasificatoria',
      ),
      _reserva(
        usuarioId: jug(0), usuarioNombre: 'Carlos Martínez',
        pistaId: pis(0),   pistaNombre: 'Pádel Central 1',
        inicio: slot(d(5), 16, 30), fin: fin(slot(d(5), 16, 30)),
        notas: 'Partido amistoso con equipo visitante',
      ),
      // ── Lucía (jug 1) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(1), usuarioNombre: 'Lucía Fernández',
        pistaId: pis(7),   pistaNombre: 'Tenis Rafa',
        inicio: slot(d(10), 10, 30), fin: fin(slot(d(10), 10, 30)),
      ),
      _reserva(
        usuarioId: jug(1), usuarioNombre: 'Lucía Fernández',
        pistaId: pis(7),   pistaNombre: 'Tenis Rafa',
        inicio: slot(d(3), 12, 0),   fin: fin(slot(d(3), 12, 0)),
        notas: 'Clase con entrenadora Patricia',
      ),
      // ── Marcos (jug 2) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(2), usuarioNombre: 'Marcos Iglesias',
        pistaId: pis(3),   pistaNombre: 'Fútbol 7 Norte',
        inicio: slot(d(7), 18, 0),  fin: fin(slot(d(7), 18, 0)),
        notas: 'Entrenamiento táctico con el equipo',
      ),
      _reserva(
        usuarioId: jug(2), usuarioNombre: 'Marcos Iglesias',
        pistaId: pis(3),   pistaNombre: 'Fútbol 7 Norte',
        inicio: slot(d(1), 15, 0),  fin: fin(slot(d(1), 15, 0)),
        notas: 'Entrenamiento previo al partido del domingo',
      ),
      // ── Sofía (jug 3) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(3), usuarioNombre: 'Sofía Ruiz',
        pistaId: pis(5),   pistaNombre: 'Cancha Baloncesto A',
        inicio: slot(d(4), 13, 30), fin: fin(slot(d(4), 13, 30)),
        notas: 'Partido 3x3 liga municipal',
      ),
      // ── Adrián (jug 4) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(4), usuarioNombre: 'Adrián López',
        pistaId: pis(5),   pistaNombre: 'Cancha Baloncesto A',
        inicio: slot(d(6), 19, 30), fin: fin(slot(d(6), 19, 30)),
      ),
      // ── Elena (jug 5) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(5), usuarioNombre: 'Elena Torres',
        pistaId: pis(1),   pistaNombre: 'Pádel Central 2',
        inicio: slot(d(9), 21, 0),  fin: fin(slot(d(9), 21, 0)),
        notas: 'Sesión dobles mixtos',
      ),
      // ── Pablo (jug 6) cancelada ──────────────────────────────────────────
      _reserva(
        usuarioId: jug(6), usuarioNombre: 'Pablo Sánchez',
        pistaId: pis(9),   pistaNombre: 'Voley Playa',
        inicio: slot(d(2), 10, 30), fin: fin(slot(d(2), 10, 30)),
        cancelada: true,
      ),
      // ── Natalia (jug 7) ─────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(7), usuarioNombre: 'Natalia Gómez',
        pistaId: pis(2),   pistaNombre: 'Pádel VIP',
        inicio: slot(d(8), 12, 0),  fin: fin(slot(d(8), 12, 0)),
        notas: 'Cumpleaños, reserva especial pista VIP',
      ),
      // ── Javier (jug 8) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(8), usuarioNombre: 'Javier Moreno',
        pistaId: pis(4),   pistaNombre: 'Fútbol 7 Sur',
        inicio: slot(d(12), 9, 0),  fin: fin(slot(d(12), 9, 0)),
      ),
      // ── Marta (jug 9) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(9), usuarioNombre: 'Marta Díaz',
        pistaId: pis(6),   pistaNombre: 'Cancha Baloncesto B',
        inicio: slot(d(11), 15, 0), fin: fin(slot(d(11), 15, 0)),
        notas: 'Entreno libre tarde',
      ),
    ];

    final futuras = [
      // ── Carlos (jug 0) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(0), usuarioNombre: 'Carlos Martínez',
        pistaId: pis(0),   pistaNombre: 'Pádel Central 1',
        inicio: slot(f(0), 18, 0),  fin: fin(slot(f(0), 18, 0)),
        notas: 'Sesión de entrenamiento individual',
      ),
      _reserva(
        usuarioId: jug(0), usuarioNombre: 'Carlos Martínez',
        pistaId: pis(2),   pistaNombre: 'Pádel VIP',
        inicio: slot(f(4), 10, 30), fin: fin(slot(f(4), 10, 30)),
        notas: 'Final torneo club',
      ),
      _reserva(
        usuarioId: jug(0), usuarioNombre: 'Carlos Martínez',
        pistaId: pis(0),   pistaNombre: 'Pádel Central 1',
        inicio: slot(f(10), 9, 0),  fin: fin(slot(f(10), 9, 0)),
      ),
      // ── Lucía (jug 1) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(1), usuarioNombre: 'Lucía Fernández',
        pistaId: pis(7),   pistaNombre: 'Tenis Rafa',
        inicio: slot(f(2), 12, 0),  fin: fin(slot(f(2), 12, 0)),
        notas: 'Clase con entrenadora Patricia',
      ),
      // ── Marcos (jug 2) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(2), usuarioNombre: 'Marcos Iglesias',
        pistaId: pis(3),   pistaNombre: 'Fútbol 7 Norte',
        inicio: slot(f(5), 19, 30), fin: fin(slot(f(5), 19, 30)),
      ),
      _reserva(
        usuarioId: jug(2), usuarioNombre: 'Marcos Iglesias',
        pistaId: pis(4),   pistaNombre: 'Fútbol 7 Sur',
        inicio: slot(f(12), 16, 30), fin: fin(slot(f(12), 16, 30)),
        notas: 'Amistoso inter-equipos',
      ),
      // ── Sofía (jug 3) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(3), usuarioNombre: 'Sofía Ruiz',
        pistaId: pis(5),   pistaNombre: 'Cancha Baloncesto A',
        inicio: slot(f(3), 13, 30), fin: fin(slot(f(3), 13, 30)),
      ),
      // ── Adrián (jug 4) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(4), usuarioNombre: 'Adrián López',
        pistaId: pis(5),   pistaNombre: 'Cancha Baloncesto A',
        inicio: slot(f(1), 15, 0),  fin: fin(slot(f(1), 15, 0)),
      ),
      // ── Elena (jug 5) cancelada futura ──────────────────────────────────
      _reserva(
        usuarioId: jug(5), usuarioNombre: 'Elena Torres',
        pistaId: pis(1),   pistaNombre: 'Pádel Central 2',
        inicio: slot(f(2), 21, 0),  fin: fin(slot(f(2), 21, 0)),
        notas: 'Clase particular con entrenadora',
        cancelada: true,
      ),
      // ── Pablo (jug 6) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(6), usuarioNombre: 'Pablo Sánchez',
        pistaId: pis(9),   pistaNombre: 'Voley Playa',
        inicio: slot(f(3), 10, 30), fin: fin(slot(f(3), 10, 30)),
        notas: 'Torneo interno equipos mixtos',
      ),
      // ── Natalia (jug 7) ─────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(7), usuarioNombre: 'Natalia Gómez',
        pistaId: pis(2),   pistaNombre: 'Pádel VIP',
        inicio: slot(f(6), 12, 0),  fin: fin(slot(f(6), 12, 0)),
      ),
      // ── Javier (jug 8) ──────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(8), usuarioNombre: 'Javier Moreno',
        pistaId: pis(4),   pistaNombre: 'Fútbol 7 Sur',
        inicio: slot(f(7), 19, 30), fin: fin(slot(f(7), 19, 30)),
        notas: 'Partido de liga, jornada 8',
      ),
      // ── Marta (jug 9) ───────────────────────────────────────────────────
      _reserva(
        usuarioId: jug(9), usuarioNombre: 'Marta Díaz',
        pistaId: pis(6),   pistaNombre: 'Cancha Baloncesto B',
        inicio: slot(f(8), 9, 0),   fin: fin(slot(f(8), 9, 0)),
      ),
    ];

    // ── Reservas de equipo ──────────────────────────────────────────────────
    // Para las reservas de equipo necesitamos también los IDs de equipos.
    // Se crean con el entrenador como usuarioId y equipoId/equipoNombre rellenos.
    // Los jugadores del equipo las verán en su home automáticamente.
    final equiposSnap = await _equipos.get();
    final equiposList = equiposSnap.docs;

    final reservasEquipo = <Map<String, dynamic>>[];

    if (equiposList.isNotEmpty) {
      final eq0      = equiposList[0];
      final eq0Data  = eq0.data();
      final eq0EntId     = eq0Data['entrenadorId']     as String? ?? '';
      final eq0EntNombre = eq0Data['entrenadorNombre'] as String? ?? '';
      final eq0Nombre    = eq0Data['nombre']           as String? ?? '';

      // Pasada: hace 3 días a las 9:00
      reservasEquipo.add({
        'usuarioId':        eq0EntId,
        'usuarioNombre':    eq0EntNombre,
        'pistaId':          courtIds.length > 3 ? courtIds[3] : 'c3',
        'pistaNombre':      'Fútbol 7 Norte',
        'fecha':            Timestamp.fromDate(
            DateTime(d(3).year, d(3).month, d(3).day)),
        'horaInicio':       Timestamp.fromDate(
            DateTime(d(3).year, d(3).month, d(3).day, 9, 0)),
        'horaFin':          Timestamp.fromDate(
            DateTime(d(3).year, d(3).month, d(3).day, 10, 30)),
        'cancelada':        false,
        'notas':            'Entrenamiento semanal del equipo',
        'equipoId':         eq0.id,
        'equipoNombre':     eq0Nombre,
        'creadaPorAdminId': null,
        'createdAt':        FieldValue.serverTimestamp(),
      });

      // Futura: en 2 días a las 13:30
      reservasEquipo.add({
        'usuarioId':        eq0EntId,
        'usuarioNombre':    eq0EntNombre,
        'pistaId':          courtIds.length > 3 ? courtIds[3] : 'c3',
        'pistaNombre':      'Fútbol 7 Norte',
        'fecha':            Timestamp.fromDate(
            DateTime(f(2).year, f(2).month, f(2).day)),
        'horaInicio':       Timestamp.fromDate(
            DateTime(f(2).year, f(2).month, f(2).day, 13, 30)),
        'horaFin':          Timestamp.fromDate(
            DateTime(f(2).year, f(2).month, f(2).day, 15, 0)),
        'cancelada':        false,
        'notas':            'Preparación partido del domingo',
        'equipoId':         eq0.id,
        'equipoNombre':     eq0Nombre,
        'creadaPorAdminId': null,
        'createdAt':        FieldValue.serverTimestamp(),
      });
    }

    if (equiposList.length >= 2) {
      final eq1 = equiposList[1];
      final eq1Data      = eq1.data();
      final eq1EntId     = eq1Data['entrenadorId']     as String? ?? '';
      final eq1EntNombre = eq1Data['entrenadorNombre'] as String? ?? '';
      final eq1Nombre    = eq1Data['nombre']           as String? ?? '';

      // Futura: en 5 días a las 16:30
      reservasEquipo.add({
        'usuarioId':        eq1EntId,
        'usuarioNombre':    eq1EntNombre,
        'pistaId':          courtIds.length > 5 ? courtIds[5] : 'c5',
        'pistaNombre':      'Cancha Baloncesto A',
        'fecha':            Timestamp.fromDate(
            DateTime(f(5).year, f(5).month, f(5).day)),
        'horaInicio':       Timestamp.fromDate(
            DateTime(f(5).year, f(5).month, f(5).day, 16, 30)),
        'horaFin':          Timestamp.fromDate(
            DateTime(f(5).year, f(5).month, f(5).day, 18, 0)),
        'cancelada':        false,
        'notas':            'Sesión táctica previa al torneo',
        'equipoId':         eq1.id,
        'equipoNombre':     eq1Nombre,
        'creadaPorAdminId': null,
        'createdAt':        FieldValue.serverTimestamp(),
      });
    }

    for (final r in reservasEquipo) {
      await _reservas.add(r);
    }

    for (final r in [...pasadas, ...futuras]) {
      await _reservas.add(r);
    }
  }
  Map<String, dynamic> _reserva({
    required String usuarioId,
    required String usuarioNombre,
    required String pistaId,
    required String pistaNombre,
    required DateTime inicio,
    required DateTime fin,
    String? notas,
    bool cancelada = false,
  }) {
    final fecha = DateTime(inicio.year, inicio.month, inicio.day);
    return {
      'usuarioId':        usuarioId,
      'usuarioNombre':    usuarioNombre,
      'pistaId':          pistaId,
      'pistaNombre':      pistaNombre,
      'fecha':            Timestamp.fromDate(fecha),
      'horaInicio':       Timestamp.fromDate(inicio),
      'horaFin':          Timestamp.fromDate(fin),
      'cancelada':        cancelada,
      'notas':            notas,
      'creadaPorAdminId': null,
      'createdAt':        FieldValue.serverTimestamp(),
    };
  }

  // ── Clear ────────────────────────────────────────────────────────────────

  /// Borra todos los datos de prueba preservando los usuarios con rol 'admin'.
  Future<String> clearAll() async {
    final adminIds = await _clearUsuarios();
    await _clearCollection('pistas');
    await _clearCollection('equipos');
    await _clearCollection('reservas');

    return '🗑️ Datos eliminados correctamente.\n'
        '✅ ${adminIds.length} admin${adminIds.length == 1 ? '' : 's'} conservado${adminIds.length == 1 ? '' : 's'}.\n\n'
        '⚠️ Los usuarios no-admin de Firebase Auth deben borrarse manualmente desde la consola de Firebase.';
  }

  /// Borra de Firestore todos los usuarios que NO sean admin.
  /// Devuelve los IDs de los admins conservados.
  Future<List<String>> _clearUsuarios() async {
    final snap = await _db.collection('usuarios').get();
    final batch = _db.batch();
    final adminIds = <String>[];

    for (final doc in snap.docs) {
      final rol = doc.data()['rol'] as String?;
      if (rol == 'admin') {
        adminIds.add(doc.id);
      } else {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
    return adminIds;
  }

  Future<void> _clearCollection(String name) async {
    final snap = await _db.collection(name).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}