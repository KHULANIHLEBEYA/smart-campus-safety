import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'admin_incident_details_sheet.dart';
import '../services/csv_file_saver.dart';

const MethodChannel _incidentExportChannel =
    MethodChannel('com.khulani.smart_campus_safety/incident_export');

const Color _incidentPaper = Color(0xFFF7F6F0);
const Color _incidentGreen = Color(0xFF0F6E56);
const Color _incidentInk = Color(0xFF182522);
const Color _incidentMuted = Color(0xFF727B77);
const Color _incidentRule = Color(0xFFDFE4DE);
const Color _incidentAlert = Color(0xFFD85A30);

class ManageIncidentsScreen extends StatefulWidget {
  const ManageIncidentsScreen({super.key});

  @override
  State<ManageIncidentsScreen> createState() => _ManageIncidentsScreenState();
}

class _ManageIncidentsScreenState extends State<ManageIncidentsScreen> {
  final _searchController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _incidentStream;
  _IncidentFilter _filter = _IncidentFilter.all;
  String _query = '';
  String? _updatingId;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _incidentStream = FirebaseFirestore.instance.collection('incidents').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _incidentPaper,
      body: Column(
        children: [
          _masthead(context),
          _searchField(),
          _filters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _incidentStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    icon: Icons.cloud_off_outlined,
                    title: 'Reports unavailable',
                    detail: 'Check your connection and staff Firestore access.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _incidentGreen));
                }
                final reports = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(_ManagedIncident.fromDocument)
                    .toList()
                  ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
                final filtered = reports.where(_matches).toList();
                if (filtered.isEmpty) {
                  return _message(
                    icon: reports.isEmpty ? Icons.inbox_outlined : Icons.search_off_outlined,
                    title: reports.isEmpty ? 'No reports yet' : 'No matching reports',
                    detail: reports.isEmpty
                        ? 'Student reports and SOS alerts will appear here.'
                        : 'Try another status filter or search term.',
                  );
                }
                return RefreshIndicator(
                  color: _incidentGreen,
                  onRefresh: () async { await FirebaseFirestore.instance.collection('incidents').get(); },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _incidentRow(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(_ManagedIncident report) {
    if (_filter != _IncidentFilter.all && report.status != _filter) return false;
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return report.type.toLowerCase().contains(q) ||
        report.location.toLowerCase().contains(q) ||
        report.description.toLowerCase().contains(q) ||
        report.refNumber.toLowerCase().contains(q);
  }

  Widget _masthead(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _incidentGreen,
      padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 16, 22, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SMARTSAFE  /  RESPONSE DESK', style: GoogleFonts.spaceGrotesk(color: Colors.white.withValues(alpha: 0.76), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 14),
          Text('Incident register.', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 5),
          const Text('Review reports and update their response status.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportIncidents,
              icon: _isExporting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.file_download_outlined, size: 17),
              label: Text(_isExporting ? 'Preparing CSV…' : 'Export full CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportIncidents() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      // Deliberately query the collection directly: current search and status
      // filters only affect the list, never the admin export.
      final snapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .get(const GetOptions(source: Source.server));
      final incidents = snapshot.docs
          .map((doc) => _ExportIncident.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);
      final csv = _buildIncidentCsv(incidents);
      final fileName =
          'smart_campus_incidents_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final bool saved;
      if (kIsWeb) {
        saved = await downloadCsvFile(fileName, csv);
      } else {
        saved = await _incidentExportChannel.invokeMethod<bool>(
              'saveCsv',
              {'fileName': fileName, 'contents': csv},
            ) ??
            false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(saved
              ? (kIsWeb ? 'CSV report downloaded.' : 'CSV report saved.')
              : 'CSV export cancelled.'),
          behavior: SnackBarBehavior.floating,
        ));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Export denied. Check admin Firestore read access and the published security rules.'
          : 'Could not load the incident collection (${error.code}).';
      _showExportError(message);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showExportError(error.message?.isNotEmpty == true
          ? 'Could not save the CSV: ${error.message}'
          : 'Could not open the system save picker.');
    } catch (error) {
      if (!mounted) return;
      _showExportError('Could not export the incident report: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _incidentAlert,
        duration: const Duration(seconds: 7),
      ));
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 17, 22, 5),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(color: _incidentInk, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search type, location, reference…',
          hintStyle: const TextStyle(color: _incidentMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: _incidentGreen, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                  icon: const Icon(Icons.close, size: 18, color: _incidentMuted),
                ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: _incidentRule)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _incidentRule)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _incidentGreen, width: 1.5)),
        ),
      ),
    );
  }

  Widget _filters() {
    final filters = _IncidentFilter.values;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = filter == _filter;
          return InkWell(
            onTap: () => setState(() => _filter = filter),
            child: Center(
              child: Text(
                filter.label.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? _incidentGreen : _incidentMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _incidentRow(_ManagedIncident report) {
    final time = report.createdAt == null
        ? 'Time pending'
        : DateFormat('d MMM yyyy · h:mm a').format(report.createdAt!.toLocal());
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _incidentRule))),
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showAdminIncidentDetails(context, report.details),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(report.isSos ? Icons.warning_amber_rounded : Icons.circle,
                      size: report.isSos ? 18 : 9,
                      color: report.isSos ? _incidentAlert : _incidentGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.isSos ? 'SOS emergency · ${report.location}' : '${report.type} · ${report.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(color: _incidentInk, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _statusText(report.status),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right, size: 17, color: _incidentMuted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 5),
            child: Text('$time  /  REF ${report.refNumber}', style: const TextStyle(color: _incidentMuted, fontSize: 10)),
          ),
          if (report.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 7),
              child: Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _incidentMuted, fontSize: 12, height: 1.4)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _updatingId == report.documentId ? null : () => _showStatusSheet(report),
              icon: _updatingId == report.documentId
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _incidentGreen))
                  : const Icon(Icons.tune, size: 15, color: _incidentGreen),
              label: Text(_updatingId == report.documentId ? 'Saving…' : 'Update status',
                  style: const TextStyle(color: _incidentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusText(_IncidentFilter status) {
    final color = switch (status) {
      _IncidentFilter.pending => const Color(0xFF854F0B),
      _IncidentFilter.inProgress => const Color(0xFF185FA5),
      _IncidentFilter.resolved => _incidentGreen,
      _IncidentFilter.cancelled => _incidentMuted,
      _IncidentFilter.all => _incidentMuted,
    };
    return Text(status.label.toUpperCase(), style: GoogleFonts.spaceGrotesk(color: color, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.45));
  }

  Future<void> _showStatusSheet(_ManagedIncident report) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _incidentPaper,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UPDATE RESPONSE', style: GoogleFonts.spaceGrotesk(color: _incidentGreen, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(report.refNumber, style: GoogleFonts.spaceGrotesk(color: _incidentInk, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              for (final status in [_IncidentFilter.pending, _IncidentFilter.inProgress, _IncidentFilter.resolved, _IncidentFilter.cancelled])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(status.label, style: const TextStyle(color: _incidentInk, fontWeight: FontWeight.w600)),
                  trailing: report.status == status ? const Icon(Icons.check, color: _incidentGreen) : null,
                  onTap: () { Navigator.pop(sheetContext); if (status != report.status) _saveStatus(report, status); },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveStatus(_ManagedIncident report, _IncidentFilter status) async {
    setState(() => _updatingId = report.documentId);
    final updates = <String, Object?>{
      'status': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == _IncidentFilter.resolved) updates['resolvedAt'] = FieldValue.serverTimestamp();
    if (status == _IncidentFilter.cancelled) updates['cancelledAt'] = FieldValue.serverTimestamp();
    try {
      await FirebaseFirestore.instance.collection('incidents').doc(report.documentId).update(updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Incident status updated.'), behavior: SnackBarBehavior.floating));
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error.code == 'permission-denied'
              ? 'Update denied. Check that your account has admin or security access and the current Firestore rules are published.'
              : 'Could not update the report (${error.code}).'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _incidentAlert,
        ));
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  Widget _message({required IconData icon, required String title, required String detail}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: _incidentMuted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _incidentInk, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _incidentMuted, height: 1.4)),
        ]),
      ),
    );
  }
}

