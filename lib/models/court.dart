import 'package:cloud_firestore/cloud_firestore.dart';

enum CourtType { padel, futbol, baloncesto, tenis, voley, otro }

extension CourtTypeExtension on CourtType {
  String get label {
    switch (this) {
      case CourtType.padel:       return 'Pádel';
      case CourtType.futbol:      return 'Fútbol';
      case CourtType.baloncesto:  return 'Baloncesto';
      case CourtType.tenis:       return 'Tenis';
      case CourtType.voley:       return 'Voley';
      case CourtType.otro:        return 'Otro';
    }
  }

  static CourtType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'futbol':     return CourtType.futbol;
      case 'baloncesto': return CourtType.baloncesto;
      case 'tenis':      return CourtType.tenis;
      case 'voley':      return CourtType.voley;
      case 'otro':       return CourtType.otro;
      default:           return CourtType.padel;
    }
  }
}

class CourtModel {
  final String id;
  final String nombre;
  final CourtType tipo;
  final String descripcion;
  final bool activa;
  final double precioPorHora;
  final DateTime? createdAt;

  const CourtModel({
    required this.id,
    required this.nombre,
    this.tipo = CourtType.padel,
    this.descripcion = '',
    this.activa = true,
    this.precioPorHora = 0.0,
    this.createdAt,
  });

  factory CourtModel.fromMap(String id, Map<String, dynamic> data) {
    return CourtModel(
      id: id,
      nombre: data['nombre'] ?? '',
      tipo: CourtTypeExtension.fromString(data['tipo']),
      descripcion: data['descripcion'] ?? '',
      activa: data['activa'] ?? true,
      precioPorHora: (data['precioPorHora'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipo': tipo.name,
      'descripcion': descripcion,
      'activa': activa,
      'precioPorHora': precioPorHora,
    };
  }
}