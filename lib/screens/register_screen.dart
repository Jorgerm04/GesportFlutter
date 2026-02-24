import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gesport/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> _handleRegister() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();
    final ageText = ageController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, rellena todos los campos obligatorios');
      return;
    }

    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (ageText.isNotEmpty) {
      final age = int.tryParse(ageText);
      if (age == null || age < 1 || age > 120) {
        _showSnackBar('Introduce una edad válida');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      UserCredential? credential =
      await _authService.signUp(email, password, username);

      if (credential != null && credential.user != null) {
        final String uid = credential.user!.uid;
        final int? age = ageText.isNotEmpty ? int.tryParse(ageText) : null;

        final querySnapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: email)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // CASO A: El Admin ya creó el perfil
          String oldDocId = querySnapshot.docs.first.id;
          Map<String, dynamic> existingData =
          querySnapshot.docs.first.data();

          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .set({
            'nombre': username,
            'email': email,
            'phone': phone,
            'age': age,
            'rol': existingData['rol'] ?? 'jugador',
            'createdAt':
            existingData['createdAt'] ?? FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });

          if (oldDocId != uid) {
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(oldDocId)
                .delete();
          }
        } else {
          // CASO B: Registro totalmente nuevo
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .set({
            'nombre': username,
            'email': email,
            'phone': phone,
            'age': age,
            'rol': 'jugador',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          _showSnackBar('Cuenta creada con éxito', isError: false);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A1A2F), Color(0xFF050B14)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Gesport',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrena. Gestiona. Mejora.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  _buildInput(
                    controller: usernameController,
                    hint: 'Nombre de usuario *',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    controller: emailController,
                    hint: 'Email *',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    controller: passwordController,
                    hint: 'Contraseña *',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    controller: phoneController,
                    hint: 'Teléfono (opcional)',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s\-]'))
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInput(
                    controller: ageController,
                    hint: 'Edad (opcional)',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5CAD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : const Text(
                        'Registrarse',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('¿Ya tienes cuenta?',
                          style: TextStyle(color: Colors.white54)),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Inicia sesión',
                            style:
                            TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Text('© 2025 Gesport',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscurePassword : false,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white54),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(
                    () => obscurePassword = !obscurePassword),
          )
              : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}