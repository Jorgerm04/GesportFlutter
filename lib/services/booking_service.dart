import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gesport/models/booking.dart';
import 'package:rxdart/rxdart.dart';

class BookingService {
  final _col = FirebaseFirestore.instance.collection('reservas');
  final _equipos = FirebaseFirestore.instance.collection('equipos');

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<BookingModel>> getAllBookings() {
    return _col
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return list;
    });
  }

  /// Reservas individuales del usuario (sin equipo)
  Stream<List<BookingModel>> getUserBookings(String userId) {
    return _col
        .where('usuarioId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return list;
    });
  }

  /// Reservas de un equipo concreto
  Stream<List<BookingModel>> getEquipoBookings(String equipoId) {
    return _col
        .where('equipoId', isEqualTo: equipoId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return list;
    });
  }

  /// Stream combinado para la home del jugador/entrenador:
  /// une sus reservas individuales + reservas de todos sus equipos.
  /// [equipoIds] = IDs de equipos en los que el usuario es jugador o entrenador.
  Stream<List<BookingModel>> getAllUserRelatedBookings(
      String userId, List<String> equipoIds) {
    // Stream de reservas individuales
    final individualStream = getUserBookings(userId);

    if (equipoIds.isEmpty) return individualStream;

    // Un stream por equipo
    final equipoStreams = equipoIds
        .map((eid) => getEquipoBookings(eid))
        .toList();

    // Combinar todos con rxdart CombineLatest
    return Rx.combineLatestList<List<BookingModel>>(
      [individualStream, ...equipoStreams],
    ).map((lists) {
      final seen = <String>{};
      final merged = <BookingModel>[];
      for (final list in lists) {
        for (final b in list) {
          if (seen.add(b.id)) merged.add(b);
        }
      }
      merged.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return merged;
    });
  }

  Stream<List<BookingModel>> getCourtBookings(String courtId) {
    return _col
        .where('pistaId', isEqualTo: courtId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return list;
    });
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> createBooking(BookingModel booking) async {
    await _col.add({
      ...booking.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBooking(BookingModel booking) async {
    await _col.doc(booking.id).update({
      ...booking.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCancelada(String id, bool cancelada) async {
    await _col.doc(id).update({'cancelada': cancelada});
  }

  Future<void> deleteBooking(String id) async {
    await _col.doc(id).delete();
  }

  // ── Equipos del usuario ──────────────────────────────────────────────────

  /// Devuelve los equipos en los que el usuario es jugador O entrenador.
  Future<List<Map<String, String>>> getEquiposDelUsuario(
      String userId) async {
    final result = <Map<String, String>>[];
    final seen = <String>{};

    // Como entrenador
    final asCoach = await _equipos
        .where('entrenadorId', isEqualTo: userId)
        .get();
    for (final d in asCoach.docs) {
      if (seen.add(d.id)) {
        result.add({'id': d.id, 'nombre': d.data()['nombre'] ?? ''});
      }
    }

    // Como jugador
    final asPlayer = await _equipos
        .where('jugadoresIds', arrayContains: userId)
        .get();
    for (final d in asPlayer.docs) {
      if (seen.add(d.id)) {
        result.add({'id': d.id, 'nombre': d.data()['nombre'] ?? ''});
      }
    }

    return result;
  }

  /// Devuelve solo los equipos donde el usuario es entrenador
  /// (puede crear reservas de equipo).
  Future<List<Map<String, String>>> getEquiposComoEntrenador(
      String userId) async {
    final snap = await _equipos
        .where('entrenadorId', isEqualTo: userId)
        .get();
    return snap.docs
        .map((d) => {'id': d.id, 'nombre': d.data()['nombre'] as String? ?? ''})
        .toList();
  }

  // ── Disponibilidad ───────────────────────────────────────────────────────

  Future<List<BookingModel>> getCourtBookingsForDay(
      String courtId, DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay   = startOfDay.add(const Duration(days: 1));

    final snap = await _col.where('pistaId', isEqualTo: courtId).get();

    return snap.docs
        .map((d) => BookingModel.fromMap(d.id, d.data()))
        .where((b) =>
    !b.cancelada &&
        b.fechaInicio.isBefore(endOfDay) &&
        b.fechaFin.isAfter(startOfDay))
        .toList();
  }

  Future<bool> hasConflict({
    required String courtId,
    required DateTime inicio,
    required DateTime fin,
    String? excludeId,
  }) async {
    final snap = await _col.where('pistaId', isEqualTo: courtId).get();

    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final b = BookingModel.fromMap(doc.id, doc.data());
      if (b.cancelada) continue;
      if (inicio.isBefore(b.fechaFin) && fin.isAfter(b.fechaInicio)) {
        return true;
      }
    }
    return false;
  }
}