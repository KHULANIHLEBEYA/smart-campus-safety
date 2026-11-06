import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_dashboard_screen.dart';
import 'manage_incidents_screen.dart' as incident_register;
import 'manage_users_screen.dart';

const Color _adminNavPaper = Color(0xFFF7F6F0);
const Color _adminNavGreen = Color(0xFF0F6E56);
const Color _adminNavMuted = Color(0xFF727B77);
const Color _adminNavRule = Color(0xFFDFE4DE);
const Color _adminNavAlert = Color(0xFFD85A30);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  late final Timestamp _monitoringStartedAt;
  late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _incidentSubscription;
  final Set<String> _seenIncidentIds = <String>{};
  final List<_LiveIncidentAlert> _newAlerts = <_LiveIncidentAlert>[];

  static const _screens = <Widget>[
    AdminDashboardScreen(),
    incident_register.ManageIncidentsScreen(),
    ManageUsersScreen(),
  ];

  static const _items = <_AdminNavItem>[
    _AdminNavItem(icon: Icons.dashboard_outlined, label: 'Overview'),
    _AdminNavItem(icon: Icons.fact_check_outlined, label: 'Reports'),
    _AdminNavItem(icon: Icons.people_outline, label: 'People'),
  ];

  @override
  void initState() {
    super.initState();
    _monitoringStartedAt = Timestamp.now();
    _incidentSubscription = FirebaseFirestore.instance
        .collection('incidents')
        .where('createdAt', isGreaterThanOrEqualTo: _monitoringStartedAt)
        .snapshots()
        .listen(
          _handleIncidentSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Admin incident alert listener failed: $error');
          },
        );
  }

  @override
  void dispose() {
    unawaited(_incidentSubscription.cancel());
    super.dispose();
  }

  void _handleIncidentSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final newlyCreated = <_LiveIncidentAlert>[];
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      if (_seenIncidentIds.contains(change.doc.id)) continue;
      final data = change.doc.data();
      if (data == null) continue;
      final createdAt = data['createdAt'];
      if (createdAt is! Timestamp || createdAt.compareTo(_monitoringStartedAt) < 0) {
        if (createdAt is Timestamp) _seenIncidentIds.add(change.doc.id);
        continue;
      }
      _seenIncidentIds.add(change.doc.id);
      newlyCreated.add(_LiveIncidentAlert.fromData(data));
    }

    if (!mounted || newlyCreated.isEmpty) return;
    setState(() {
      _newAlerts.insertAll(0, newlyCreated.reversed);
      if (_newAlerts.length > 8) {
        _newAlerts.removeRange(8, _newAlerts.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminNavPaper,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          if (_newAlerts.isNotEmpty) _liveAlertBanner(),
        ],
      ),
      bottomNavigationBar: _bottomNavigationBar(),
    );
  }

  Widget _liveAlertBanner() {
    final latest = _newAlerts.firstWhere(
      (alert) => alert.isSos,
      orElse: () => _newAlerts.first,
    );
    final count = _newAlerts.length;
    final color = latest.isSos ? _adminNavAlert : _adminNavGreen;
    final heading = latest.isSos
        ? count == 1
            ? 'NEW SOS ALERT'
            : 'SOS ALERT  /  $count NEW REPORTS'
        : count == 1
            ? 'NEW INCIDENT REPORT'
            : '$count NEW INCIDENT REPORTS';

    return Material(
      color: color,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
          child: Row(
            children: [
              Icon(
                latest.isSos ? Icons.warning_amber_rounded : Icons.notifications_active_outlined,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      heading,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${latest.type} · ${latest.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                    _newAlerts.clear();
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text(
                  'VIEW',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss new incident alert',
                onPressed: () => setState(() => _newAlerts.clear()),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _adminNavPaper,
        border: Border(top: BorderSide(color: _adminNavRule)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(child: _navItem(index)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    final item = _items[index];
    final selected = index == _currentIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 21,
                color: selected ? _adminNavGreen : _adminNavMuted,
              ),
              const SizedBox(height: 4),
              Text(
                item.label.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 8,
                  letterSpacing: 0.6,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _adminNavGreen : _adminNavMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final IconData icon;
  final String label;

  const _AdminNavItem({required this.icon, required this.label});
}

class _LiveIncidentAlert {
  final String type;
  final String location;
  final bool isSos;

  const _LiveIncidentAlert({
    required this.type,
    required this.location,
    required this.isSos,
  });

  factory _LiveIncidentAlert.fromData(Map<String, dynamic> data) {
    final rawType = data['type'];
    final type = rawType is String && rawType.trim().isNotEmpty
        ? rawType.trim()
        : 'Incident';
    final rawLocation = data['location'];
    var location = rawLocation is String ? rawLocation.trim() : '';
    final point = data['locationPoint'];
    if (location.isEmpty && point is GeoPoint) {
      location = '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}';
    }
    if (location.isEmpty) location = 'Location unavailable';
    final source = data['source'];
    return _LiveIncidentAlert(
      type: type,
      location: location,
      isSos: source == 'panic_button' || type.toLowerCase() == 'emergency',
    );
  }
}
