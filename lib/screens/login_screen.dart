import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'register_screen.dart';

const Color _paper = Color(0xFFF7F6F0);
const Color _green = Color(0xFF0F6E56);
const Color _deepGreen = Color(0xFF0A4C3D);
const Color _ink = Color(0xFF182522);
const Color _muted = Color(0xFF727B77);
const Color _rule = Color(0xFFDFE4DE);
const Color _errorRed = Color(0xFFA63B32);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isSigningIn = false;
  bool _isSendingReset = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _normalizeRole(Object? value) {
    if (value is! String) return null;

    final role = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    switch (role) {
      case 'student':
      case 'learner':
        return 'student';
      case 'admin':
      case 'administrator':
      case 'staff':
        return 'admin';
      case 'security':
      case 'security officer':
      case 'officer':
        return 'security';
      default:
        return null;
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address and password.');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'invalid-user',
          message: 'Firebase did not return a signed-in user.',
        );
      }

      DocumentSnapshot<Map<String, dynamic>> userDocument;
      try {
        userDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      } on FirebaseException {
        await FirebaseAuth.instance.signOut();
        rethrow;
      }

      final profile = userDocument.data();
      if (!userDocument.exists || profile == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _errorMessage =
              'Your account profile could not be found. Please contact campus support.';
        });
        return;
      }

      final rawRole = profile['role'] ?? profile['userRole'] ?? profile['accountType'];
      final role = _normalizeRole(rawRole);
      if (role == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _isSigningIn = false;
          _errorMessage =
              'Your account role is missing or not recognized. Please contact an administrator.';
        });
        return;
      }

      if (!mounted) return;
      setState(() => _isSigningIn = false);
      Navigator.pushReplacementNamed(
        context,
        role == 'admin' || role == 'security' ? '/admin-home' : '/home',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _errorMessage = _authError(error.code);
      });
    } on FirebaseException catch (error) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _errorMessage = error.code == 'permission-denied'
            ? 'Your account profile could not be read. Check the Firestore user-profile rules.'
            : 'Could not load your account profile. Check your connection and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'Sign-in failed. Please try again.';
      });
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact campus support.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment, then try again.';
      case 'network-request-failed':
        return 'Could not connect. Check your internet and try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email first to reset your password.');
      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _isSendingReset = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      _showMessage('If this email is registered, a password-reset link is on its way.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      _showMessage(
        error.code == 'invalid-email'
            ? 'Enter a valid email address first.'
            : 'Could not send the reset email. Check your connection and try again.',
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      _showMessage('Could not send the reset email. Please try again.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _errorRed : _deepGreen,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _masthead(context),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(25, 33, 25, 27),
                          child: _loginForm(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _masthead(BuildContext context) {
    return Container(
      color: _green,
      padding: EdgeInsets.fromLTRB(
        25,
        MediaQuery.of(context).padding.top + 18,
        25,
        27,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.38)),
                      borderRadius: BorderRadius.circular(11),
                      color: Colors.white.withOpacity(0.10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'SMARTSAFE  /  SPU',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Text(
                'Your campus.\nSafer together.',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.06,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'SOL PLAATJE UNIVERSITY  /  CAMPUS SAFETY',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '01',
              style: GoogleFonts.spaceGrotesk(
                color: _green,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'SECURE ACCESS',
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Welcome back.',
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Sign in to access your campus safety tools.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: _rule),
        const SizedBox(height: 19),
        _fieldLabel('EMAIL ADDRESS'),
        const SizedBox(height: 7),
        _textField(
          controller: _emailController,
          focusNode: _emailFocus,
          hint: 'you@spu.ac.za',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: 18),
        _fieldLabel('PASSWORD'),
        const SizedBox(height: 7),
        _textField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isSigningIn ? null : _handleLogin(),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _muted,
              size: 19,
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 15),
          _errorNotice(_errorMessage!),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isSendingReset || _isSigningIn ? null : _sendPasswordReset,
            style: TextButton.styleFrom(
              foregroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isSendingReset
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _green,
                    ),
                  )
                : const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSigningIn ? null : _handleLogin,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _green.withOpacity(0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSigningIn
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign in',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 21),
        const Divider(height: 1, color: _rule),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(
              child: Text(
                'New to campus safety? ',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _isSigningIn
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              style: TextButton.styleFrom(
                foregroundColor: _green,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Create an account',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'CAMPUS SAFETY  ·  HERE WHEN YOU NEED IT',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: _muted.withOpacity(0.78),
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.75,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        color: _ink,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.75,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: _ink, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: _green, size: 19),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFCFBF7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _green, width: 1.4),
        ),
      ),
    );
  }

  Widget _errorNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.07),
        border: Border.all(color: _errorRed.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _errorRed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _errorRed, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
