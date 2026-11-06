import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color _adminPaper = Color(0xFFF7F6F0);
const Color _adminGreen = Color(0xFF0F6E56);
const Color _adminInk = Color(0xFF182522);
const Color _adminMuted = Color(0xFF727B77);
const Color _adminRule = Color(0xFFDFE4DE);
const Color _adminAlert = Color(0xFFD85A30);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _incidentStream;

  @override
  void initState() {
    super.initState();
    _incidentStream = FirebaseFirestore.instance
        .collection('incidents')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminPaper,
      body: Column(
        children: [
          _masthead(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incidentStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    icon: Icons.cloud_off_outlined,
                    title: 'Dashboard unavailable',
                    detail: 'Check your connection and staff Firestore access.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _adminGreen),
                  );
                }
                final reports = (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(_AdminReport.fromDocument)
                    .toList()
                  ..sort((a, b) =>
                      (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                          .compareTo(a.createdAt ??
                              DateTime.fromMillisecondsSinceEpoch(0)));
                return _dashboard(reports);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _masthead(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _adminGreen,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 16,
        22,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                'SMARTSAFE  /  OPERATIONS',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, color: Color(0xFFA9D6C8), size: 7),
              const SizedBox(width: 5),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Text(
            'Operations\noverview.',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Campus reports and response activity',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(List<_AdminReport> reports) {
    final pending = reports.where((r) => r.status == _ReportStatus.pending).length;
    final responding =
        reports.where((r) => r.status == _ReportStatus.inProgress).length;
    final resolved = reports.where((r) => r.status == _ReportStatus.resolved).length;
    final needsAttention = reports
        .where((r) =>
            r.status == _ReportStatus.pending ||
            r.status == _ReportStatus.inProgress)
        .take(5)
        .toList();
    final recent = reports.take(6).toList();

    return RefreshIndicator(
      color: _adminGreen,
      onRefresh: () async {
        await FirebaseFirestore.instance.collection('incidents').get();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 23, 22, 30),
        children: [
          _sectionHeading('01', 'At a glance', trailing: 'LIVE TOTALS'),
          const SizedBox(height: 8),
          _metrics(
            total: reports.length,
            pending: pending,
            responding: responding,
            resolved: resolved,
          ),
          const SizedBox(height: 28),
          _sectionHeading('02', 'Needs attention', trailing: '${pending + responding} OPEN'),
          const SizedBox(height: 5),
          if (needsAttention.isEmpty)
            _emptyLine('No reports are awaiting a response.')
          else
            ...needsAttention.map((report) => _reportRow(report, priority: true)),
          const SizedBox(height: 27),
          _sectionHeading('03', 'Latest reports', trailing: 'NEWEST FIRST'),
          const SizedBox(height: 5),
          if (recent.isEmpty)
            _emptyLine('New student reports will appear here.')
          else
            ...recent.map((report) => _reportRow(report)),
        ],
      ),
    );
  }

  Widget _sectionHeading(String number, String title, {String? trailing}) {
    return Row(
      children: [
        Text(
          number,
          style: GoogleFonts.spaceGrotesk(
            color: _adminGreen,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: _adminInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.spaceGrotesk(
              color: _adminMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.65,
            ),
          ),
      ],
    );
  }

  Widget _metrics({
    required int total,
    required int pending,
    required int responding,
    required int resolved,
  }) {
    final values = [
      ('TOTAL REPORTS', total, _adminInk),
      ('PENDING', pending, const Color(0xFF854F0B)),
      ('IN PROGRESS', responding, const Color(0xFF185FA5)),
      ('RESOLVED', resolved, _adminGreen),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const Divider(height: 1, color: _adminRule),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 17),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${values[row * 2 + col].$2}',
                          style: GoogleFonts.spaceGrotesk(
                            color: values[row * 2 + col].$3,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          values[row * 2 + col].$1,
                          style: GoogleFonts.spaceGrotesk(
                            color: _adminMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _reportRow(_AdminReport report, {bool priority = false}) {
    final title = report.isSos ? 'SOS alert' : report.type;
    final time = report.createdAt == null
        ? 'Time pending'
        : DateFormat('d MMM · h:mm a').format(report.createdAt!.toLocal());
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _adminRule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              report.isSos ? Icons.warning_amber_rounded : Icons.circle,
              size: report.isSos ? 18 : 9,
              color: report.isSos ? _adminAlert : _adminGreen,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${report.location}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _adminInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time  /  ${report.refNumber}',
                  style: const TextStyle(color: _adminMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusLabel(report.status, urgent: priority && report.isSos),
        ],
      ),
    );
  }

  Widget _statusLabel(_ReportStatus status, {bool urgent = false}) {
    final color = urgent ? _adminAlert : switch (status) {
      _ReportStatus.pending => const Color(0xFF854F0B),
      _ReportStatus.inProgress => const Color(0xFF185FA5),
      _ReportStatus.resolved => _adminGreen,
      _ReportStatus.cancelled => _adminMuted,
    };
    return Text(
      status.label.toUpperCase(),
      style: GoogleFonts.spaceGrotesk(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
    );
  }

  Widget _emptyLine(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Text(message, style: const TextStyle(color: _adminMuted, fontSize: 12)),
      );

  Widget _message({required IconData icon, required String title, required String detail}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _adminMuted, size: 40),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w700, color: _adminInk)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _adminMuted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

enum _ReportStatus { pending, inProgress, resolved, cancelled }

extension on _ReportStatus {
  String get label => switch (this) {
        _ReportStatus.pending => 'Pending',
        _ReportStatus.inProgress => 'In progress',
        _ReportStatus.resolved => 'Resolved',
        _ReportStatus.cancelled => 'Cancelled',
      };
}

_ReportStatus _parseStatus(Object? raw) {
  switch (raw?.toString().trim().toLowerCase()) {
    case 'in progress':
    case 'in_progress':
    case 'responding':
      return _ReportStatus.inProgress;
    case 'resolved':
    case 'done':
      return _ReportStatus.resolved;
    case 'cancelled':
    case 'canceled':
      return _ReportStatus.cancelled;
    case 'active':
    case 'open':
    case 'pending':
    default:
      return _ReportStatus.pending;
  }
}

class _AdminReport {
  final String refNumber;
  final String type;
  final String location;
  final DateTime? createdAt;
  final _ReportStatus status;
  final bool isSos;

  const _AdminReport({
    required this.refNumber,
    required this.type,
    required this.location,
    required this.createdAt,
    required this.status,
    required this.isSos,
  });

  factory _AdminReport.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final typeValue = data['type'];
    final type = typeValue is String && typeValue.trim().isNotEmpty ? typeValue.trim() : 'Incident';
    final rawLocation = data['location'];
    var location = rawLocation is String ? rawLocation.trim() : '';
    final point = data['locationPoint'];
    if (location.isEmpty && point is GeoPoint) {
      location = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
    if (location.isEmpty) location = 'Location unavailable';
    final timeValue = data['createdAt'];
    final fallbackTime = data['updatedAt'];
    final createdAt = timeValue is Timestamp
        ? timeValue.toDate()
        : fallbackTime is Timestamp
            ? fallbackTime.toDate()
            : null;
    final rawRef = data['refNumber'];
    final source = data['source'];
    return _AdminReport(
      refNumber: rawRef is String && rawRef.trim().isNotEmpty ? rawRef.trim() : doc.id,
      type: type,
      location: location,
      createdAt: createdAt,
      status: _parseStatus(data['status']),
      isSos: source == 'panic_button' || type.toLowerCase() == 'emergency',
    );
  }
}
