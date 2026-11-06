import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _zonesPaper = Color(0xFFF7F6F0);
const Color _zonesGreen = Color(0xFF0F6E56);
const Color _zonesInk = Color(0xFF182522);
const Color _zonesMuted = Color(0xFF727B77);
const Color _zonesRule = Color(0xFFDFE4DE);
const Color _zonesAlert = Color(0xFFD85A30);

class SafeZonesScreen extends StatelessWidget {
  const SafeZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _zonesPaper,
      appBar: AppBar(
        backgroundColor: _zonesGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: _zonesGreen,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CAMPUS FIELD GUIDE  /  02',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Safe zones',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('safe_zones').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load safe zones',
              message:
                  'Check your connection and Firestore rules, then try again.',
              iconColor: _zonesAlert,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingState();
          }

          final zones = (snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              .where((doc) => doc.data()['isActive'] != false)
              .map(_SafeZone.fromDocument)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (zones.isEmpty) {
            return _buildMessage(
              icon: Icons.location_on_outlined,
              title: 'No safe zones configured yet',
              message:
                  'Campus staff must add verified locations to the safe_zones Firestore collection before they appear here.',
              iconColor: _zonesGreen,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            itemCount: zones.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _ZonesIntroduction();
              }

              return _SafeZoneRow(
                zone: zones[index - 1],
                number: index.toString().padLeft(2, '0'),
                isLast: index == zones.length,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    required Color iconColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _zonesRule),
              ),
              child: Icon(icon, size: 26, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _zonesInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _zonesMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              color: _zonesGreen,
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading safe zones…',
            style: TextStyle(
              color: _zonesMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonesIntroduction extends StatelessWidget {
  const _ZonesIntroduction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERIFIED CAMPUS LOCATIONS',
            style: GoogleFonts.spaceGrotesk(
              color: _zonesGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Find a safe point.',
            style: GoogleFonts.spaceGrotesk(
              color: _zonesInk,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Open a location in Maps when coordinates are available.',
            style: TextStyle(
              color: _zonesMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 21),
          const Divider(height: 1, color: _zonesRule),
        ],
      ),
    );
  }
}

class _SafeZone {
  final String name;
  final String description;
  final double? latitude;
  final double? longitude;

  const _SafeZone({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory _SafeZone.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawName = data['name'];
    final rawDescription = data['description'];
    final rawLatitude = data['latitude'];
    final rawLongitude = data['longitude'];

    return _SafeZone(
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : document.id,
      description: rawDescription is String ? rawDescription.trim() : '',
      latitude: rawLatitude is num ? rawLatitude.toDouble() : null,
      longitude: rawLongitude is num ? rawLongitude.toDouble() : null,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}

class _SafeZoneRow extends StatelessWidget {
  final _SafeZone zone;
  final String number;
  final bool isLast;

  const _SafeZoneRow({
    required this.zone,
    required this.number,
    required this.isLast,
  });

  Future<void> _openMap(BuildContext context) async {
    final latitude = zone.latitude;
    final longitude = zone.longitude;
    if (latitude == null || longitude == null) return;

    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '$latitude,$longitude',
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps application.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = zone.hasCoordinates
        ? '${zone.latitude!.toStringAsFixed(6)}, ${zone.longitude!.toStringAsFixed(6)}'
        : null;

    return Semantics(
      container: true,
      label: '${zone.name} safe zone',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: _zonesRule)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 29,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      number,
                      style: GoogleFonts.spaceGrotesk(
                        color: _zonesMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const Icon(
                  Icons.place_outlined,
                  color: _zonesGreen,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    zone.name,
                    style: GoogleFonts.spaceGrotesk(
                      color: _zonesInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (zone.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 61),
                child: Text(
                  zone.description,
                  style: const TextStyle(
                    color: _zonesMuted,
                    fontSize: 13,
                    height: 1.42,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 13),
            Padding(
              padding: const EdgeInsets.only(left: 61),
              child: coordinates == null
                  ? const Text(
                      'Coordinates have not been added yet.',
                      style: TextStyle(color: _zonesMuted, fontSize: 12),
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.gps_fixed,
                          size: 15,
                          color: _zonesMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            coordinates,
                            style: const TextStyle(
                              color: _zonesMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (zone.hasCoordinates) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 53),
                child: TextButton.icon(
                  onPressed: () => _openMap(context),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open in Maps'),
                  style: TextButton.styleFrom(
                    foregroundColor: _zonesGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 44),
                    textStyle: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
