import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'report_screen.dart';

const Color _paper = Color(0xFFF7F6F0);
const Color _green = Color(0xFF0F6E56);
const Color _ink = Color(0xFF182522);
const Color _muted = Color(0xFF727B77);
const Color _rule = Color(0xFFDFE4DE);
const Color _alert = Color(0xFFD85A30);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final User? _user;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _incidentStream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    final uid = _user?.uid;
    _incidentStream = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('incidents')
            .where('reportedBy', isEqualTo: uid)
            .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        foregroundColor: _ink,
        elevation: 0,
        titleSpacing: 22,
        title: Text(
          'SMARTSAFE  /  ACTIVITY',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.15,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open incident history',
            onPressed: () => Navigator.pushNamed(context, '/incident-history'),
            icon: const Icon(Icons.history, size: 21),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _user == null || _incidentStream == null
          ? _stateNotice(
              icon: Icons.lock_outline,
              title: 'Sign in to view your activity.',
              body: 'Reports linked to your account will appear here.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incidentStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _stateNotice(
                    icon: Icons.cloud_off_outlined,
                    title: 'Your activity could not load.',
                    body:
                        'Check your connection and Firestore rules. This screen reads only reports linked to your UID.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                final reports = (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(_FieldGuideIncident.fromDocument)
                    .toList()
                  ..sort((a, b) {
                    final aTime = a.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime = b.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime);
                  });

                final counts = <_ReportState, int>{
                  for (final state in _ReportState.values) state: 0,
                };
                for (final report in reports) {
                  counts[report.state] = (counts[report.state] ?? 0) + 1;
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 17, 22, 30),
                  children: [
                    _intro(reports.length),
                    const SizedBox(height: 30),
                    _SectionTitle(number: '01', title: 'Status overview'),
                    const SizedBox(height: 11),
                    _StatusLine(
                      label: 'Pending',
                      count: counts[_ReportState.pending] ?? 0,
                      color: const Color(0xFF9A5B0A),
                    ),
                    _StatusLine(
                      label: 'In progress',
                      count: counts[_ReportState.inProgress] ?? 0,
                      color: const Color(0xFF185FA5),
                    ),
                    _StatusLine(
                      label: 'Resolved',
                      count: counts[_ReportState.resolved] ?? 0,
                      color: _green,
                    ),
                    _StatusLine(
                      label: 'Cancelled',
                      count: counts[_ReportState.cancelled] ?? 0,
                      color: _muted,
                      isLast: true,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            number: '02',
                            title: 'Recent reports',
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                              context, '/incident-history'),
                          style: TextButton.styleFrom(
                            foregroundColor: _green,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'HISTORY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (reports.isEmpty)
                      const _InlineMessage(
                        text: 'No reports yet. Reports you submit while signed in will appear here. Anonymous reports are not linked to your account.',
                      )
                    else
                      ...reports.take(5).toList().asMap().entries.map(
                            (entry) => _ReportTimelineRow(
                              report: entry.value,
                              isLast: entry.key == reports.take(5).length - 1,
                            ),
                          ),
                    const SizedBox(height: 15),
                    const _InlineMessage(
                      text: 'This list includes reports linked to your signed-in UID. Anonymous reports are not included.',
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReportScreen(),
            ),
          );
        },
        backgroundColor: _alert,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert),
        label: const Text('New report'),
      ),
    );
  }

  Widget _intro(int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SAFETY\nACTIVITY',
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 31,
            height: 1.03,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Text(
              '$total',
              style: GoogleFonts.spaceGrotesk(
                color: _green,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                total == 1 ? 'report linked to your account' : 'reports linked to your account',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            Text(
              DateFormat('d MMM').format(DateTime.now()).toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        const Divider(height: 1, color: _rule),
      ],
    );
  }

  Widget _stateNotice({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: _muted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReportState { pending, inProgress, resolved, cancelled }

_ReportState _stateFromFirestore(Object? raw) {
  switch (raw?.toString().trim().toLowerCase()) {
    case 'in progress':
    case 'responding':
    case 'review':
      return _ReportState.inProgress;
    case 'resolved':
    case 'done':
      return _ReportState.resolved;
    case 'cancelled':
    case 'canceled':
      return _ReportState.cancelled;
    default:
      return _ReportState.pending;
  }
}

String _stateLabel(_ReportState state) {
  switch (state) {
    case _ReportState.pending:
      return 'Pending';
    case _ReportState.inProgress:
      return 'In progress';
    case _ReportState.resolved:
      return 'Resolved';
    case _ReportState.cancelled:
      return 'Cancelled';
  }
}

Color _stateColor(_ReportState state) {
  switch (state) {
    case _ReportState.pending:
      return const Color(0xFF9A5B0A);
    case _ReportState.inProgress:
      return const Color(0xFF185FA5);
    case _ReportState.resolved:
      return _green;
    case _ReportState.cancelled:
      return _muted;
  }
}

class _FieldGuideIncident {
  final String reference;
  final String title;
  final String location;
  final DateTime? createdAt;
  final _ReportState state;
  final bool emergency;

  const _FieldGuideIncident({
    required this.reference,
    required this.title,
    required this.location,
    required this.createdAt,
    required this.state,
    required this.emergency,
  });

  factory _FieldGuideIncident.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawType = data['type'];
    final type = rawType is String && rawType.trim().isNotEmpty
        ? rawType.trim()
        : 'Incident';
    final source = (data['source'] as String?)?.toLowerCase() ?? '';
    final emergency = source == 'panic_button' || type.toLowerCase() == 'emergency';
    final rawLocation = data['location'];
    var location = rawLocation is String ? rawLocation.trim() : '';
    final point = data['locationPoint'];
    if (location.isEmpty && point is GeoPoint) {
      location = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
    if (location.isEmpty) location = 'Location unavailable';
    final rawReference = data['refNumber'];
    final created = data['createdAt'];
    final updated = data['updatedAt'];

    return _FieldGuideIncident(
      reference: rawReference is String && rawReference.trim().isNotEmpty
          ? rawReference.trim()
          : document.id,
      title: emergency ? 'Emergency SOS' : type,
      location: location,
      createdAt: created is Timestamp
          ? created.toDate()
          : updated is Timestamp
              ? updated.toDate()
              : null,
      state: _stateFromFirestore(data['status']),
      emergency: emergency,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String number;
  final String title;

  const _SectionTitle({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: GoogleFonts.spaceGrotesk(
            color: _green,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isLast;

  const _StatusLine({
    required this.label,
    required this.count,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _rule)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTimelineRow extends StatelessWidget {
  final _FieldGuideIncident report;
  final bool isLast;

  const _ReportTimelineRow({required this.report, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final time = report.createdAt == null
        ? 'TIME PENDING'
        : DateFormat('d MMM  ·  h:mm a')
            .format(report.createdAt!.toLocal())
            .toUpperCase();
    final color = _stateColor(report.state);

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/incident-history'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: report.emergency ? _alert : _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: _rule,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.spaceGrotesk(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.65,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _stateLabel(report.state).toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.location}  ·  ${report.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Divider(height: 1, color: _rule),
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

class _InlineMessage extends StatelessWidget {
  final String text;

  const _InlineMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.45),
      ),
    );
  }
}
