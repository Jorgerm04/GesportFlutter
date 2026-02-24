import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String pistaId;
  final String pistaNombre;

  /// Día de la reserva (solo año/mes/día, hora siempre 00:00)
  final DateTime fecha;
  /// Hora de inicio (solo hora y minutos importan)
  final DateTime horaInicio;
  /// Hora de fin (solo hora y minutos importan)
  final DateTime horaFin;

  final bool cancelada;
  final String? notas;
  final String? creadaPorAdminId;
  final DateTime? createdAt;

  /// Si no es null, esta reserva pertenece a un equipo
  final String? equipoId;
  final String? equipoNombre;

  bool get esDeEquipo => equipoId != null && equipoId!.isNotEmpty;

  const BookingModel({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.pistaId,
    required this.pistaNombre,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    this.cancelada = false,
    this.notas,
    this.creadaPorAdminId,
    this.createdAt,
    this.equipoId,
    this.equipoNombre,
  });

  /// DateTime completo de inicio (fecha + horaInicio) para comparaciones
  DateTime get fechaInicio => DateTime(
    fecha.year, fecha.month, fecha.day,
    horaInicio.hour, horaInicio.minute,
  );

  /// DateTime completo de fin (fecha + horaFin) para comparaciones
  DateTime get fechaFin => DateTime(
    fecha.year, fecha.month, fecha.day,
    horaFin.hour, horaFin.minute,
  );

  factory BookingModel.fromMap(String id, Map<String, dynamic> data) {
    // Retrocompatibilidad: documentos que aún usan fechaInicio/fechaFin
    final legacyInicio = (data['fechaInicio'] as Timestamp?)?.toDate();
    final legacyFin    = (data['fechaFin']    as Timestamp?)?.toDate();

    final DateTime fechaVal;
    final DateTime horaInicioVal;
    final DateTime horaFinVal;

    if (data.containsKey('fecha')) {
      // Nuevo esquema
      fechaVal      = (data['fecha']      as Timestamp).toDate();
      horaInicioVal = (data['horaInicio'] as Timestamp).toDate();
      horaFinVal    = (data['horaFin']    as Timestamp).toDate();
    } else if (legacyInicio != null && legacyFin != null) {
      // Esquema antiguo: extraer los tres campos de los dos timestamps
      fechaVal      = DateTime(legacyInicio.year, legacyInicio.month, legacyInicio.day);
      horaInicioVal = legacyInicio;
      horaFinVal    = legacyFin;
    } else {
      final now = DateTime.now();
      fechaVal      = DateTime(now.year, now.month, now.day);
      horaInicioVal = now;
      horaFinVal    = now.add(const Duration(hours: 1, minutes: 30));
    }

    // Retrocompat estado legacy 'cancelada'
    final estadoLegacy    = data['estado'] as String?;
    final canceladaLegacy = estadoLegacy?.toLowerCase() == 'cancelada';

    return BookingModel(
      id:               id,
      usuarioId:        data['usuarioId']       ?? '',
      usuarioNombre:    data['usuarioNombre']    ?? '',
      pistaId:          data['pistaId']          ?? '',
      pistaNombre:      data['pistaNombre']      ?? '',
      fecha:            fechaVal,
      horaInicio:       horaInicioVal,
      horaFin:          horaFinVal,
      cancelada:        (data['cancelada'] as bool?) ?? canceladaLegacy,
      notas:            data['notas'],
      creadaPorAdminId: data['creadaPorAdminId'],
      createdAt:        (data['createdAt'] as Timestamp?)?.toDate(),
      equipoId:         data['equipoId'],
      equipoNombre:     data['equipoNombre'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId':        usuarioId,
      'usuarioNombre':    usuarioNombre,
      'pistaId':          pistaId,
      'pistaNombre':      pistaNombre,
      'fecha':            Timestamp.fromDate(
          DateTime(fecha.year, fecha.month, fecha.day)),
      'horaInicio':       Timestamp.fromDate(DateTime(
          fecha.year, fecha.month, fecha.day,
          horaInicio.hour, horaInicio.minute)),
      'horaFin':          Timestamp.fromDate(DateTime(
          fecha.year, fecha.month, fecha.day,
          horaFin.hour, horaFin.minute)),
      'cancelada':        cancelada,
      'notas':            notas,
      'creadaPorAdminId': creadaPorAdminId,
      'equipoId':         equipoId,
      'equipoNombre':     equipoNombre,
    };
  }

  BookingModel copyWith({
    String?   id,
    String?   usuarioId,
    String?   usuarioNombre,
    String?   pistaId,
    String?   pistaNombre,
    DateTime? fecha,
    DateTime? horaInicio,
    DateTime? horaFin,
    bool?     cancelada,
    String?   notas,
    String?   creadaPorAdminId,
    DateTime? createdAt,
    String?   equipoId,
    String?   equipoNombre,
  }) {
    return BookingModel(
      id:               id               ?? this.id,
      usuarioId:        usuarioId        ?? this.usuarioId,
      usuarioNombre:    usuarioNombre    ?? this.usuarioNombre,
      pistaId:          pistaId          ?? this.pistaId,
      pistaNombre:      pistaNombre      ?? this.pistaNombre,
      fecha:            fecha            ?? this.fecha,
      horaInicio:       horaInicio       ?? this.horaInicio,
      horaFin:          horaFin          ?? this.horaFin,
      cancelada:        cancelada        ?? this.cancelada,
      notas:            notas            ?? this.notas,
      creadaPorAdminId: creadaPorAdminId ?? this.creadaPorAdminId,
      createdAt:        createdAt        ?? this.createdAt,
      equipoId:         equipoId         ?? this.equipoId,
      equipoNombre:     equipoNombre     ?? this.equipoNombre,
    );
  }
}