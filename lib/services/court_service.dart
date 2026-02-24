import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gesport/models/court.dart';

class CourtService {
  final _col = FirebaseFirestore.instance.collection('pistas');

  Stream<List<CourtModel>> getCourts() {
    return _col.orderBy('nombre').snapshots().map(
          (snap) => snap.docs
          .map((d) => CourtModel.fromMap(d.id, d.data()))
          .toList(),
    );
  }

  Stream<List<CourtModel>> getActiveCourts() {
    return _col
        .where('activa', isEqualTo: true)
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((d) => CourtModel.fromMap(d.id, d.data()))
          .toList(),
    );
  }

  Future<void> createCourt(CourtModel court) async {
    await _col.add({
      ...court.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCourt(CourtModel court) async {
    await _col.doc(court.id).update({
      ...court.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCourt(String id) async {
    await _col.doc(id).delete();
  }
}