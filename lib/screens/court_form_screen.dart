import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gesport/models/court.dart';
import 'package:gesport/services/court_service.dart';

class CourtFormScreen extends StatefulWidget {
  final CourtModel? court;
  const CourtFormScreen({super.key, this.court});

  @override
  State<CourtFormScreen> createState() => _CourtFormScreenState();
}

class _CourtFormScreenState extends State<CourtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _service = CourtService();

  CourtType _tipo = CourtType.padel;
  bool _activa = true;
  bool _isLoading = false;

  bool get isEditing => widget.court != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameCtrl.text = widget.court!.nombre;
      _descCtrl.text = widget.court!.descripcion;
      _precioCtrl.text = widget.court!.precioPorHora.toStringAsFixed(2);
      _tipo = widget.court!.tipo;
      _activa = widget.court!.activa;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final court = CourtModel(
      id: isEditing ? widget.court!.id : '',
      nombre: _nameCtrl.text.trim(),
      tipo: _tipo,
      descripcion: _descCtrl.text.trim(),
      activa: _activa,
      precioPorHora:
      double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0.0,
    );

    try {
      if (isEditing) {
        await _service.updateCourt(court);
      } else {
        await _service.createCourt(court);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
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
        title: Text(isEditing ? 'Editar Pista' : 'Nueva Pista',
            style: const TextStyle(color: Colors.white)),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Nombre de la pista',
                    icon: Icons.stadium,
                  ),
                  const SizedBox(height: 20),

                  // Tipo de pista
                  _sectionLabel('Tipo de pista'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CourtType>(
                        value: _tipo,
                        dropdownColor: const Color(0xFF0A1A2F),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: CourtType.values
                            .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _tipo = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildField(
                    controller: _descCtrl,
                    label: 'Descripción (opcional)',
                    icon: Icons.notes,
                    required: false,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  _buildField(
                    controller: _precioCtrl,
                    label: 'Precio por hora (€)',
                    icon: Icons.euro,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'))
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return null;
                      if (double.tryParse(val.replaceAll(',', '.')) == null) {
                        return 'Introduce un precio válido';
                      }
                      return null;
                    },
                    required: false,
                  ),
                  const SizedBox(height: 20),

                  // Estado activa/inactiva
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pista activa',
                          style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        _activa
                            ? 'Disponible para reservas'
                            : 'No disponible para reservas',
                        style: TextStyle(
                            color: _activa
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12),
                      ),
                      value: _activa,
                      activeColor: Colors.greenAccent,
                      onChanged: (val) => setState(() => _activa = val),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Pista',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
              (val) => required && (val == null || val.isEmpty)
              ? 'Campo obligatorio'
              : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }
}