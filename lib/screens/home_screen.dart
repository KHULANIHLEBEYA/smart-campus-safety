import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import '../config/campus_safety_config.dart';

const Color _guideGreen = Color(0xFF0F6E56);
const Color _guideInk = Color(0xFF182522);
const Color _guideMuted = Color(0xFF727B77);
const Color _guideRule = Color(0xFFDFE4DE);
const Color _guideAlert = Color(0xFFD85A30);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _paper = Color(0xFFF7F6F0);
  static const Color _green = Color(0xFF0F6E56);
  static const Color _ink = Color(0xFF182522);
  static const Color _muted = Color(0xFF727B77);
  static const Color _rule = Color(0xFFDFE4DE);
  static const Color _alert = Color(0xFFD85A30);

  int _currentIndex = 0;
  late final User? _user;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _incidentStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    final uid = _user?.uid;
    _profileStream = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    _incidentStream = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('incidents')
            .where('reportedBy', isEqualTo: uid)
            .snapshots();
    _notificationStream = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUid', isEqualTo: uid)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _buildHomeBody(),
      const ReportScreen(),
      const DashboardScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: _paper,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildMasthead()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeLine(),
                const SizedBox(height: 22),
                _buildEmergencyAction(),
                const SizedBox(height: 28),
                _buildQuickAccess(),
                const SizedBox(height: 30),
                _buildRecentReports(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMasthead() {
    return Container(
      color: _green,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 14,
        18,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.explore_outlined,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Text(
                'SMARTSAFE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _buildNotificationButton(),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Profile',
                onPressed: () => setState(() => _currentIndex = 4),
                icon: const Icon(Icons.account_circle_outlined,
                    color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Text(
            'CAMPUS FIELD GUIDE  /  01',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Safety,\nwithin reach.',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 31,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 28, height: 1, color: const Color(0xFFA9D6C8)),
              const SizedBox(width: 8),
              Text(
                'A practical guide for safer campus days',
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

  Widget _buildNotificationButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((doc) => doc.data()['isRead'] != true)
            .length;

        return IconButton(
          tooltip: unreadCount == 0
              ? 'Notifications'
              : '$unreadCount unread notifications',
          onPressed: () => setState(() => _currentIndex = 3),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_outlined,
                  color: Colors.white, size: 23),
              if (unreadCount > 0)
                Positioned(
                  top: -5,
                  right: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _alert,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        );
      },
    );
  }

  Widget _buildWelcomeLine() {
    if (_profileStream == null) {
      return _welcomeText('there');
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final fullName = data?['fullName'];
        final firstName = fullName is String && fullName.trim().isNotEmpty
            ? fullName.trim().split(RegExp(r'\s+')).first
            : 'there';
        return _welcomeText(firstName);
      },
    );
  }

  Widget _welcomeText(String firstName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                firstName == 'there' ? 'Stay aware.' : 'Welcome, $firstName.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        Text(
          DateFormat('EEE  ·  d MMM').format(DateTime.now()).toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyAction() {
    return Semantics(
      button: true,
      label: 'Open emergency SOS screen',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, '/panic'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _alert,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 27),
                    const SizedBox(height: 1),
                    Text(
                      'SOS',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help now?',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Open emergency alert options',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'TAP SOS',
                      style: GoogleFonts.spaceGrotesk(
                        color: _alert,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: _alert, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          index: '01',
          title: 'Quick access',
          trailing: 'CAMPUS TOOLS',
        ),
        const SizedBox(height: 9),
        _QuickAccessRow(
          number: 'A',
          icon: Icons.edit_note_outlined,
          title: 'Report an incident',
          subtitle: 'Share what happened',
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _QuickAccessRow(
          number: 'B',
          icon: Icons.place_outlined,
          title: 'Safe zones',
          subtitle: 'Browse verified campus locations',
          onTap: () => Navigator.pushNamed(context, '/safe-zones'),
        ),
        _QuickAccessRow(
          number: 'C',
          icon: Icons.phone_in_talk_outlined,
          title: 'Call campus security',
          subtitle: 'Call the campus security line',
          onTap: _callCampusSecurity,
          isLast: true,
        ),
      ],
    );
  }

  Future<void> _callCampusSecurity() async {
    final number = CampusSafetyConfig.securityPhoneNumber.trim();
    if (number.isEmpty) {
      _showSecurityCallMessage(
        'Campus security phone number is not configured.',
      );
      return;
    }

    final normalized = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      _showSecurityCallMessage(
        'The configured security number is not a valid international number.',
      );
      return;
    }

    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: normalized),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showSecurityCallMessage('Could not open the phone dialer.');
      }
    } catch (_) {
      if (!mounted) return;
      _showSecurityCallMessage(
        'Could not open the phone dialer. Call campus security directly.',
      );
    }
  }

  void _showSecurityCallMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildRecentReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          index: '02',
          title: 'Recent reports',
          trailing: 'YOUR ACTIVITY',
          action: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/incident-history'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _green,
            ),
            child: const Text(
              'View all',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 11),
        if (_user == null || _incidentStream == null)
          const _InlineNotice(
            icon: Icons.lock_outline,
            text: 'Sign in to see reports linked to your account.',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _incidentStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _InlineNotice(
                  icon: Icons.cloud_off_outlined,
                  text: 'Reports could not be loaded. Check your connection and Firestore rules.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    ),
                  ),
                );
              }

              final reports = (snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .map(_HomeReport.fromDocument)
                  .toList()
                ..sort((a, b) {
                  final aTime = a.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime = b.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });

              if (reports.isEmpty) {
                return const _InlineNotice(
                  icon: Icons.auto_stories_outlined,
                  text: 'Your signed-in reports will appear here. Anonymous reports are not linked to your account.',
                );
              }

              return Column(
                children: reports
                    .take(3)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) => _TimelineReportRow(
                          report: entry.value,
                          isLast: entry.key == reports.take(3).length - 1,
                        ))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBottomNav() {
    const items = <_NavItemData>[
      _NavItemData(Icons.home_outlined, Icons.home, 'Home'),
      _NavItemData(Icons.add_circle_outline, Icons.add_circle, 'Report'),
      _NavItemData(Icons.stacked_line_chart, Icons.stacked_line_chart, 'Activity'),
      _NavItemData(Icons.notifications_none_outlined, Icons.notifications, 'Alerts'),
      _NavItemData(Icons.person_outline, Icons.person, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _paper,
        border: Border(top: BorderSide(color: _rule, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 59,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final tabIndex = entry.key;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = tabIndex),
                  child: _NavItemView(
                    data: entry.value,
                    selected: _currentIndex == tabIndex,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _HomeReport {
  final String refNumber;
  final String title;
  final String location;
  final String status;
  final DateTime? createdAt;
  final bool isEmergency;

  const _HomeReport({
    required this.refNumber,
    required this.title,
    required this.location,
    required this.status,
    required this.createdAt,
    required this.isEmergency,
  });

  factory _HomeReport.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawType = data['type'];
    final type = rawType is String && rawType.trim().isNotEmpty
        ? rawType.trim()
        : 'Incident';
    final source = (data['source'] as String?)?.trim().toLowerCase() ?? '';
    final isEmergency = source == 'panic_button' || type.toLowerCase() == 'emergency';

    final rawLocation = data['location'];
    var location = rawLocation is String ? rawLocation.trim() : '';
    final point = data['locationPoint'];
    if (location.isEmpty && point is GeoPoint) {
      location = '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}';
    }
    if (location.isEmpty) location = 'Location unavailable';

    final rawRef = data['refNumber'];
    final rawCreated = data['createdAt'];
    final rawUpdated = data['updatedAt'];
    final rawStatus = data['status'];

    return _HomeReport(
      refNumber: rawRef is String && rawRef.trim().isNotEmpty
          ? rawRef.trim()
          : document.id,
      title: isEmergency ? 'Emergency SOS' : type,
      location: location,
      status: _formatStatus(rawStatus),
      createdAt: rawCreated is Timestamp
          ? rawCreated.toDate()
          : rawUpdated is Timestamp
              ? rawUpdated.toDate()
              : null,
      isEmergency: isEmergency,
    );
  }
}

String _formatStatus(Object? value) {
  final status = value?.toString().trim().toLowerCase() ?? '';
  switch (status) {
    case 'in progress':
    case 'responding':
    case 'review':
      return 'In progress';
    case 'resolved':
    case 'done':
      return 'Resolved';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'In progress':
      return const Color(0xFF185FA5);
    case 'Resolved':
      return const Color(0xFF0F6E56);
    case 'Cancelled':
      return const Color(0xFF667085);
    default:
      return const Color(0xFF854F0B);
  }
}

class _TimelineReportRow extends StatelessWidget {
  final _HomeReport report;
  final bool isLast;

  const _TimelineReportRow({required this.report, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final timeLabel = report.createdAt == null
        ? 'TIME PENDING'
        : DateFormat('d MMM  ·  h:mm a')
            .format(report.createdAt!.toLocal())
            .toUpperCase();
    final statusColor = _statusColor(report.status);

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/incident-history'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 25,
              child: Column(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: report.isEmergency ? _guideAlert : _guideGreen,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: _guideRule,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeLabel,
                      style: GoogleFonts.spaceGrotesk(
                        color: _guideMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _guideInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          report.status.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.location}  ·  ${report.refNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _guideMuted, fontSize: 11),
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Divider(height: 1, color: _guideRule),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String index;
  final String title;
  final String trailing;
  final Widget? action;

  const _SectionHeading({
    required this.index,
    required this.title,
    required this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          index,
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF0F6E56),
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
              color: const Color(0xFF182522),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (action != null)
          action!
        else
          Text(
            trailing,
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF727B77),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _QuickAccessRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFDFE4DE))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 23,
              child: Text(
                number,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF89928D),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, color: const Color(0xFF0F6E56), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF182522),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF727B77),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_outward, color: Color(0xFF89928D), size: 16),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF727B77)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF727B77),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItemData(this.icon, this.selectedIcon, this.label);
}

class _NavItemView extends StatelessWidget {
  final _NavItemData data;
  final bool selected;

  const _NavItemView({required this.data, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0F6E56) : const Color(0xFF87908B);
    return SizedBox(
      height: 59,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? data.selectedIcon : data.icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            data.label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
