import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';


const Color _paper = Color(0xFFF7F6F0);
const Color _green = Color(0xFF0F6E56);
const Color _ink = Color(0xFF182522);
const Color _muted = Color(0xFF727B77);
const Color _rule = Color(0xFFDFE4DE);
const Color _alert = Color(0xFFD85A30);

enum IncidentStatus { active, inProgress, done, cancelled }

extension IncidentStatusPresentation on IncidentStatus {
  String get label {
    switch (this) {
      case IncidentStatus.active:
        return 'Pending';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.done:
        return 'Resolved';
      case IncidentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case IncidentStatus.active:
        return _alert;
      case IncidentStatus.inProgress:
        return _green;
      case IncidentStatus.done:
        return _green;
      case IncidentStatus.cancelled:
        return _muted;
    }
  }
}

IncidentStatus _statusFromFirestore(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'in progress':
    case 'responding':
    case 'review':
      return IncidentStatus.inProgress;
    case 'resolved':
    case 'done':
      return IncidentStatus.done;
    case 'cancelled':
    case 'canceled':
      return IncidentStatus.cancelled;
    case 'active':
    case 'open':
    case 'pending':
    default:
      return IncidentStatus.active;
  }
}

class Incident {
  final String id;
  final String documentId;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool timestampAvailable;
  final IncidentStatus status;
  final String location;
  final String reportedBy;
  final GeoPoint? locationPoint;
  final bool isPanic;

  const Incident({
    required this.id,
    required this.documentId,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.timestampAvailable,
    required this.status,
    required this.location,
    required this.reportedBy,
    required this.locationPoint,
    required this.isPanic,
  });

  factory Incident.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final typeValue = data['type'];
    final type = typeValue is String && typeValue.trim().isNotEmpty
        ? typeValue.trim()
        : 'Incident';

    final source = (data['source'] as String?)?.trim().toLowerCase() ?? '';
    final isPanic = source == 'panic_button' || type.toLowerCase() == 'emergency';

    final rawLocation = data['location'];
    var location = rawLocation is String ? rawLocation.trim() : '';
    final rawPoint = data['locationPoint'];
    final point = rawPoint is GeoPoint
        ? rawPoint
        : rawLocation is GeoPoint
            ? rawLocation
            : null;

    if (location.isEmpty && point != null) {
      location = '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}';
    }
    if (location.isEmpty) location = 'Location unavailable';

