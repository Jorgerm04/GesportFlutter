import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gesport/models/booking.dart';
import 'package:rxdart/rxdart.dart';

class BookingService {
  final _col     = FirebaseFirestore.instance.collection('reservas');
  final _equipos = FirebaseFirestore.instance.collection('equipos');

  // ── Helpers ──────────────────────────────────────────────────────────────
  List<BookingModel> _map(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));

  // ── Streams ──────────────────────────────────────────────────────────────
  Stream<List<BookingModel>> getAllBookings() =>
      _col.orderBy('fecha', descending: true).snapshots().map(_map);

  Stream<List<BookingModel>> _getUserBookings(String userId) =>
      _col.where('usuarioId', isEqualTo: userId).snapshots().map(_map);

  Stream<List<BookingModel>> _getEquipoBookings(String equipoId) =>
      _col.where('equipoId', isEqualTo: equipoId).snapshots().map(_map);

  Stream<List<BookingModel>> getPartidosArbitro(String arbitroId) =>
      _col.where('arbitroId', isEqualTo: arbitroId).snapshots().map(_map);

  /// Combina reservas individuales + de todos los equipos del usuario.
  Stream<List<BookingModel>> getAllUserRelatedBookings(
      String userId, List<String> equipoIds) {
    final individual = _getUserBookings(userId);
    if (equipoIds.isEmpty) return individual;
    return Rx.combineLatestList<List<BookingModel>>(
      [individual, ...equipoIds.map(_getEquipoBookings)],
    ).map((lists) {
      final seen = <String>{};
      return [
        for (final list in lists)
          for (final b in list)
            if (seen.add(b.id)) b
      ]..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    });
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────
  Future<void> createBooking(BookingModel b) =>
      _col.add({...b.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> updateBooking(BookingModel b) =>
      _col.doc(b.id).update({...b.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> setCancelada(String id, bool v) =>
      _col.doc(id).update({'cancelada': v});

  Future<void> deleteBooking(String id) => _col.doc(id).delete();

  // ── Equipos ───────────────────────────────────────────────────────────────
  Future<List<Map<String, String>>> getEquiposDelUsuario(String userId) async {
    final seen = <String>{};
    final result = <Map<String, String>>[];
    void add(QueryDocumentSnapshot<Map<String, dynamic>> d) {
      if (!seen.add(d.id)) return;
      final data = d.data();
      result.add({
        'id': d.id,
        'nombre':           data['nombre']           as String? ?? '',
        'entrenadorId':     data['entrenadorId']     as String? ?? '',
        'entrenadorNombre': data['entrenadorNombre'] as String? ?? '',
        'deporte':          data['deporte']          as String? ?? '',
      });
    }
    final asCoach  = await _equipos.where('entrenadorId',  isEqualTo: userId).get();
    final asPlayer = await _equipos.where('jugadoresIds', arrayContains: userId).get();
    for (final d in asCoach.docs)  add(d);
    for (final d in asPlayer.docs) add(d);
    return result;
  }

  Future<List<Map<String, String>>> getEquiposComoEntrenador(String userId) async {
    final snap = await _equipos.where('entrenadorId', isEqualTo: userId).get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'nombre':           data['nombre']           as String? ?? '',
        'entrenadorId':     data['entrenadorId']     as String? ?? '',
        'entrenadorNombre': data['entrenadorNombre'] as String? ?? '',
        'deporte':          data['deporte']          as String? ?? '',
      };
    }).toList();
  }

  // ── Disponibilidad (FIX: filtra por fecha en Firestore) ──────────────────
  Future<List<BookingModel>> getCourtBookingsForDay(
      String courtId, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final snap = await _col
        .where('pistaId', isEqualTo: courtId)
        .where('fecha',   isEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    return snap.docs
        .map((d) => BookingModel.fromMap(d.id, d.data()))
        .where((b) => !b.cancelada)
        .toList();
  }

  Future<bool> hasConflict({
    required String courtId,
    required DateTime inicio,
    required DateTime fin,
    String? excludeId,
  }) async {
    final startOfDay = DateTime(inicio.year, inicio.month, inicio.day);
    final snap = await _col
        .where('pistaId', isEqualTo: courtId)
        .where('fecha',   isEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final b = BookingModel.fromMap(doc.id, doc.data());
      if (b.cancelada) continue;
      if (inicio.isBefore(b.fechaFin) && fin.isAfter(b.fechaInicio)) return true;
    }
    return false;
  }

  /// Todos los equipos (para modo admin en el formulario de reservas).
  Future<List<Map<String, String>>> getAllEquipos() async {
    final snap = await _equipos.orderBy('nombre').get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id':               d.id,
        'nombre':           data['nombre']           as String? ?? '',
        'entrenadorId':     data['entrenadorId']     as String? ?? '',
        'entrenadorNombre': data['entrenadorNombre'] as String? ?? '',
        'deporte':          data['deporte']          as String? ?? '',
      };
    }).toList();
  }
}
