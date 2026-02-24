import 'package:flutter/material.dart';
import 'package:gesport/models/team.dart';
import 'package:gesport/services/team_service.dart';
import 'package:gesport/screens/team_form_screen.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  Future<void> _delete(BuildContext context, TeamModel team) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1A2F),
        title: const Text('Eliminar equipo',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Seguro que quieres eliminar "${team.nombre}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) await TeamService().deleteTeam(team.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Gestión de Equipos',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0E5CAD),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamFormScreen()),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<TeamModel>>(
            stream: TeamService().getTeams(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              final teams = snap.data ?? [];
              if (teams.isEmpty) {
                return const Center(
                  child: Text('No hay equipos creados',
                      style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: teams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final team = teams[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor:
                        Colors.orangeAccent.withOpacity(0.2),
                        child: const Icon(Icons.groups_rounded,
                            color: Colors.orangeAccent),
                      ),
                      title: Text(team.nombre,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (team.descripcion.isNotEmpty)
                            Text(team.descripcion,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _chip(
                                Icons.person_pin,
                                team.entrenadorNombre ?? 'Sin entrenador',
                                Colors.blueAccent,
                              ),
                              const SizedBox(width: 8),
                              _chip(
                                Icons.sports_soccer,
                                '${team.jugadoresIds.length} jugadores',
                                Colors.greenAccent,
                              ),
                            ],
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
                                  builder: (_) =>
                                      TeamFormScreen(team: team)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _delete(context, team),
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

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}