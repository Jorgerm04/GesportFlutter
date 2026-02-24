import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gesport/models/team.dart';

class TeamService {
  final _col = FirebaseFirestore.instance.collection('equipos');

  Stream<List<TeamModel>> getTeams() {
    return _col.orderBy('nombre').snapshots().map(
          (snap) => snap.docs
          .map((d) => TeamModel.fromMap(d.id, d.data()))
          .toList(),
    );
  }

  Future<TeamModel?> getTeam(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return TeamModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> createTeam(TeamModel team) async {
    await _col.add({
      ...team.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTeam(TeamModel team) async {
    await _col.doc(team.id).update({
      ...team.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTeam(String id) async {
    await _col.doc(id).delete();
  }

  /// Añade un jugador al equipo (sólo jugadores)
  Future<void> addPlayer(String teamId, String userId) async {
    await _col.doc(teamId).update({
      'jugadoresIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Elimina un jugador del equipo
  Future<void> removePlayer(String teamId, String userId) async {
    await _col.doc(teamId).update({
      'jugadoresIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Asigna (o reemplaza) el entrenador del equipo
  Future<void> setCoach(
      String teamId, String? coachId, String? coachNombre) async {
    await _col.doc(teamId).update({
      'entrenadorId': coachId,
      'entrenadorNombre': coachNombre,
    });
  }
}