enum _IncidentFilter { all, pending, inProgress, resolved, cancelled }

extension on _IncidentFilter {
  String get label => switch (this) {
        _IncidentFilter.all => 'All',
        _IncidentFilter.pending => 'Pending',
        _IncidentFilter.inProgress => 'In progress',
        _IncidentFilter.resolved => 'Resolved',
        _IncidentFilter.cancelled => 'Cancelled',
      };

  String get firestoreValue => switch (this) {
        _IncidentFilter.all => 'Active',
        _IncidentFilter.pending => 'Pending',
        _IncidentFilter.inProgress => 'In Progress',
        _IncidentFilter.resolved => 'Resolved',
        _IncidentFilter.cancelled => 'Cancelled',
      };
}

_IncidentFilter _parseStatus(Object? raw) {
  switch (raw?.toString().trim().toLowerCase()) {
    case 'in progress':
    case 'in_progress':
    case 'responding':
      return _IncidentFilter.inProgress;
    case 'resolved':
    case 'done':
      return _IncidentFilter.resolved;
    case 'cancelled':
    case 'canceled':
      return _IncidentFilter.cancelled;
    case 'active':
    case 'open':
    case 'pending':
    default:
      return _IncidentFilter.pending;
  }
}

class _ManagedIncident {
  final AdminIncidentDetailsData details;
  final String documentId;
  final String refNumber;
  final String type;
  final String description;
  final String location;
  final DateTime? createdAt;
  final _IncidentFilter status;
  final bool isSos;

