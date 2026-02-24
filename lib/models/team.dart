import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String? entrenadorId;
  final String? entrenadorNombre;
  final List<String> jugadoresIds;
  final DateTime? createdAt;

  const TeamModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.entrenadorId,
    this.entrenadorNombre,
    this.jugadoresIds = const [],
    this.createdAt,
  });

  factory TeamModel.fromMap(String id, Map<String, dynamic> data) {
    return TeamModel(
      id: id,
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      entrenadorId: data['entrenadorId'],
      entrenadorNombre: data['entrenadorNombre'],
      jugadoresIds: List<String>.from(data['jugadoresIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'entrenadorId': entrenadorId,
      'entrenadorNombre': entrenadorNombre,
      'jugadoresIds': jugadoresIds,
    };
  }

  TeamModel copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? entrenadorId,
    String? entrenadorNombre,
    List<String>? jugadoresIds,
    DateTime? createdAt,
  }) {
    return TeamModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      entrenadorId: entrenadorId ?? this.entrenadorId,
      entrenadorNombre: entrenadorNombre ?? this.entrenadorNombre,
      jugadoresIds: jugadoresIds ?? this.jugadoresIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}