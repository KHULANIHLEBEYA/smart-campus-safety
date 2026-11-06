import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  int _currentStep = 0;
  String? _errorMessage;

  String _selectedFaculty = 'Natural & Applied Sciences';

  final List<String> _faculties = [
    'Natural & Applied Sciences',
    'Economic & Management Sciences',
    'Education',
    'Humanities',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    // Basic per-step validation before moving forward
    if (_currentStep == 0) {
      if (_fullNameController.text.trim().isEmpty ||
          _studentIdController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please fill in your name and ID.');
        return;
      }
    }

    if (_currentStep == 1) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();

      if (email.isEmpty || !email.contains('@')) {
        setState(() => _errorMessage = 'Please enter a valid email.');
        return;
      }
      if (password.length < 8) {
        setState(() => _errorMessage = 'Password must be at least 8 characters.');
        return;
      }
      if (password != confirm) {
        setState(() => _errorMessage = 'Passwords do not match.');
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _handleRegister();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _handleRegister() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD85A30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Please agree to the terms to continue.',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Create the Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      // 2. Create the matching Firestore user profile
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': _fullNameController.text.trim(),
        'studentOrStaffId': _studentIdController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        // Public registration must never grant a privileged role.
        'role': 'student',
        'faculty': _selectedFaculty,
        'emergencyContact': _emergencyContactController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'An account with that email already exists.';
            break;
          case 'invalid-email':
            _errorMessage = 'Please enter a valid email address.';
            break;
          case 'weak-password':
            _errorMessage = 'Password is too weak. Try a stronger one.';
            break;
          default:
            _errorMessage = 'Registration failed. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFE1F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF0F6E56), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Account Created!',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Welcome to Smart Campus Safety. Your account is ready to use.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HomeScreen()),
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F6E56),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: Column(
        children: [
          _buildTopBar(),
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepContent(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD85A30).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFD85A30).withOpacity(0.4)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Color(0xFFD85A30), fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _buildNavigationButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF0F6E56),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 8,
        right: 20,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            'Create Account',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Personal Info', 'Account Setup', 'Security'];
    return Container(
      color: const Color(0xFF0F6E56),
      padding: const EdgeInsets.only(
          left: 20, right: 20, bottom: 20),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final index = e.key;
          final label = e.value;
          final isActive = _currentStep == index;
          final isDone = _currentStep > index;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.white
                                  : isActive
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check_rounded,
                                      size: 15,
                                      color: Color(0xFF0F6E56))
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? const Color(0xFF0F6E56)
                                            : Colors.white54,
                                      ),
                                    ),
                            ),
                          ),
                          if (index < steps.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: isDone
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.white.withOpacity(0.2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive || isDone
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  // Step 1 — Personal Info
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle('Personal Information',
            'Tell us a bit about yourself'),
        const SizedBox(height: 20),
        _buildLabel('Full Name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _fullNameController,
          hint: 'Khulani Hlebeya',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildLabel('Student ID'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _studentIdController,
          hint: '202302091',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildLabel('Phone Number'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _phoneController,
          hint: '+27 71 234 5678',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildLabel('Account Type'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.school_outlined,
                  color: Color(0xFF0F6E56), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Staff and security access must be assigned by an administrator.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.lock_outline,
                  color: Colors.grey, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Faculty'),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _selectedFaculty,
          items: _faculties,
          icon: Icons.account_balance_outlined,
          onChanged: (v) =>
              setState(() => _selectedFaculty = v!),
        ),
      ],
    );
  }

  // Step 2 — Account Setup
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
            'Account Setup', 'Set up your login credentials'),
        const SizedBox(height: 20),
        _buildLabel('Email Address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _emailController,
          hint: 'khulani@spu.ac.za',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildLabel('Password'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _passwordController,
          hint: 'Min. 8 characters',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Confirm Password'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _confirmPasswordController,
          hint: 'Re-enter password',
          icon: Icons.lock_outline,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () => setState(
                () => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 16),
        // Password strength indicator
        _buildPasswordStrength(),
      ],
    );
  }

  // Step 3 — Security & Terms
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(
            'Almost done!', 'Review and confirm your account'),
        const SizedBox(height: 20),

        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              _buildSummaryRow(Icons.person_outline,
                  'Name', _fullNameController.text.isEmpty
                      ? 'Not set' : _fullNameController.text),
              _buildSummaryRow(Icons.badge_outlined,
                  'Student ID', _studentIdController.text.isEmpty
                      ? 'Not set' : _studentIdController.text),
              _buildSummaryRow(Icons.email_outlined,
                  'Email', _emailController.text.isEmpty
                      ? 'Not set' : _emailController.text),
              _buildSummaryRow(Icons.school_outlined,
                  'Role', 'Student'),
              _buildSummaryRow(
                  Icons.account_balance_outlined,
                  'Faculty',
                  _selectedFaculty,
                  isLast: true),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Emergency contact
        _buildLabel('Emergency Contact (optional)'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _emergencyContactController,
          hint: 'Parent / Guardian phone number',
          icon: Icons.contact_phone_outlined,
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 20),

        // Terms
        GestureDetector(
          onTap: () =>
              setState(() => _agreedToTerms = !_agreedToTerms),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _agreedToTerms
                  ? const Color(0xFFE1F5EE)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _agreedToTerms
                    ? const Color(0xFF1D9E75)
                    : Colors.black.withOpacity(0.08),
                width: _agreedToTerms ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _agreedToTerms
                        ? const Color(0xFF1D9E75)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _agreedToTerms
                          ? const Color(0xFF1D9E75)
                          : Colors.grey,
                      width: 1.5,
                    ),
                  ),
                  child: _agreedToTerms
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I agree to the Terms of Service and Privacy Policy. I understand my data will be used to improve campus safety.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) strength++;

    final labels = ['Too short', 'Weak', 'Fair', 'Strong', 'Very strong'];
    final colors = [
      Colors.grey,
      const Color(0xFFD85A30),
      const Color(0xFFBA7517),
      const Color(0xFF1D9E75),
      const Color(0xFF0F6E56),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength
                      ? colors[strength]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          password.isEmpty ? '' : labels[strength],
          style: TextStyle(
            fontSize: 11,
            color: password.isEmpty ? Colors.transparent : colors[strength],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label,
      String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.black.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back',
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F6E56),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep < 2
                              ? 'Continue'
                              : 'Create Account',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _currentStep < 2
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded,
                          size: 18,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF1D9E75), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87),
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}