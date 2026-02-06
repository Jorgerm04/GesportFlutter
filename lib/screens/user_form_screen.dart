import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserFormScreen extends StatefulWidget {
  final String? uid; // Ahora es opcional
  const UserFormScreen({super.key, this.uid});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedRole = 'jugador';
  bool _isLoading = false;

  bool get isEditing => widget.uid != null; // Detecta si estamos editando o creando

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['nombre'] ?? '';
      _emailController.text = data['email'] ?? '';
      setState(() {
        _selectedRole = data['rol'] ?? 'jugador';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final data = {
        'nombre': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'rol': _selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        if (isEditing) {
          // ACTUALIZAR
          await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).update(data);
        } else {
          // CREAR NUEVO
          await FirebaseFirestore.instance.collection('usuarios').add({
            ...data,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent)
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isEditing ? "Editar Usuario" : "Nuevo Usuario", style: const TextStyle(color: Colors.white)),
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
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, "Nombre completo", Icons.person),
                  const SizedBox(height: 20),
                  // El email solo es editable si estamos CREANDO
                  _buildTextField(_emailController, "Email", Icons.email, enabled: !isEditing),
                  const SizedBox(height: 20),
                  _buildRoleDropdown(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEditing ? "Guardar Cambios" : "Crear Usuario",
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool enabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      validator: (val) => val!.isEmpty ? "Campo obligatorio" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: enabled ? Colors.white70 : Colors.white30),
        prefixIcon: Icon(icon, color: enabled ? Colors.white70 : Colors.white30),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    final List<String> roles = ['admin', 'jugador', 'entrenador', 'arbitro'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Rol del usuario", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: roles.contains(_selectedRole) ? _selectedRole : 'jugador',
              dropdownColor: const Color(0xFF0A1A2F),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _selectedRole = val!),
            ),
          ),
        ),
      ],
    );
  }
}