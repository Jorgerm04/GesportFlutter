import 'package:flutter/material.dart';
import 'package:gesport/models/team.dart';
import 'package:gesport/services/team_service.dart';
import 'package:gesport/screens/team_form_screen.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';
import 'package:gesport/utils/app_utils.dart';

class TeamsScreen extends StatelessWidget {
  /// Si se pasa [coachId], la pantalla entra en "modo entrenador":
  /// solo muestra los equipos de ese entrenador, sin poder crear/eliminar.
  final String? coachId;
  final String? coachNombre;

  const TeamsScreen({super.key, this.coachId, this.coachNombre});

  bool get _isCoachMode => coachId != null;

  Future<void> _delete(BuildContext context, TeamModel team) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Eliminar equipo',
      content: '¿Seguro que quieres eliminar "${team.nombre}"?',
      confirmLabel: 'Eliminar',
    );
    if (confirm == true) await TeamService().deleteTeam(team.id);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _isCoachMode
        ? TeamService().getTeamsByCoach(coachId!)
        : TeamService().getTeams();

    return AppScaffold(
      title: _isCoachMode ? 'Mis equipos' : 'Gestión de Equipos',
      // FAB solo para admin
      floatingActionButton: _isCoachMode
          ? null
          : FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamFormScreen()),
        ),
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final teams = snap.data ?? [];
          if (teams.isEmpty) {
            return Center(
              child: Text(
                _isCoachMode
                    ? 'No tienes equipos asignados'
                    : 'No hay equipos creados',
                style: const TextStyle(color: Colors.white54),
              ),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (!_isCoachMode)
                            _chip(
                              Icons.person_pin,
                              team.entrenadorNombre ?? 'Sin entrenador',
                              Colors.blueAccent,
                            ),
                          _chip(
                            Icons.sports_soccer,
                            '${team.jugadoresIds.length} jugadores',
                            Colors.greenAccent,
                          ),
                          if (team.deporte != null)
                            _chip(
                              Icons.sports,
                              deporteLabel(team.deporte!),
                              Colors.purpleAccent,
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Editar — en modo entrenador solo jugadores
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white70),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamFormScreen(
                              team:      team,
                              coachMode: _isCoachMode,
                            ),
                          ),
                        ),
                      ),
                      // Eliminar solo para admin
                      if (!_isCoachMode)
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
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}