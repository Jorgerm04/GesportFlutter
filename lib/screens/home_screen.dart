import 'package:flutter/material.dart';
import 'package:gesport/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("GESPORT",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async => await AuthService().signOut(),
          )
        ],
      ),
      // Fondo con el gradiente oficial
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Mensaje de Bienvenida
                const SizedBox(height: 20),
                const Text("¡Hola de nuevo!",
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const Text("Tu actividad de hoy",
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),

                const SizedBox(height: 30),

                // 2. Card de Próxima Reserva
                _buildSectionTitle("Próxima Reserva"),
                const SizedBox(height: 12),
                _buildReservationCard(),

                const SizedBox(height: 30),

                // 3. Grid de Información General
                _buildSectionTitle("Gestión del Centro"),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _buildInfoCard("Mis Clases", Icons.fitness_center, Colors.blueAccent),
                    _buildInfoCard("Horarios", Icons.schedule, Colors.orangeAccent),
                    _buildInfoCard("Mi Plan", Icons.assignment, Colors.greenAccent),
                    _buildInfoCard("Pagos", Icons.credit_card, Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),

      // 4. Bottom Navigation Bar Deportiva
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF050B14),
        selectedItemColor: const Color(0xFF0E5CAD),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.event_available), label: "Reservas"),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: "Logros"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Perfil"),
        ],
      ),
    );
  }

  // Widget para títulos de sección
  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600));
  }

  // Tarjeta de Reserva Destacada
  Widget _buildReservationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E5CAD).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0E5CAD).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E5CAD),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.sports_tennis, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pista de Pádel - Central",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Hoy, 18:30 - 20:00",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  // Tarjetas de Información/Grid
  Widget _buildInfoCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}