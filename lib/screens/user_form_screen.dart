import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gesport/models/user.dart';
import 'package:gesport/models/team.dart';
import 'package:gesport/screens/team_form_screen.dart';
import 'package:gesport/services/user_service.dart';
import 'package:gesport/utils/app_theme.dart';
import 'package:gesport/widgets/widgets.dart';

class UserFormScreen extends StatefulWidget {
  final String? uid;
  const UserFormScreen({super.key, this.uid});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _service    = UserService();
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _ageCtrl    = TextEditingController();

  UserRole _selectedRole = UserRole.jugador;
  bool     _isLoading    = false;

  Map<String, dynamic>? _equipoAsociado;
  bool                  _loadingEquipo = false;

  bool get isEditing => widget.uid != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = await _service.getUserById(widget.uid!);
    if (user == null) return;

    _nameCtrl.text  = user.nombre;
    _emailCtrl.text = user.email;
    _phoneCtrl.text = user.phone;
    _ageCtrl.text   = user.age?.toString() ?? '';

    setState(() {
      _selectedRole = user.rol;
      _isLoading    = false;
    });

    if (user.rol == UserRole.jugador || user.rol == UserRole.entrenador) {
      _loadEquipo(user.rol);
    }
  }

  Future<void> _loadEquipo(UserRole role) async {
    setState(() {
      _loadingEquipo  = true;
      _equipoAsociado = null;
    });

    final equipo = await _service.getEquipoDelUsuario(widget.uid!, role);

    if (mounted) {
      setState(() {
        _equipoAsociado = equipo;
        _loadingEquipo  = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'nombre': _nameCtrl.text.trim(),
      'email':  _emailCtrl.text.trim(),
      'phone':  _phoneCtrl.text.trim(),
      'age':    _ageCtrl.text.isNotEmpty
          ? int.tryParse(_ageCtrl.text.trim())
          : null,
      'rol':    _selectedRole.name,
    };

    try {
      if (isEditing) {
        await _service.updateUser(widget.uid!, data);
      } else {
        await _service.createUser(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
      body: (_isLoading && isEditing)
          ? const Center(
          child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                  controller: _nameCtrl,
                  label: 'Nombre completo',
                  icon:  Icons.person),
              const SizedBox(height: 20),
              _buildTextField(
                  controller:   _emailCtrl,
                  label:        'Email',
                  icon:         Icons.email,
                  enabled:      !isEditing,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),
              _buildTextField(
                  controller:   _phoneCtrl,
                  label:        'Teléfono',
                  icon:         Icons.phone,
                  keyboardType: TextInputType.phone,
                  required:     false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9+\s\-]'))
                  ]),
              const SizedBox(height: 20),
              _buildTextField(
                  controller:   _ageCtrl,
                  label:        'Edad',
                  icon:         Icons.cake,
                  keyboardType: TextInputType.number,
                  required:     false,
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
                  }),
              const SizedBox(height: 20),
              _buildRoleDropdown(),

              // Equipo asociado (solo edición)
              if (isEditing &&
                  (_selectedRole == UserRole.jugador ||
                      _selectedRole == UserRole.entrenador)) ...[
                const SizedBox(height: 28),
                _buildEquipoSection(),
              ],

              const SizedBox(height: 40),
              SaveButton(
                label: isEditing ? 'Guardar Cambios' : 'Crear',
                isLoading: _isLoading,
                onPressed: _saveUser,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sección equipo ────────────────────────────────────────────────────────

  Widget _buildEquipoSection() {
    final isEntrenador = _selectedRole == UserRole.entrenador;
    final label = isEntrenador ? 'Equipo que entrena' : 'Equipo';
    final color = isEntrenador ? Colors.blueAccent : Colors.greenAccent;
    final icon  = isEntrenador ? Icons.person_pin  : Icons.sports_soccer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color:      color,
                  fontSize:   13,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (_loadingEquipo)
          Container(
            height:     64,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20, height: 20,
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
      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        const Icon(Icons.groups_rounded, color: Colors.white24, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isEntrenador
                ? 'No entrena ningún equipo todavía'
                : 'No pertenece a ningún equipo todavía',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _buildTeamCard(
      Map<String, dynamic> equipo, Color color, bool isEntrenador) {
    final nombre      = equipo['nombre']      as String? ?? 'Equipo';
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
                color:        color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: color.withOpacity(0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color:        color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.groups_rounded, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:   14)),
                        if (descripcion.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(descripcion,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
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
                            Text('Tú eres el entrenador',
                                style: TextStyle(
                                    color: color.withOpacity(0.8), fontSize: 11)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: color.withOpacity(0.5), size: 20),
                ]),
              ),
            )
        )
    );
        }

  // ── Widgets base ──────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String                label,
    required IconData              icon,
    bool                           enabled          = true,
    bool                           required         = true,
    TextInputType                  keyboardType     = TextInputType.text,
    List<TextInputFormatter>?      inputFormatters,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller:      controller,
      enabled:         enabled,
      style:           const TextStyle(color: Colors.white),
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
              (val) {
            if (required && (val == null || val.isEmpty)) {
              return 'Campo obligatorio';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText:   label,
        labelStyle:  TextStyle(
            color: enabled ? Colors.white70 : Colors.white30),
        prefixIcon:  Icon(icon,
            color: enabled ? Colors.white70 : Colors.white30),
        filled:      true,
        fillColor:   Colors.white.withOpacity(0.05),
        border:      OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rol del usuario',
            style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding:    const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserRole>(
              value:         _selectedRole,
              dropdownColor: AppTheme.bg1,
              isExpanded:    true,
              style:         const TextStyle(color: Colors.white),
              items: UserRole.values.map((role) => DropdownMenuItem(
                value: role,
                child: Text(role.label.toUpperCase()),
              )).toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _selectedRole   = val;
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