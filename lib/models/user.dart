enum UserRole { jugador, entrenador, arbitro, admin }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.jugador:
        return 'Jugador';
      case UserRole.entrenador:
        return 'Entrenador';
      case UserRole.arbitro:
        return 'Árbitro';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'entrenador':
        return UserRole.entrenador;
      case 'arbitro':
        return UserRole.arbitro;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.jugador;
    }
  }
}

class UserModel {
  final String uid;
  final String nombre;
  final String email;
  final String phone;
  final int? age;
  final UserRole rol;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.uid,
    required this.nombre,
    required this.email,
    this.phone = '',
    this.age,
    this.rol = UserRole.jugador,
    this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      age: data['age'] != null ? (data['age'] as num).toInt() : null,
      rol: UserRoleExtension.fromString(data['rol']),
      createdAt: data['createdAt']?.toDate(),
      lastLogin: data['lastLogin']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'phone': phone,
      'age': age,
      'rol': rol.name,
    };
  }

  UserModel copyWith({
    String? uid,
    String? nombre,
    String? email,
    String? phone,
    int? age,
    UserRole? rol,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      rol: rol ?? this.rol,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}