  const _ManagedIncident({
    required this.details,
    required this.documentId,
    required this.refNumber,
    required this.type,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.status,
    required this.isSos,
  });

  factory _ManagedIncident.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final details = AdminIncidentDetailsData.fromFirestore(
      documentId: doc.id,
      data: data,
    );
    return _ManagedIncident(
      details: details,
      documentId: doc.id,
      refNumber: details.refNumber,
      type: details.type,
      description: details.description,
      location: details.location,
      createdAt: details.createdAt,
      status: _parseStatus(data['status']),
      isSos: details.isSos,
    );
  }
}

class _ExportIncident {
  final AdminIncidentDetailsData details;
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const _ExportIncident({
    required this.details,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory _ExportIncident.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    DateTime? timestamp(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final details = AdminIncidentDetailsData.fromFirestore(
      documentId: documentId,
      data: data,
    );
    return _ExportIncident(
      details: details,
      status: details.status,
      createdAt: timestamp(data['createdAt']),
      resolvedAt: timestamp(data['resolvedAt']),
    );
  }
}

String _buildIncidentCsv(List<_ExportIncident> incidents) {
  final byType = <String, int>{};
  final byStatus = <String, int>{};
  var sosCount = 0;
  for (final incident in incidents) {
    byType.update(incident.details.type, (count) => count + 1, ifAbsent: () => 1);
    byStatus.update(incident.status, (count) => count + 1, ifAbsent: () => 1);
    if (incident.details.isSos) sosCount++;
  }

  String iso(DateTime? date) => date?.toUtc().toIso8601String() ?? '';
  String csvCell(Object? field) {
    var value = field?.toString() ?? '';
    // Prefix untrusted text that spreadsheet apps might interpret as a formula.
    if (field is! num && field is! bool &&
        RegExp(r'^[\t\r ]*[=+@\-]').hasMatch(value)) {
      value = "'$value";
    }
    return '"${value.replaceAll('"', '""')}"';
  }
  String row(Iterable<Object?> fields) => fields.map(csvCell).join(',');

  final typeEntries = byType.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  final statusEntries = byStatus.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
  final rows = <Iterable<Object?>>[
    ['Incident report summary'],
    ['Metric', 'Count'],
    ['Total incidents', incidents.length],
    ['SOS count', sosCount],
    [''],
    ['Counts by incident type'],
    ['Incident type', 'Count'],
    ...typeEntries.map((entry) => [entry.key, entry.value]),
    [''],
    ['Counts by status'],
    ['Status', 'Count'],
    ...statusEntries.map((entry) => [entry.key, entry.value]),
    [''],
    ['Incident details'],
    [
      'Reference',
      'Type',
      'Source / SOS',
      'Status',
      'Created timestamp (UTC)',
      'Resolved timestamp (UTC)',
      'Location',
      'Latitude',
      'Longitude',
      'Reporter UID',
      'Description',
    ],
    ...incidents.map((incident) {
      final details = incident.details;
      return [
        details.refNumber,
        details.type,
        '${details.source.isEmpty ? 'Unknown source' : details.source} / ${details.isSos ? 'SOS' : 'Not SOS'}',
        incident.status,
        iso(incident.createdAt),
        iso(incident.resolvedAt),
        details.location,
        details.latitude,
        details.longitude,
        details.reporterUid,
        details.description,
      ];
    }),
  ];

  // UTF-8 BOM improves spreadsheet recognition; every field is quoted so
  // commas, quotes, and embedded newlines in user descriptions remain valid.
  return '\uFEFF${rows.map(row).join('\r\n')}\r\n';
}
