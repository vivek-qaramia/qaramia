import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../theme/brand.dart';
import '../../widgets/logo_mark.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  String? _ageRange;
  static const _ageRanges = ['18-24', '25-34', '35-44', '45+'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      if (_isLogin) {
        await auth.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await auth.signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim().toLowerCase(),
          displayName: _displayNameCtrl.text.trim(),
          ageRange: _ageRange,
          country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [QBrand.bg, QBrand.cardAlt],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo — mark above italic wordmark
                  const LogoMark(size: 80, glow: true),
                  const SizedBox(height: 12),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => QBrand.wordmarkGradient.createShader(rect),
                    child: Text(
                      'qara-mia!',
                      style: QBrand.wordmark(fontSize: 48),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'MY BELOVED',
                    style: TextStyle(color: QBrand.fgMute, fontSize: 12, letterSpacing: 4),
                  ),
                  const SizedBox(height: 48),

                  // Form
                  if (!_isLogin) ...[
                    _field(_displayNameCtrl, 'Display Name', Icons.person),
                    const SizedBox(height: 16),
                    _field(_usernameCtrl, 'Username', Icons.alternate_email),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _ageRange,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Age range (optional)',
                              prefixIcon: const Icon(Icons.cake_outlined, color: QBrand.fgMute),
                              labelStyle: const TextStyle(color: QBrand.fgMute),
                              filled: true,
                              fillColor: QBrand.cardAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFF7043)),
                              ),
                            ),
                            dropdownColor: QBrand.card,
                            style: const TextStyle(color: QBrand.fg),
                            items: [
                              for (final r in _ageRanges)
                                DropdownMenuItem(value: r, child: Text(r)),
                            ],
                            onChanged: (v) => setState(() => _ageRange = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_countryCtrl, 'Country', Icons.public, capitalize: TextCapitalization.words),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  _field(_emailCtrl, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _field(_passwordCtrl, 'Password', Icons.lock, obscure: true),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Google
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _googleSignIn,
                      icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: QBrand.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already have an account? Sign in',
                      style: const TextStyle(color: QBrand.deep, fontWeight: FontWeight.w600),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    TextCapitalization capitalize = TextCapitalization.none,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: capitalize,
      style: const TextStyle(color: QBrand.fg),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: QBrand.fgMute),
        labelStyle: const TextStyle(color: QBrand.fgMute),
        filled: true,
        fillColor: QBrand.cardAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF7043)),
        ),
      ),
    );
  }
}
