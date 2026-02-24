import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/models/team.dart';
import 'package:gesport/screens/team_form_screen.dart';

class UserFormScreen extends StatefulWidget {
  final String? uid;
  const UserFormScreen({super.key, this.uid});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  UserRole _selectedRole = UserRole.jugador;
  bool _isLoading = false;

  // Equipo asociado (solo en modo edición)
  Map<String, dynamic>? _equipoAsociado;
  bool _loadingEquipo = false;

  bool get isEditing => widget.uid != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['nombre'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _ageController.text =
      data['age'] != null ? data['age'].toString() : '';
      final role = UserRoleExtension.fromString(data['rol']);
      setState(() {
        _selectedRole = role;
        _isLoading = false;
      });
      if (role == UserRole.jugador || role == UserRole.entrenador) {
        _loadEquipo(role);
      }
    }
  }

  Future<void> _loadEquipo(UserRole role) async {
    setState(() {
      _loadingEquipo = true;
      _equipoAsociado = null;
    });

    QuerySnapshot snap;

    if (role == UserRole.jugador) {
      snap = await FirebaseFirestore.instance
          .collection('equipos')
          .where('jugadoresIds', arrayContains: widget.uid)
          .limit(1)
          .get();
    } else {
      snap = await FirebaseFirestore.instance
          .collection('equipos')
          .where('entrenadorId', isEqualTo: widget.uid)
          .limit(1)
          .get();
    }

    if (mounted) {
      setState(() {
        _equipoAsociado = snap.docs.isNotEmpty
            ? {
          'id': snap.docs.first.id,
          ...snap.docs.first.data() as Map<String, dynamic>
        }
            : null;
        _loadingEquipo = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'nombre': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'age': _ageController.text.isNotEmpty
          ? int.tryParse(_ageController.text.trim())
          : null,
      'rol': _selectedRole.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (isEditing) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.uid)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('usuarios').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isEditing ? "Editar Usuario" : "Nuevo Usuario",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
          ),
        ),
        child: SafeArea(
          child: _isLoading && isEditing
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: "Nombre completo",
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: "Email",
                    icon: Icons.email,
                    enabled: !isEditing,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    label: "Teléfono",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    required: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s\-]'))
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _ageController,
                    label: "Edad",
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                    required: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return null;
                      final age = int.tryParse(val);
                      if (age == null || age < 1 || age > 120) {
                        return 'Introduce una edad válida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildRoleDropdown(),

                  // ── Equipo asociado ──────────────────────
                  if (isEditing &&
                      (_selectedRole == UserRole.jugador ||
                          _selectedRole == UserRole.entrenador)) ...[
                    const SizedBox(height: 28),
                    _buildEquipoSection(),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : Text(
                        isEditing
                            ? "Guardar Cambios"
                            : "Crear Usuario",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sección equipo ───────────────────────────────────────────────────────

  Widget _buildEquipoSection() {
    final isEntrenador = _selectedRole == UserRole.entrenador;
    final label = isEntrenador ? 'Equipo que entrena' : 'Equipo';
    final color = isEntrenador ? Colors.blueAccent : Colors.greenAccent;
    final icon  = isEntrenador ? Icons.person_pin : Icons.sports_soccer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingEquipo)
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white38, strokeWidth: 2),
              ),
            ),
          )
        else if (_equipoAsociado == null)
          _buildNoTeamCard(isEntrenador)
        else
          _buildTeamCard(_equipoAsociado!, color, isEntrenador),
      ],
    );
  }

  Widget _buildNoTeamCard(bool isEntrenador) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withOpacity(0.07),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded,
              color: Colors.white24, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEntrenador
                  ? 'No entrena ningún equipo todavía'
                  : 'No pertenece a ningún equipo todavía',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(
      Map<String, dynamic> equipo, Color color, bool isEntrenador) {
    final nombre      = equipo['nombre'] as String? ?? 'Equipo';
    final descripcion = equipo['descripcion'] as String? ?? '';
    final jugadores   = (equipo['jugadoresIds'] as List?)?.length ?? 0;
    final team        = TeamModel.fromMap(equipo['id'] as String, equipo);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeamFormScreen(team: team)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.groups_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          descripcion,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.sports_soccer,
                              size: 12, color: color.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            '$jugadores jugador${jugadores == 1 ? '' : 'es'}',
                            style: TextStyle(
                                color: color.withOpacity(0.8), fontSize: 11),
                          ),
                          if (isEntrenador) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.person_pin,
                                size: 12, color: color.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Tú eres el entrenador',
                              style: TextStyle(
                                  color: color.withOpacity(0.8), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets base ─────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
              (val) {
            if (required && (val == null || val.isEmpty)) {
              return 'Campo obligatorio';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: enabled ? Colors.white70 : Colors.white30),
        prefixIcon:
        Icon(icon, color: enabled ? Colors.white70 : Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Rol del usuario",
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserRole>(
              value: _selectedRole,
              dropdownColor: const Color(0xFF0A1A2F),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: UserRole.values
                  .map((role) => DropdownMenuItem(
                value: role,
                child: Text(role.label.toUpperCase()),
              ))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedRole = val;
                  _equipoAsociado = null;
                });
                if (isEditing &&
                    (val == UserRole.jugador ||
                        val == UserRole.entrenador)) {
                  _loadEquipo(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}