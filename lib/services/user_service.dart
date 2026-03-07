import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gesport/models/user.dart';

class UserService {
  final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('usuarios');
  final CollectionReference<Map<String, dynamic>> _equipos =
  FirebaseFirestore.instance.collection('equipos');

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<UserModel>> getAllUsers() {
    return _col.snapshots().map((snap) => snap.docs
        .map((d) => UserModel.fromMap(d.id, d.data()))
        .toList());
  }

  // ── Consultas ─────────────────────────────────────────────────────────────

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  /// Devuelve el equipo asociado al usuario según su rol.
  Future<Map<String, dynamic>?> getEquipoDelUsuario(
      String uid, UserRole role) async {
    QuerySnapshot snap;

    if (role == UserRole.jugador) {
      snap = await _equipos
          .where('jugadoresIds', arrayContains: uid)
          .limit(1)
          .get();
    } else {
      snap = await _equipos
          .where('entrenadorId', isEqualTo: uid)
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) return null;

    return {
      'id': snap.docs.first.id,
      ...snap.docs.first.data() as Map<String, dynamic>,
    };
  }

  // ── Registro ──────────────────────────────────────────────────────────────

  /// Sincroniza Firestore tras el registro en Auth.
  ///
  /// - Si el admin ya había creado el perfil (existe doc con ese email),
  ///   lo migra al UID real de Auth y borra el doc antiguo.
  /// - Si es un registro nuevo, crea el doc desde cero con rol 'jugador'.
  Future<void> syncAfterRegister({
    required String uid,
    required String nombre,
    required String email,
    required String phone,
    required int?   age,
  }) async {
    final existing = await _col
        .where('email', isEqualTo: email)
        .get();

    if (existing.docs.isNotEmpty) {
      // Caso A: el admin ya creó el perfil → migrar al UID real
      final oldDoc     = existing.docs.first;
      final oldData    = oldDoc.data() as Map<String, dynamic>;

      await _col.doc(uid).set({
        'nombre':    nombre,
        'email':     email,
        'phone':     phone,
        'age':       age,
        'rol':       oldData['rol'] ?? 'jugador',
        'createdAt': oldData['createdAt'] ?? FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Borrar doc antiguo solo si tenía un ID diferente al UID
      if (oldDoc.id != uid) {
        await _col.doc(oldDoc.id).delete();
      }
    } else {
      // Caso B: registro totalmente nuevo
      await _col.doc(uid).set({
        'nombre':    nombre,
        'email':     email,
        'phone':     phone,
        'age':       age,
        'rol':       'jugador',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> createUser(Map<String, dynamic> data) async {
    await _col.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _col.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String uid) async {
    await _col.doc(uid).delete();
  }

  /// Devuelve todos los usuarios de un rol dado.
  Future<List<Map<String, dynamic>>> getUsersByRole(List<String> roles) async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((u) => roles.contains(u['rol'] ?? 'jugador'))
        .toList();
  }

  /// Busca un usuario primero por UID, luego por email (fallback legacy).
  Future<UserModel?> getUserByUidOrEmail(String uid, String email) async {
    final byUid = await _col.doc(uid).get();
    if (byUid.exists) return UserModel.fromMap(uid, byUid.data()!);

    final byEmail = await _col
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (byEmail.docs.isEmpty) return null;
    final doc = byEmail.docs.first;
    return UserModel.fromMap(doc.id, doc.data());
  }
}
