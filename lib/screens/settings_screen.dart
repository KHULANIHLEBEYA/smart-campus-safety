import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _settingsPaper = Color(0xFFF7F6F0);
const Color _settingsGreen = Color(0xFF0F6E56);
const Color _settingsInk = Color(0xFF182522);
const Color _settingsMuted = Color(0xFF727B77);
const Color _settingsRule = Color(0xFFDFE4DE);
const Color _settingsAlert = Color(0xFFD85A30);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<String> _languages = [
    'English',
    'Zulu',
    'Sotho',
    'Xhosa',
    'Afrikaans',
  ];

  static const List<String> _radiusOptions = [
    '100m',
    '250m',
    '500m',
    '1km',
    '2km',
  ];

  late final User? _user;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  final Set<String> _savingPreferences = <String>{};

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

  Map _preferences(Map<String, dynamic> data) {
    final raw = data['preferences'];
    return raw is Map ? raw : const <String, dynamic>{};
  }

  bool _boolPreference(
    Map<String, dynamic> data,
    String key,
    bool fallback,
  ) {
    final value = _preferences(data)[key];
    return value is bool ? value : fallback;
  }

  String _stringPreference(
    Map<String, dynamic> data,
    String key,
    List<String> options,
    String fallback,
  ) {
    final value = _preferences(data)[key];
    return value is String && options.contains(value) ? value : fallback;
  }

  Future<void> _savePreference(String key, Object value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Sign in again to save settings.');
      return;
    }

    setState(() => _savingPreferences.add(key));
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'preferences': {key: value}},
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not save this preference. Check your connection and Firestore rules.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingPreferences.remove(key));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _settingsPaper,
      body: Column(
        children: [
          _buildMasthead(),
          Expanded(child: _buildSettingsBody()),
        ],
      ),
    );
  }

  Widget _buildSettingsBody() {
    if (_user == null || _profileStream == null) {
      return _buildMessage(
        icon: Icons.lock_outline,
        title: 'Sign in to manage settings',
        message: 'Your preferences are saved to your account.',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load settings',
            message: 'Check your connection and Firestore user-profile rules.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _settingsGreen),
          );
        }

        if (snapshot.data == null || !snapshot.data!.exists) {
          return _buildMessage(
            icon: Icons.person_off_outlined,
            title: 'Profile not found',
            message:
                'Settings are stored under users/${_user.uid}. Create or repair that profile before saving preferences.',
          );
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final language =
            _stringPreference(data, 'language', _languages, 'English');
        final radius =
            _stringPreference(data, 'alertRadius', _radiusOptions, '500m');

        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 34),
          children: [
            _buildNotice(),
            const SizedBox(height: 30),
            _buildSection(
              index: '01',
              title: 'Appearance',
              children: [
                _buildToggleTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark mode',
                  subtitle: 'Save your preferred appearance',
                  value: _boolPreference(data, 'darkMode', false),
                  saving: _savingPreferences.contains('darkMode'),
                  onChanged: (value) => _savePreference('darkMode', value),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 29),
            _buildSection(
              index: '02',
              title: 'Alerts & sound',
              children: [
                _buildToggleTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Sound alerts',
                  subtitle: 'Preference for notification sounds',
                  value: _boolPreference(data, 'soundAlerts', true),
                  saving: _savingPreferences.contains('soundAlerts'),
                  onChanged: (value) => _savePreference('soundAlerts', value),
                ),
                _buildToggleTile(
                  icon: Icons.vibration,
                  title: 'Vibration',
                  subtitle: 'Preference for alert vibration',
                  value: _boolPreference(data, 'vibration', true),
                  saving: _savingPreferences.contains('vibration'),
                  onChanged: (value) => _savePreference('vibration', value),
                ),
                _buildToggleTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Emergency alerts',
                  subtitle: 'Preference for emergency notifications',
                  value: _boolPreference(data, 'emergencyAlerts', true),
                  saving: _savingPreferences.contains('emergencyAlerts'),
                  onChanged: (value) =>
                      _savePreference('emergencyAlerts', value),
                  isEmergency: true,
                ),
                _buildToggleTile(
                  icon: Icons.cloud_outlined,
                  title: 'Weather advisories',
                  subtitle: 'Preference for campus weather notices',
                  value: _boolPreference(data, 'weatherAdvisories', false),
                  saving: _savingPreferences.contains('weatherAdvisories'),
                  onChanged: (value) =>
                      _savePreference('weatherAdvisories', value),
                ),
                _buildToggleTile(
                  icon: Icons.shield_outlined,
                  title: 'Patrol updates',
                  subtitle: 'Preference for campus patrol notices',
                  value: _boolPreference(data, 'patrolUpdates', false),
                  saving: _savingPreferences.contains('patrolUpdates'),
                  onChanged: (value) =>
                      _savePreference('patrolUpdates', value),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 29),
            _buildSection(
              index: '03',
              title: 'Location',
              children: [
                _buildToggleTile(
                  icon: Icons.gps_fixed,
                  title: 'Auto location',
                  subtitle: 'Preference for attaching location to reports',
                  value: _boolPreference(data, 'autoLocation', true),
                  saving: _savingPreferences.contains('autoLocation'),
                  onChanged: (value) => _savePreference('autoLocation', value),
                ),
                _buildDropdownTile(
                  icon: Icons.radar,
                  title: 'Alert radius',
                  subtitle: 'Preferred distance for nearby alerts',
                  value: radius,
                  options: _radiusOptions,
                  saving: _savingPreferences.contains('alertRadius'),
                  onChanged: (value) {
                    if (value != null) _savePreference('alertRadius', value);
                  },
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 29),
            _buildSection(
              index: '04',
              title: 'Language',
              children: [
                _buildDropdownTile(
                  icon: Icons.language,
                  title: 'App language',
                  subtitle: 'Preferred language',
                  value: language,
                  options: _languages,
                  saving: _savingPreferences.contains('language'),
                  onChanged: (value) {
                    if (value != null) _savePreference('language', value);
                  },
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 29),
            _buildSection(
              index: '05',
              title: 'Privacy',
              children: [
                _buildToggleTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Anonymous reports by default',
                  subtitle: 'Save your preference for future reports',
                  value: _boolPreference(data, 'anonymousReports', false),
                  saving: _savingPreferences.contains('anonymousReports'),
                  onChanged: (value) =>
                      _savePreference('anonymousReports', value),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 29),
            _buildSection(
              index: '06',
              title: 'About',
              children: const [
                _InfoTile(
                  icon: Icons.info_outline,
                  title: 'Smart Campus Safety',
                  subtitle: 'Version 1.0.0',
                  isLast: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMasthead() {
    return Container(
      width: double.infinity,
      color: _settingsGreen,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        22,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 6),
              Text(
                'SMARTSAFE',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.25,
                ),
              ),
              const Spacer(),
              Text(
                'ACCOUNT',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'SETTINGS  /  01',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set your\npreferences.',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.55,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 28, height: 1, color: const Color(0xFFA9D6C8)),
              const SizedBox(width: 8),
              Text(
                'Choose how campus safety reaches you',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _settingsGreen, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, color: _settingsGreen, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Preferences are saved to your Firestore profile. Theme, language, sound, location automation, and notification delivery must also be connected to these saved values elsewhere in the app before they change app behavior.',
              style: const TextStyle(
                color: _settingsMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 30, 30, 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _settingsMuted),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _settingsInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _settingsMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String index,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              index,
              style: GoogleFonts.spaceGrotesk(
                color: _settingsGreen,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: _settingsMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Divider(height: 1, thickness: 1, color: _settingsRule),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Column(children: children),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool saving,
    required ValueChanged<bool> onChanged,
    bool isEmergency = false,
    bool isLast = false,
  }) {
    final accent = isEmergency ? _settingsAlert : _settingsGreen;
    return _SettingsRowContainer(
      isLast: isLast,
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: isEmergency ? _settingsAlert : _settingsInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _settingsMuted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (saving)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            Switch.adaptive(
              value: value,
              activeColor: accent,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required bool saving,
    required ValueChanged<String?> onChanged,
    bool isLast = false,
  }) {
    return _SettingsRowContainer(
      isLast: isLast,
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: _settingsGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: _settingsInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _settingsMuted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (saving)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _settingsGreen,
              ),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: _settingsGreen,
                  size: 20,
                ),
                style: GoogleFonts.spaceGrotesk(
                  color: _settingsGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsRowContainer extends StatelessWidget {
  final Widget child;
  final bool isLast;

  const _SettingsRowContainer({required this.child, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _settingsRule)),
      ),
      child: child,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsRowContainer(
      isLast: isLast,
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: _settingsGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: _settingsInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _settingsMuted,
                    fontSize: 11,
                    height: 1.35,
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
