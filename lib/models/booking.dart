import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoReserva { individual, equipo, partido }

extension TipoReservaExtension on TipoReserva {
  String get label {
    switch (this) {
      case TipoReserva.individual: return 'Individual';
      case TipoReserva.equipo:     return 'Equipo';
      case TipoReserva.partido:    return 'Partido';
    }
  }

  static TipoReserva fromString(String? value) {
    switch (value) {
      case 'equipo':  return TipoReserva.equipo;
      case 'partido': return TipoReserva.partido;
      default:        return TipoReserva.individual;
    }
  }
}

class BookingModel {
  final String id;

  /// Para individual/equipo: ID del usuario/entrenador.
  /// Para partido: vacío (no aplica).
  final String usuarioId;
  final String usuarioNombre;

  final String pistaId;
  final String pistaNombre;

  final DateTime fecha;
  final DateTime horaInicio;
  final DateTime horaFin;

  final bool    cancelada;
  final String? notas;
  final DateTime? createdAt;

  // ── Campos de reserva de equipo ──────────────────────────────────────────
  final String? equipoId;
  final String? equipoNombre;

  // ── Campos de reserva de partido ────────────────────────────────────────
  final String? equipoLocalId;
  final String? equipoLocalNombre;
  final String? equipoVisitanteId;
  final String? equipoVisitanteNombre;
  final String? arbitroId;
  final String? arbitroNombre;
  final int?    puntosLocal;
  final int?    puntosVisitante;
  final String? deporte;

  // ── Tipo ─────────────────────────────────────────────────────────────────
  final TipoReserva tipo;

  bool get esDeEquipo  => tipo == TipoReserva.equipo;
  bool get esPartido   => tipo == TipoReserva.partido;
  bool get esIndividual=> tipo == TipoReserva.individual;

  /// Resultado formateado, null si no hay puntos
  String? get resultado {
    if (puntosLocal == null || puntosVisitante == null) return null;
    return '$puntosLocal – $puntosVisitante';
  }

  const BookingModel({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.pistaId,
    required this.pistaNombre,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    this.cancelada        = false,
    this.notas,
    this.createdAt,
    this.equipoId,
    this.equipoNombre,
    this.equipoLocalId,
    this.equipoLocalNombre,
    this.equipoVisitanteId,
    this.equipoVisitanteNombre,
    this.arbitroId,
    this.arbitroNombre,
    this.puntosLocal,
    this.puntosVisitante,
    this.deporte,
    this.tipo             = TipoReserva.individual,
  });

  DateTime get fechaInicio => DateTime(
    fecha.year, fecha.month, fecha.day,
    horaInicio.hour, horaInicio.minute,
  );

  DateTime get fechaFin => DateTime(
    fecha.year, fecha.month, fecha.day,
    horaFin.hour, horaFin.minute,
  );