    final createdValue = data['createdAt'];
    final updatedValue = data['updatedAt'];
    final timestampAvailable = createdValue is Timestamp || updatedValue is Timestamp;
    final timestamp = createdValue is Timestamp
        ? createdValue.toDate()
        : updatedValue is Timestamp
            ? updatedValue.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);

    final refValue = data['refNumber'];
    final refNumber = refValue is String && refValue.trim().isNotEmpty
        ? refValue.trim()
        : document.id;
    final isAnonymous = data['isAnonymous'] == true;

    return Incident(
      id: refNumber,
      documentId: document.id,
      title: isPanic ? 'Emergency SOS' : type,
      description: (data['description'] as String?)?.trim() ?? '',
      timestamp: timestamp,
      timestampAvailable: timestampAvailable,
      status: _statusFromFirestore(data['status']),
      location: location,
      reportedBy: isAnonymous ? 'Anonymous' : 'You',
      locationPoint: point,
      isPanic: isPanic,
    );
  }
}

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  String _searchText = '';
  bool _isSearching = false;
  late final User? _user;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _incidentStream;

  static const List<String> _filters = [
    'All',
    'Pending',
    'In Progress',
    'Resolved',
    'Cancelled',
  ];

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 78,
        titleSpacing: 0,
        title: _isSearching ? _buildSearchField() : _buildMastheadTitle(),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter incidents',
            icon: const Icon(Icons.tune_outlined),
            color: _paper,
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder: (context) => _filters
                .map(
                  (filter) => PopupMenuItem<String>(
                    value: filter,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          child: filter == _selectedFilter
                              ? const Icon(Icons.check, color: _green, size: 18)
                              : null,
                        ),
                        Text(
                          filter,
                          style: GoogleFonts.spaceGrotesk(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: filter == _selectedFilter
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: _isSearching ? 'Close search' : 'Search reports',
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchText = '';
                }
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _user == null
          ? _buildMessage(
              icon: Icons.lock_outline,
              title: 'Sign in to view your reports',
              message: 'Your incident history is linked to your account.',
            )
          : Column(
              children: [
                _buildSectionHeader(),
                const Divider(height: 1, color: _rule),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _incidentStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildMessage(
                          icon: Icons.cloud_off_outlined,
                          title: 'Could not load reports',
                          message:
                              'Check your connection and Firestore rules. Your history only reads reports linked to your account.',
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _green,
                            ),
                          ),
                        );
                      }

                      final incidents = (snapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(Incident.fromDocument)
                          .toList()
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      final filtered = incidents.where(_matchesFilter).toList();
                      if (filtered.isEmpty) {
                        return _buildMessage(
                          icon: Icons.history,
                          title: incidents.isEmpty
                              ? 'No reports yet'
                              : 'No matching reports',
                          message: incidents.isEmpty
                              ? 'Reports you submit while signed in will appear here. Reports submitted anonymously are not linked to your account.'
                              : 'Try another status filter or search term.',
                        );
                      }

                      return RefreshIndicator(
                        color: _green,
                        backgroundColor: _paper,
                        onRefresh: () async {
                          await FirebaseFirestore.instance
                              .collection('incidents')
                              .where('reportedBy', isEqualTo: _user.uid)
                              .get(const GetOptions(source: Source.server));
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 2, 22, 108),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: _rule),
                          itemBuilder: (context, index) =>
                              _IncidentRow(incident: filtered[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        backgroundColor: _alert,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(
          'New Report',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMastheadTitle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAMPUS FIELD GUIDE  /  RECORDS',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Incident history',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) => setState(() => _searchText = value),
      cursorColor: Colors.white,
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search your reports',
        hintStyle: GoogleFonts.spaceGrotesk(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 15,
        ),
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }

  Widget _buildSectionHeader() {
    final scope = _selectedFilter == 'All'
        ? 'ALL REPORTS'
        : _selectedFilter.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '01',
            style: GoogleFonts.spaceGrotesk(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.75,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your reports',
              style: GoogleFonts.spaceGrotesk(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            scope,
            style: GoogleFonts.spaceGrotesk(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.85,
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(Incident incident) {
    final filterMatches =
        _selectedFilter == 'All' || incident.status.label == _selectedFilter;
    if (!filterMatches) return false;

    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return true;

    return incident.title.toLowerCase().contains(query) ||
        incident.description.toLowerCase().contains(query) ||
        incident.location.toLowerCase().contains(query) ||
        incident.id.toLowerCase().contains(query) ||
        incident.status.label.toLowerCase().contains(query);
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border(
                  top: BorderSide(color: _rule),
                  right: BorderSide(color: _rule),
                  bottom: BorderSide(color: _rule),
                  left: BorderSide(color: _rule),
                ),
              ),
              child: Icon(icon, size: 23, color: _muted),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  final Incident incident;

  const _IncidentRow({required this.incident});

  @override
  Widget build(BuildContext context) {
    final dateText = incident.timestampAvailable
        ? DateFormat('MMM d, yyyy · h:mm a').format(incident.timestamp.toLocal())
        : 'Time pending';
    final markerColor = incident.isPanic ? _alert : _green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.75,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        incident.title,
                        style: GoogleFonts.spaceGrotesk(
                          color: incident.isPanic ? _alert : _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusText(status: incident.status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'REF #${incident.id}',
                  style: GoogleFonts.spaceGrotesk(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.75,
                  ),
                ),
                if (incident.description.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    incident.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.42,
                    ),
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: _muted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        incident.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/incident-details',
                      arguments: incident,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                      minimumSize: const Size(48, 38),
                      foregroundColor: _green,
                    ),
                    icon: const Icon(Icons.arrow_outward, size: 16),
                    label: Text(
                      'View details',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
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

class _StatusText extends StatelessWidget {
  final IncidentStatus status;

  const _StatusText({required this.status});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${status.label}',
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: status.color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.65,
        ),
      ),
    );
  }
}
