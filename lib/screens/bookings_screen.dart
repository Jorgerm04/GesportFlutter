import 'package:flutter/material.dart';
import 'package:gesport/models/booking.dart';
import 'package:gesport/services/booking_service.dart';
import 'package:gesport/screens/booking_form_screen.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  Future<void> _toggleCancelada(
      BuildContext context, BookingModel booking) async {
    final action = booking.cancelada ? 'reactivar' : 'cancelar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1A2F),
        title: Text(
          booking.cancelada ? 'Reactivar reserva' : 'Cancelar reserva',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Seguro que quieres $action la reserva de '
              '${booking.usuarioNombre} en ${booking.pistaNombre}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                booking.cancelada ? 'Reactivar' : 'Cancelar',
                style: TextStyle(
                    color: booking.cancelada
                        ? Colors.greenAccent
                        : Colors.redAccent),
              )),
        ],
      ),
    );
    if (confirm == true) {
      await BookingService().setCancelada(booking.id, !booking.cancelada);
    }
  }

  Future<void> _delete(BuildContext context, BookingModel booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1A2F),
        title: const Text('Eliminar reserva',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Reserva de ${booking.usuarioNombre} en ${booking.pistaNombre}. '
              '¿Confirmar eliminación permanente?',
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
    if (confirm == true) await BookingService().deleteBooking(booking.id);
  }

  @override
  Widget build(BuildContext context) {
    final fmtFecha = DateFormat('dd/MM/yy');
    final fmtHora  = DateFormat('HH:mm');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Gestión de Reservas',
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
          MaterialPageRoute(builder: (_) => const BookingFormScreen()),
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
          child: StreamBuilder<List<BookingModel>>(
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
                  final color = b.cancelada
                      ? Colors.redAccent
                      : Colors.greenAccent;

                  return Opacity(
                    opacity: b.cancelada ? 0.55 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          left: BorderSide(color: color, width: 3),
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(
                            b.cancelada
                                ? Icons.event_busy
                                : Icons.event_available,
                            color: color,
                          ),
                        ),
                        title: Text(
                          b.pistaNombre,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: b.cancelada
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white54,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.usuarioNombre,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 3),
                            Text(
                              '${fmtFecha.format(b.fecha)}  ·  ${fmtHora.format(b.horaInicio)} – ${fmtHora.format(b.horaFin)}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                b.cancelada ? 'CANCELADA' : 'ACTIVA',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
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