  factory BookingModel.fromMap(String id, Map<String, dynamic> data) {
    // Retrocompat fechaInicio/fechaFin
    final legacyInicio = (data['fechaInicio'] as Timestamp?)?.toDate();
    final legacyFin    = (data['fechaFin']    as Timestamp?)?.toDate();

    final DateTime fechaVal;
    final DateTime horaInicioVal;
    final DateTime horaFinVal;

    if (data.containsKey('fecha')) {
      fechaVal      = (data['fecha']      as Timestamp).toDate();
      horaInicioVal = (data['horaInicio'] as Timestamp).toDate();
      horaFinVal    = (data['horaFin']    as Timestamp).toDate();
    } else if (legacyInicio != null && legacyFin != null) {
      fechaVal      = DateTime(legacyInicio.year, legacyInicio.month, legacyInicio.day);
      horaInicioVal = legacyInicio;
      horaFinVal    = legacyFin;
    } else {
      final now = DateTime.now();
      fechaVal      = DateTime(now.year, now.month, now.day);
      horaInicioVal = now;
      horaFinVal    = now.add(const Duration(hours: 1, minutes: 30));
    }

    final estadoLegacy    = data['estado'] as String?;
    final canceladaLegacy = estadoLegacy?.toLowerCase() == 'cancelada';

    // Retrocompat: si tiene equipoId pero no tipo → es reserva de equipo
    String? tipoStr = data['tipo'] as String?;
    if (tipoStr == null && (data['equipoId'] as String?)?.isNotEmpty == true) {
      tipoStr = 'equipo';
    }

    return BookingModel(
      id:                    id,
      usuarioId:             data['usuarioId']             ?? '',
      usuarioNombre:         data['usuarioNombre']         ?? '',
      pistaId:               data['pistaId']               ?? '',
      pistaNombre:           data['pistaNombre']           ?? '',
      fecha:                 fechaVal,
      horaInicio:            horaInicioVal,
      horaFin:               horaFinVal,
      cancelada:             (data['cancelada'] as bool?)  ?? canceladaLegacy,
      notas:                 data['notas'],
      createdAt:             (data['createdAt'] as Timestamp?)?.toDate(),
      equipoId:              data['equipoId'],
      equipoNombre:          data['equipoNombre'],
      equipoLocalId:         data['equipoLocalId'],
      equipoLocalNombre:     data['equipoLocalNombre'],
      equipoVisitanteId:     data['equipoVisitanteId'],
      equipoVisitanteNombre: data['equipoVisitanteNombre'],
      arbitroId:             data['arbitroId'],
      arbitroNombre:         data['arbitroNombre'],
      puntosLocal:           data['puntosLocal']     != null
          ? (data['puntosLocal']     as num).toInt()
          : null,
      puntosVisitante:       data['puntosVisitante'] != null
          ? (data['puntosVisitante'] as num).toInt()
          : null,
      deporte:               data['deporte'],
      tipo:                  TipoReservaExtension.fromString(tipoStr),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo':                  tipo.name,
      'usuarioId':             usuarioId,
      'usuarioNombre':         usuarioNombre,
      'pistaId':               pistaId,
      'pistaNombre':           pistaNombre,
      'fecha':                 Timestamp.fromDate(
          DateTime(fecha.year, fecha.month, fecha.day)),
      'horaInicio':            Timestamp.fromDate(DateTime(
          fecha.year, fecha.month, fecha.day,
          horaInicio.hour, horaInicio.minute)),
      'horaFin':               Timestamp.fromDate(DateTime(
          fecha.year, fecha.month, fecha.day,
          horaFin.hour, horaFin.minute)),
      'cancelada':             cancelada,
      'notas':                 notas,
      // Equipo
      'equipoId':              equipoId,
      'equipoNombre':          equipoNombre,
      // Partido
      'equipoLocalId':         equipoLocalId,
      'equipoLocalNombre':     equipoLocalNombre,
      'equipoVisitanteId':     equipoVisitanteId,
      'equipoVisitanteNombre': equipoVisitanteNombre,
      'arbitroId':             arbitroId,
      'arbitroNombre':         arbitroNombre,
      'puntosLocal':           puntosLocal,
      'puntosVisitante':       puntosVisitante,
      'deporte':               deporte,
    };
  }

  BookingModel copyWith({
    String?       id,
    String?       usuarioId,
    String?       usuarioNombre,
    String?       pistaId,
    String?       pistaNombre,
    DateTime?     fecha,
    DateTime?     horaInicio,
    DateTime?     horaFin,
    bool?         cancelada,
    String?       notas,
    DateTime?     createdAt,
    String?       equipoId,
    String?       equipoNombre,
    String?       equipoLocalId,
    String?       equipoLocalNombre,
    String?       equipoVisitanteId,
    String?       equipoVisitanteNombre,
    String?       arbitroId,
    String?       arbitroNombre,
    int?          puntosLocal,
    int?          puntosVisitante,
    String?       deporte,
    TipoReserva?  tipo,
  }) {
    return BookingModel(
      id:                    id                    ?? this.id,
      usuarioId:             usuarioId             ?? this.usuarioId,
      usuarioNombre:         usuarioNombre         ?? this.usuarioNombre,
      pistaId:               pistaId               ?? this.pistaId,
      pistaNombre:           pistaNombre           ?? this.pistaNombre,
      fecha:                 fecha                 ?? this.fecha,
      horaInicio:            horaInicio            ?? this.horaInicio,
      horaFin:               horaFin               ?? this.horaFin,
      cancelada:             cancelada             ?? this.cancelada,
      notas:                 notas                 ?? this.notas,
      createdAt:             createdAt             ?? this.createdAt,
      equipoId:              equipoId              ?? this.equipoId,
      equipoNombre:          equipoNombre          ?? this.equipoNombre,
      equipoLocalId:         equipoLocalId         ?? this.equipoLocalId,
      equipoLocalNombre:     equipoLocalNombre     ?? this.equipoLocalNombre,
      equipoVisitanteId:     equipoVisitanteId     ?? this.equipoVisitanteId,
      equipoVisitanteNombre: equipoVisitanteNombre ?? this.equipoVisitanteNombre,
      arbitroId:             arbitroId             ?? this.arbitroId,
      arbitroNombre:         arbitroNombre         ?? this.arbitroNombre,
      puntosLocal:           puntosLocal           ?? this.puntosLocal,
      puntosVisitante:       puntosVisitante       ?? this.puntosVisitante,
      deporte:               deporte               ?? this.deporte,
      tipo:                  tipo                  ?? this.tipo,
    );
  }
}