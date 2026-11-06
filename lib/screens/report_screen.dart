
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _reportPaper = Color(0xFFF7F6F0);
const Color _reportGreen = Color(0xFF0F6E56);
const Color _reportInk = Color(0xFF182522);
const Color _reportMuted = Color(0xFF727B77);
const Color _reportRule = Color(0xFFDFE4DE);
const Color _reportAlert = Color(0xFFD85A30);

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _selectedType = 0;
  bool _isAnonymous = true;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  final TextEditingController _descriptionController = TextEditingController();

  Position? _position;
  Future<Position?>? _locationRequest;
  String _locationStatus = 'Getting GPS location…';

  final List<_IncidentType> _types = const [
    _IncidentType(icon: Icons.lock_outline, label: 'Theft'),
    _IncidentType(icon: Icons.warning_amber_outlined, label: 'Assault'),
    _IncidentType(icon: Icons.local_fire_department_outlined, label: 'Fire'),
    _IncidentType(icon: Icons.remove_red_eye_outlined, label: 'Suspicious'),
    _IncidentType(icon: Icons.medical_services_outlined, label: 'Medical'),
    _IncidentType(icon: Icons.more_horiz, label: 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_captureLocation());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<Position?> _captureLocation() async {
    if (!mounted) return _position;

    // Share an in-flight GPS request instead of starting another one. This is
    // important when the user submits while the initial location lookup runs.
    final pending = _locationRequest;
    if (pending != null) return pending;

    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Getting GPS location…';
    });

    final request = _performLocationCapture();
    _locationRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_locationRequest, request)) {
        _locationRequest = null;
      }
    }
  }

  Future<Position?> _performLocationCapture() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Turn on location services, then tap to retry.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied. Tap to try again.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Allow location in your phone settings, then tap to retry.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return null;
      setState(() {
        _position = position;
        _locationStatus = 'GPS location captured';
        _isGettingLocation = false;
      });
      return position;
    } catch (error) {
      if (!mounted) return null;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _position = null;
        _locationStatus = message.contains('TimeoutException')
            ? 'Could not get GPS in time. Tap to retry.'
            : message;
        _isGettingLocation = false;
      });
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (_descriptionController.text.trim().isEmpty) {
      _showNotice('Please add a description.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showNotice('Sign in before submitting an incident report.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // Await the current GPS lookup if it is already running. If no lookup is
    // active, request one now. Do not submit a report without coordinates.
    final position = _position ?? await (_locationRequest ?? _captureLocation());
    if (!mounted) return;
    if (position == null) {
      setState(() => _isSubmitting = false);
      _showNotice(
        'Report not sent because GPS is unavailable. Enable location access '
        'and services, then tap the location row to retry.',
        isError: true,
      );
      return;
    }

    try {
      final incidentCollection =
          FirebaseFirestore.instance.collection('incidents');
      final refNumber = 'INC-${incidentCollection.doc().id}';
      final incidentReference = incidentCollection.doc(refNumber);
      final locationText =
          'GPS: ${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';

      await incidentReference.set({
        'type': _types[_selectedType].label,
        'description': _descriptionController.text.trim(),
        'isAnonymous': _isAnonymous,
        'reportedBy': _isAnonymous ? null : user.uid,
        'status': 'Active',
        'refNumber': refNumber,
        'location': locationText,
        'locationPoint': GeoPoint(position.latitude, position.longitude),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationAccuracyMeters': position.accuracy,
        'locationAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSuccessDialog(refNumber, hasLocation: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final message = error is FirebaseException
          ? 'Report not saved (${error.code}). Check your Firestore rules.'
          : 'Report not saved. Check your connection and try again.';
      _showNotice(message, isError: true);
    }
  }

  void _showNotice(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _reportAlert : _reportGreen,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
  }

  void _showSuccessDialog(String refNumber, {required bool hasLocation}) {
    final reportMessage = hasLocation
        ? 'Your incident report and GPS location were saved.'
        : 'Your incident report was saved, but GPS was unavailable.';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _reportPaper,
        surfaceTintColor: _reportPaper,
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: _reportGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Report submitted',
                style: GoogleFonts.spaceGrotesk(
                  color: _reportInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reportMessage,
              style: const TextStyle(color: _reportInk, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              'This app does not yet send automatic notifications to security.',
              style: const TextStyle(color: _reportMuted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            Text(
              'REFERENCE  /  $refNumber',
              style: GoogleFonts.spaceGrotesk(
                color: _reportGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              _descriptionController.clear();
              setState(() {
                _selectedType = 0;
                _isAnonymous = true;
                _position = null;
                _locationStatus = 'Getting GPS location…';
              });
              _captureLocation();
            },
            style: TextButton.styleFrom(foregroundColor: _reportGreen),
            child: Text(
              'Done',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _reportPaper,
      body: Column(
        children: [
          _buildMasthead(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIncidentTypes(),
                  const SizedBox(height: 27),
                  _buildDescription(),
                  const SizedBox(height: 27),
                  _buildLocationRow(),
                  const SizedBox(height: 22),
                  _buildAnonymousToggle(),
                  const SizedBox(height: 25),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  const Text(
                    'Reports are saved with a written description and GPS location. Automatic security notifications are not enabled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _reportMuted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasthead() {
    return Container(
      width: double.infinity,
      color: _reportGreen,
      padding: EdgeInsets.fromLTRB(
        22,
        MediaQuery.of(context).padding.top + 15,
        22,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CAMPUS FIELD GUIDE  /  REPORT',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Report an incident',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Share what happened so it can be recorded.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String number, String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            number,
            style: GoogleFonts.spaceGrotesk(
              color: _reportGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.75,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: _reportInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: GoogleFonts.spaceGrotesk(
                color: _reportMuted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentTypes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('01', 'Incident type', trailing: 'SELECT ONE'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 14) / 2;
            return Wrap(
              spacing: 14,
              children: _types.asMap().entries.map((entry) {
                final index = entry.key;
                final type = entry.value;
                final selected = _selectedType == index;
                return SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: () => setState(() => _selectedType = index),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _reportRule)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            type.icon,
                            size: 18,
                            color: selected ? _reportGreen : _reportMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? _reportInk : _reportMuted,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: selected ? _reportGreen : _reportRule,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('02', 'Description', trailing: 'REQUIRED'),
        TextField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: _reportInk, fontSize: 14, height: 1.45),
          decoration: InputDecoration(
            hintText: 'Describe what happened, when, and where…',
            hintStyle: const TextStyle(color: _reportMuted, fontSize: 13),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: _reportRule),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _reportRule),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _reportGreen, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    final position = _position;
    final title = _isGettingLocation
        ? 'Getting GPS location…'
        : position != null
            ? 'GPS location captured'
            : 'GPS location unavailable';
    final detail = position == null
        ? _locationStatus
        : '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}  ·  '
            '±${position.accuracy.toStringAsFixed(0)} m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('03', 'Location', trailing: 'GPS'),
        InkWell(
          onTap: _isGettingLocation ? null : _captureLocation,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Icon(
                  position == null
                      ? Icons.location_searching
                      : Icons.gps_fixed,
                  color: position == null ? _reportAlert : _reportGreen,
                  size: 20,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          color: _reportInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _reportMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_isGettingLocation)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _reportGreen,
                    ),
                  )
                else
                  Text(
                    'RETRY',
                    style: GoogleFonts.spaceGrotesk(
                      color: _reportGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: _reportRule),
      ],
    );
  }

  Widget _buildAnonymousToggle() {
    return Row(
      children: [
        const Icon(Icons.visibility_off_outlined, color: _reportMuted, size: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit anonymously',
                style: GoogleFonts.spaceGrotesk(
                  color: _reportInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Your identity will not be attached to this report.',
                style: TextStyle(color: _reportMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _isAnonymous,
          activeTrackColor: _reportGreen,
          onChanged: (value) => setState(() => _isAnonymous = value),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _handleSubmit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_outlined, size: 17),
        label: Text(
          _isSubmitting ? 'Submitting…' : 'Submit report',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _reportGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _reportGreen.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

}

class _IncidentType {
  final IconData icon;
  final String label;

  const _IncidentType({required this.icon, required this.label});
}
