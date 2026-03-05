import 'package:flutter/material.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/screens/user_form_screen.dart';
import 'package:gesport/services/user_service.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':      return Colors.deepPurpleAccent;
      case 'entrenador': return Colors.blue.shade800;
      case 'arbitro':    return Colors.yellow;
      case 'jugador':    return Colors.green.shade800;
      default:           return Colors.blueGrey.shade700;
    }
  }

  Future<void> _deleteUser(
      BuildContext context, String uid, String nombre) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Eliminar usuario',
      content: '¿Estás seguro de que quieres eliminar a $nombre?',
      confirmLabel: 'Eliminar',
    );

    if (confirm == true) {
      await UserService().deleteUser(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Gestión de Usuarios',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation:       0,
        iconTheme:       const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child:     const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserFormScreen()),
        ),
      ),
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(
          child: StreamBuilder<List<UserModel>>(
            stream: UserService().getAllUsers(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              final users = snap.data ?? [];

              return ListView.separated(
                padding:          const EdgeInsets.all(16),
                itemCount:        users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final u   = users[i];
                  final rol = u.rol.name;

                  return Container(
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: _getRoleColor(rol).withOpacity(0.2),
                        child: Icon(Icons.person, color: _getRoleColor(rol)),
                      ),
                      title: Text(u.nombre,
                          style: const TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.email,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:        _getRoleColor(rol),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(rol.toUpperCase(),
                                style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.white70),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => UserFormScreen(uid: u.uid)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () =>
                                _deleteUser(context, u.uid, u.nombre),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}