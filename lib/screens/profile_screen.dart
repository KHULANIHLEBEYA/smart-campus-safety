import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';
import 'settings_screen.dart';

const Color _profilePaper = Color(0xFFF7F6F0);
const Color _profileGreen = Color(0xFF0F6E56);
const Color _profileInk = Color(0xFF182522);
const Color _profileMuted = Color(0xFF727B77);
const Color _profileRule = Color(0xFFDFE4DE);
const Color _profileAlert = Color(0xFFD85A30);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final User? _user;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _profileStream = _user == null
        ? null
        : FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .snapshots();
  }

  String _value(Map<String, dynamic> data, String key,
      {String fallback = 'Not provided'}) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty
        ? value.trim()
        : fallback;
  }

  String _displayRole(Map<String, dynamic> data) {
    final role = _value(data, 'role', fallback: 'student');
    return role
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final names = parts.toList();
    if (names.isEmpty) return '?';
    if (names.length == 1) return names.first[0].toUpperCase();
    return '${names.first[0]}${names.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _profilePaper,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildProfileBody()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      color: _profileGreen,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 13,
        14,
        15,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.65)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.explore_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Text(
            'SMARTSAFE',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'App settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _buildProfileBody() {
    if (_user == null || _profileStream == null) {
      return _buildMessage(
        icon: Icons.lock_outline,
        title: 'Sign in to view your profile',
        message: 'Your profile is linked to your authenticated account.',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your profile',
            message: 'Check your connection and Firestore user-profile rules.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _profileGreen),
          );
        }

        if (snapshot.data == null || !snapshot.data!.exists) {
          return _buildMessage(
            icon: Icons.person_off_outlined,
            title: 'Profile not found',
            message:
                'Your sign-in exists, but the users/${_user.uid} Firestore document is missing. Ask an administrator to check your account setup.',
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileMasthead(data),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeading(
                      index: '01',
                      title: 'Account details',
                      action: TextButton.icon(
                        onPressed: () => _showEditProfile(data),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit profile'),
                        style: TextButton.styleFrom(
                          foregroundColor: _profileGreen,
                          textStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProfileDetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _value(
                        data,
                        'email',
                        fallback: _user.email ?? 'Not available',
                      ),
                    ),
                    _ProfileDetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: _value(data, 'phone'),
                    ),
                    _ProfileDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Student / staff ID',
                      value: _value(data, 'studentOrStaffId'),
                    ),
                    _ProfileDetailRow(
                      icon: Icons.school_outlined,
                      label: 'Faculty',
                      value: _value(data, 'faculty'),
                    ),
                    _ProfileDetailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Role',
                      value: _displayRole(data),
                      isLast: true,
                    ),
                    const SizedBox(height: 31),
                    _buildSectionHeading(
                      index: '02',
                      title: 'Account & preferences',
                      trailing: 'MANAGE ACCESS',
                    ),
                    const SizedBox(height: 8),
                    const _ProfileActionRow(
                      icon: Icons.lock_outline,
                      title: 'Role and access',
                      subtitle:
                          'Your role is managed by campus staff and cannot be changed here.',
                    ),
                    _ProfileActionRow(
                      icon: Icons.settings_outlined,
                      title: 'App settings',
                      subtitle: 'Open notification and app preferences',
                      onTap: _openSettings,
                      isLast: true,
                    ),
                    const SizedBox(height: 31),
                    _buildSectionHeading(
                      index: '03',
                      title: 'Session',
                      trailing: 'DEVICE ACCESS',
                    ),
                    const SizedBox(height: 7),
                    Semantics(
                      button: true,
                      label: 'Sign out of your account',
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sign out'),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          alignment: Alignment.centerLeft,
                          foregroundColor: _profileInk,
                          side: const BorderSide(color: _profileRule),
                          shape: const RoundedRectangleBorder(),
                          textStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'You will be returned to the login screen.',
                      style: TextStyle(
                        color: _profileMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileMasthead(Map<String, dynamic> data) {
    final name = _value(data, 'fullName', fallback: 'Campus user');
    final email = _value(
      data,
      'email',
      fallback: _user?.email ?? 'Email not available',
    );

    return Container(
      width: double.infinity,
      color: _profileGreen,
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFILE  /  05',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your account.',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.52)),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(width: 29, height: 1, color: const Color(0xFFA9D6C8)),
          const SizedBox(height: 8),
          Text(
            'SOL PLAATJE UNIVERSITY  ·  ${_displayRole(data).toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.82),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading({
    required String index,
    required String title,
    String? trailing,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          index,
          style: GoogleFonts.spaceGrotesk(
            color: _profileGreen,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: _profileInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null)
          action
        else if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.spaceGrotesk(
              color: _profileMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );
  }

  Future<void> _showEditProfile(Map<String, dynamic> data) async {
    final nameController = TextEditingController(
      text: _value(data, 'fullName', fallback: ''),
    );
    final phoneController = TextEditingController(
      text: _value(data, 'phone', fallback: ''),
    );
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? saveError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _profilePaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 35,
                    height: 3,
                    color: _profileRule,
                  ),
                ),
                const SizedBox(height: 21),
                Text(
                  'EDIT PROFILE',
                  style: GoogleFonts.spaceGrotesk(
                    color: _profileGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Keep your contact details current.',
                  style: GoogleFonts.spaceGrotesk(
                    color: _profileInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _SheetField(
                  controller: nameController,
                  label: 'Full name',
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 15),
                _SheetField(
                  controller: phoneController,
                  label: 'Phone number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Enter your phone number';
                    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 7) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                if (saveError != null) ...[
                  const SizedBox(height: 13),
                  Text(
                    saveError!,
                    style: const TextStyle(
                      color: _profileAlert,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 23),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            final currentUser = FirebaseAuth.instance.currentUser;
                            if (currentUser == null) {
                              setSheetState(() => saveError =
                                  'Your session has expired. Sign in again.');
                              return;
                            }

                            setSheetState(() {
                              isSaving = true;
                              saveError = null;
                            });
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .update({
                                'fullName': nameController.text.trim(),
                                'phone': phoneController.text.trim(),
                              });
                              if (!mounted) return;
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated.'),
                                  backgroundColor: _profileGreen,
                                ),
                              );
                            } catch (_) {
                              setSheetState(() {
                                isSaving = false;
                                saveError =
                                    'Could not save changes. Check your connection and Firestore rules.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _profileGreen,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                      textStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _profilePaper,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: _profileRule),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.spaceGrotesk(
            color: _profileInk,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: _profileMuted, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: _profileMuted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _profileGreen,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 31, height: 1, color: _profileGreen),
            const SizedBox(height: 18),
            Icon(icon, size: 42, color: _profileMuted),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _profileInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _profileMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _profileRule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: _profileGreen, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: _profileMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _profileInk,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  const _ProfileActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: _profileRule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: _profileGreen, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        color: _profileInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _profileMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(top: 5, left: 12),
                  child: Icon(
                    Icons.arrow_outward,
                    color: _profileMuted,
                    size: 17,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _profileInk, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _profileMuted, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _profileRule),
          borderRadius: BorderRadius.zero,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: _profileRule),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _profileGreen, width: 1.5),
          borderRadius: BorderRadius.zero,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }
}
