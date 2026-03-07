import 'package:flutter/material.dart';
import 'package:gesport/models/court.dart';
import 'package:gesport/services/court_service.dart';
import 'package:gesport/screens/court_form_screen.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';

class CourtsScreen extends StatelessWidget {
  const CourtsScreen({super.key});

  Future<void> _delete(BuildContext context, CourtModel court) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Eliminar pista',
      content: '¿Seguro que quieres eliminar "${court.nombre}"?',
      confirmLabel: 'Eliminar',
    );
    if (confirm == true) await CourtService().deleteCourt(court.id);
  }

  IconData _courtIcon(CourtType tipo) {
    switch (tipo) {
      case CourtType.padel:       return Icons.sports_tennis;
      case CourtType.futbol:      return Icons.sports_soccer;
      case CourtType.baloncesto:  return Icons.sports_basketball;
      case CourtType.tenis:       return Icons.sports_tennis;
      case CourtType.voley:       return Icons.sports_volleyball;
      case CourtType.otro:        return Icons.stadium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gestión de Pistas',
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CourtFormScreen()),
        ),
      ),
      body: StreamBuilder<List<CourtModel>>(
        stream: CourtService().getCourts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final courts = snap.data ?? [];
          if (courts.isEmpty) {
            return const Center(
              child: Text('No hay pistas creadas',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final court = courts[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: court.activa
                        ? Colors.transparent
                        : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor:
                    Colors.redAccent.withOpacity(0.2),
                    child: Icon(_courtIcon(court.tipo),
                        color: Colors.redAccent),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(court.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (!court.activa) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('INACTIVA',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(court.tipo.label,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${court.precioPorHora.toStringAsFixed(2)} €/h',
                          style: const TextStyle(
                              color: Colors.greenAccent, fontSize: 12)),
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
                                  CourtFormScreen(court: court)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.redAccent),
                        onPressed: () => _delete(context, court),
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
}