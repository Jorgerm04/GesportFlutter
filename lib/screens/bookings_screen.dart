import 'package:flutter/material.dart';
import 'package:gesport/models/booking.dart';
import 'package:gesport/services/booking_service.dart';
import 'package:gesport/screens/booking_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  Future<void> _toggleCancelada(
      BuildContext context, BookingModel booking) async {
    final action = booking.cancelada ? 'reactivar' : 'cancelar';
    final confirm = await ConfirmDialog.show(
      context,
      title:        booking.cancelada ? 'Reactivar reserva' : 'Cancelar reserva',
      content:      '¿Seguro que quieres $action la reserva de ${booking.usuarioNombre} en ${booking.pistaNombre}?',
      confirmLabel: booking.cancelada ? 'Reactivar' : 'Cancelar',
      confirmColor: booking.cancelada ? Colors.greenAccent : Colors.redAccent,
    );
    if (confirm == true) {
      await BookingService().setCancelada(booking.id, !booking.cancelada);
    }
  }

  Future<void> _delete(BuildContext context, BookingModel booking) async {
    final confirm = await ConfirmDialog.show(
      context,
      title:        'Eliminar reserva',
      content:      'Reserva de ${booking.usuarioNombre} en ${booking.pistaNombre}. ¿Confirmar eliminación permanente?',
      confirmLabel: 'Eliminar',
    );
    if (confirm == true) await BookingService().deleteBooking(booking.id);
  }

  @override
  Widget build(BuildContext context) {
    final fmtFecha = DateFormat('dd/MM/yy');
    final fmtHora  = DateFormat('HH:mm');

    return AppScaffold(
      title: 'Gestión de Reservas',
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingFormScreen()),
        ),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: BookingService().getAllBookings(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final bookings = snap.data ?? [];
          if (bookings.isEmpty) {
            return const Center(
              child: Text('No hay reservas',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final b = bookings[i];
              final statusColor = b.cancelada
                  ? Colors.redAccent
                  : Colors.greenAccent;
              final tipoColor = b.esPartido  ? Colors.yellowAccent
                  : b.esDeEquipo ? Colors.cyanAccent
                  : statusColor;
              final borderColor = b.cancelada ? Colors.redAccent : tipoColor;
              final leadingIcon = b.esPartido  ? Icons.sports
                  : b.esDeEquipo ? Icons.groups
                  : b.cancelada  ? Icons.event_busy
                  : Icons.event_available;

              // Título: para partido mostramos local vs visitante
              final titulo = b.esPartido
                  ? '${b.equipoLocalNombre ?? ''} vs ${b.equipoVisitanteNombre ?? ''}'
                  : b.pistaNombre;
              // Subtítulo línea 1
              final subtitulo = b.esPartido
                  ? b.pistaNombre
                  : b.esDeEquipo
                  ? b.equipoNombre ?? b.usuarioNombre
                  : b.usuarioNombre;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: b.cancelada ? 0.55 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          left: BorderSide(color: borderColor, width: 3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.fromLTRB(16, 14, 8, 8),
                        leading: CircleAvatar(
                          backgroundColor: tipoColor.withOpacity(0.15),
                          child: Icon(leadingIcon, color: tipoColor),
                        ),
                        title: Text(
                          titulo,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: b.cancelada
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white54,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subtitulo,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            if (b.esPartido && b.arbitroNombre != null)
                              Row(children: [
                                const Icon(Icons.sports_handball,
                                    color: Colors.white38, size: 11),
                                const SizedBox(width: 3),
                                Text(b.arbitroNombre!,
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11)),
                              ]),
                            const SizedBox(height: 3),
                            Text(
                              '${fmtFecha.format(b.fecha)}  ·  '
                                  '${fmtHora.format(b.horaInicio)} – '
                                  '${fmtHora.format(b.horaFin)}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              // Badge estado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  b.cancelada ? 'CANCELADA' : 'ACTIVA',
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              // Resultado si hay
                              if (b.esPartido && b.resultado != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.yellowAccent
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: Colors.yellowAccent
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    b.resultado!,
                                    style: const TextStyle(
                                        color: Colors.yellowAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ]),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: b.cancelada
                                  ? 'Reactivar reserva'
                                  : 'Cancelar reserva',
                              icon: Icon(
                                b.cancelada
                                    ? Icons.undo_rounded
                                    : Icons.cancel_outlined,
                                color: b.cancelada
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                              ),
                              onPressed: () =>
                                  _toggleCancelada(context, b),
                            ),
                            if (!b.cancelada)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.white70),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          BookingFormScreen(booking: b)),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _delete(context, b),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Badge pill tipo ─────────────────────────────────
                  if (b.esPartido || b.esDeEquipo)
                    Positioned(
                      top:   -1,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tipoColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: tipoColor.withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                b.esPartido ? Icons.sports : Icons.groups,
                                color: tipoColor, size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                b.esPartido ? 'PARTIDO' : 'EQUIPO',
                                style: TextStyle(
                                    color:       tipoColor,
                                    fontSize:    10,
                                    fontWeight:  FontWeight.w700,
                                    letterSpacing: 0.4),
                              ),
                            ]),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}