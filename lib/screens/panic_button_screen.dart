import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/campus_safety_config.dart';

class PanicScreen extends StatefulWidget {
  const PanicScreen({super.key});

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

enum _PanicStage { idle, confirming, sending, sent }

class _PanicScreenState extends State<PanicScreen>
    with TickerProviderStateMixin {
  _PanicStage _stage = _PanicStage.idle;
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  Timer? _countdownTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _alertStatusSubscription;
  int _secondsElapsed = 0;
  bool _alertResolved = false;
  String? _statusSyncWarning;
  String? _activeAlertId;
  String? _activeAlertRef;
  String? _sendError;
  String? _locationNote;
  Position? _alertPosition;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _alertStatusSubscription?.cancel();
    super.dispose();
  }

  void _startPanicFlow() {
    setState(() {
      _stage = _PanicStage.confirming;
      _sendError = null;
    });
  }

  void _cancelPanic() {
    setState(() {
      _stage = _PanicStage.idle;
      _sendError = null;
    });
  }

  Future<Position?> _tryGetLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationNote = 'Location services are turned off.';
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationNote = 'Location permission is unavailable.';
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      _locationNote = 'Could not get GPS coordinates.';
      return null;
    }
  }

  Future<void> _confirmPanic() async {
    if (_stage == _PanicStage.sending) return;

    setState(() {
      _stage = _PanicStage.sending;
      _sendError = null;
      _locationNote = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be signed in to send an SOS.');
      }

      // Attempt GPS, but still allow the SOS to be saved if GPS is unavailable.
      final position = await _tryGetLocation();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final refNumber = 'SOS-$timestamp';
      final locationText = position == null
          ? 'Location unavailable'
          : 'GPS: ${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}';

      final doc = await FirebaseFirestore.instance.collection('incidents').add({
        'type': 'Emergency',
        'description': 'SOS emergency alert from the panic button.',
        'source': 'panic_button',
        'isAnonymous': false,
        'reportedBy': user.uid,
        'status': 'Active',
        'refNumber': refNumber,
        'location': locationText,
        'locationPoint': position == null
            ? null
            : GeoPoint(position.latitude, position.longitude),
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'locationAccuracyMeters': position?.accuracy,
        'locationAvailable': position != null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _activeAlertId = doc.id;
      _activeAlertRef = refNumber;
      _alertPosition = position;
      _secondsElapsed = 0;
      _alertResolved = false;
      _statusSyncWarning = null;
      setState(() => _stage = _PanicStage.sent);
      _watchAlertStatus(doc.id);

      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _secondsElapsed++);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _PanicStage.confirming;
        _sendError =
            'Could not save the SOS. Check your connection and sign-in, then try again.';
      });
    }
  }


  void _watchAlertStatus(String incidentId) {
    _alertStatusSubscription?.cancel();
    _alertStatusSubscription = FirebaseFirestore.instance
        .collection('incidents')
        .doc(incidentId)
        .snapshots()
        .listen(
      (snapshot) {
        final status = snapshot.data()?['status']
            ?.toString()
            .trim()
            .toLowerCase();
        if (status == 'resolved' && !_alertResolved) {
          _countdownTimer?.cancel();
          _countdownTimer = null;
          if (!mounted) return;
          setState(() => _alertResolved = true);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('SOS status listener failed: $error');
        if (!mounted) return;
        setState(() {
          _statusSyncWarning =
              'Could not sync status with staff. Check your connection.';
        });
      },
    );
  }

  Future<void> _cancelAlert() async {
    final alertId = _activeAlertId;
    if (alertId == null) {
      setState(() => _stage = _PanicStage.idle);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(alertId)
          .update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      final statusSubscription = _alertStatusSubscription;
      _alertStatusSubscription = null;
      await statusSubscription?.cancel();
      if (!mounted) return;
      _activeAlertId = null;
      _activeAlertRef = null;
      _alertPosition = null;
      _alertResolved = false;
      _statusSyncWarning = null;
      setState(() => _stage = _PanicStage.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F6E56),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Alert marked as cancelled.',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update the alert. Contact campus security directly.',
          ),
        ),
      );
    }
  }

  String? get _normalizedSecurityNumber {
    final number = CampusSafetyConfig.securityPhoneNumber.trim();
    if (number.isEmpty) return null;
    // Keep only dialable number characters and validate an international
    // phone number before building a tel:/sms: URI.
    final normalized = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) return null;
    return normalized;
  }

  String _buildSosMessage() {
    final ref = _activeAlertRef ?? _activeAlertId ?? 'not available';
    final position = _alertPosition;
    final location = position == null
        ? 'GPS location unavailable.'
        : 'Location: https://maps.google.com/?q='
            '${position.latitude},${position.longitude}';
    return 'SOS from Smart Campus Safety. Reference: $ref. $location '
        'Please contact me / dispatch campus assistance.';
  }

  Future<void> _launchSecurityAction(Uri uri, String failureMessage) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _callCampusSecurity() async {
    final number = _normalizedSecurityNumber;
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add the official campus security number in panic_button_screen.dart. '
            'For immediate danger, use your local emergency number.',
          ),
        ),
      );
      return;
    }
    await _launchSecurityAction(
      Uri(scheme: 'tel', path: number),
      'Could not open the phone dialer. Call campus security directly.',
    );
  }

  Future<void> _textCampusSecurity() async {
    final number = _normalizedSecurityNumber;
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add the official campus security number in panic_button_screen.dart. '
            'For immediate danger, use your local emergency number.',
          ),
        ),
      );
      return;
    }
    final uri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{'body': _buildSosMessage()},
    );
    await _launchSecurityAction(
      uri,
      'Could not open your messaging app. Contact campus security directly.',
    );
  }

  String get _formattedTime {
    final mins = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04342C),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStageContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70, size: 24),
          ),
          Text(
            'Emergency',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _PanicStage.idle:
        return _buildIdleStage();
      case _PanicStage.confirming:
        return _buildConfirmingStage();
      case _PanicStage.sending:
        return _buildSendingStage();
      case _PanicStage.sent:
        return _buildSentStage();
    }
  }

  Widget _buildIdleStage() {
    return Center(
      key: const ValueKey('idle'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'In an emergency?',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap SOS below to save an emergency alert\nto the campus safety incident records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 56),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _pulse.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD85A30).withOpacity(0.12),
                        ),
                      ),
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD85A30).withOpacity(0.18),
                      ),
                    ),
                    GestureDetector(
                      onTap: _startPanicFlow,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD85A30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD85A30).withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.white, size: 42),
                            const SizedBox(height: 6),
                            Text(
                              'SOS',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),
            _buildInfoRow(Icons.gps_fixed, 'GPS is included if permission is available'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.cloud_upload_outlined, 'SOS is saved to incident records'),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.notifications_active_outlined, 'Live alert appears on the staff dashboard'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmingStage() {
    return Center(
      key: const ValueKey('confirming'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD85A30).withOpacity(0.15),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD85A30), size: 50),
            ),
            const SizedBox(height: 28),
            Text(
              'Send emergency alert?',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The SOS will be saved to incident records and appear as a live in-app alert on the staff dashboard while staff are signed in and online. It does not send SMS or push notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            if (_sendError != null) ...[
              const SizedBox(height: 12),
              Text(
                _sendError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFB4A2),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _cancelPanic,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _confirmPanic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD85A30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Send Alert',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendingStage() {
    return Center(
      key: const ValueKey('sending'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFD85A30),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sending alert...',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Capturing GPS location',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSentStage() {
    return Center(
      key: const ValueKey('sent'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1D9E75),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 46),
            ),
            const SizedBox(height: 24),
            Text(
              'SOS saved successfully',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _alertPosition != null
                  ? 'Your SOS and GPS are saved. A live in-app alert is available on the staff dashboard while staff are signed in and online. For phone contact, use Call Security or Text Security below; your phone will ask you to confirm.'
                  : '${_locationNote ?? 'GPS coordinates were unavailable.'} Your SOS was saved without GPS. A live in-app alert is available on the staff dashboard while staff are signed in and online. Use Call Security or Text Security below; your phone will ask you to confirm.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Text(
                    _alertResolved ? 'Elapsed time at resolution' : 'Time since alert',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedTime,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusSyncWarning ??
                        (_alertResolved
                            ? 'Timer stopped when staff resolved the alert'
                            : 'Timer stops when staff mark this alert resolved'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: _statusSyncWarning == null
                          ? Colors.white.withOpacity(0.45)
                          : const Color(0xFFFFD6C9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _callCampusSecurity,
                      icon: const Icon(Icons.phone_outlined,
                          size: 17, color: Colors.white70),
                      label: const Text('Call Security',
                          style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _textCampusSecurity,
                      icon: const Icon(Icons.sms_outlined,
                          size: 17, color: Colors.white70),
                      label: const Text('Text Security',
                          style: TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: _alertResolved ? null : _cancelAlert,
                child: Text(
                  _alertResolved ? 'Alert Resolved by Staff' : 'Mark Alert Cancelled',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}