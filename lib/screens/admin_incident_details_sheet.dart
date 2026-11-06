import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _detailPaper = Color(0xFFF7F6F0);
const Color _detailGreen = Color(0xFF0F6E56);
const Color _detailInk = Color(0xFF182522);
const Color _detailMuted = Color(0xFF727B77);
const Color _detailRule = Color(0xFFDFE4DE);
const Color _detailAlert = Color(0xFFD85A30);

class AdminIncidentDetailsData {
  final String documentId;
  final String refNumber;
  final String type;
  final String description;
  final String location;
  final String status;
  final String reporterUid;
  final String source;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;
  final bool isAnonymous;
  final bool isSos;

  const AdminIncidentDetailsData({
    required this.documentId,
    required this.refNumber,
    required this.type,
    required this.description,
    required this.location,
    required this.status,
    required this.reporterUid,
    required this.source,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.isAnonymous,
    required this.isSos,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinateText => hasCoordinates
      ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
      : '';

  String get formattedTime => createdAt == null
      ? 'Time unavailable'
      : DateFormat('EEEE, d MMM yyyy · h:mm a').format(createdAt!.toLocal());

  String get copyText {
    final lines = <String>[
      isSos ? 'SOS EMERGENCY' : 'INCIDENT REPORT',
      'Type: $type',
      'Reference: $refNumber',
      'Status: $status',
      'Reported: $formattedTime',
      'Location: $location',
      if (hasCoordinates) 'Coordinates: $coordinateText',
      if (description.isNotEmpty) 'Description: $description',
      if (isAnonymous) 'Reporter: Anonymous',
      if (!isAnonymous && reporterUid.isNotEmpty) 'Reporter UID: $reporterUid',
      if (source.isNotEmpty) 'Source: $source',
      'Firestore document: $documentId',
    ];
    return lines.join('\n');
  }

  factory AdminIncidentDetailsData.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    String stringValue(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value.trim() : fallback;
    }

    double? numberValue(Object? value) {
      if (value is! num) return null;
      final number = value.toDouble();
      return number.isFinite ? number : null;
    }

    final typeRaw = stringValue('type', 'Incident');
    final type = typeRaw.isEmpty ? 'Incident' : typeRaw;
    final point = data['locationPoint'];
    final latitude = numberValue(data['latitude']) ??
        (point is GeoPoint ? point.latitude : null);
    final longitude = numberValue(data['longitude']) ??
        (point is GeoPoint ? point.longitude : null);
    final rawLocation = stringValue('location');
    final location = rawLocation.isNotEmpty
        ? rawLocation
        : latitude != null && longitude != null
            ? 'GPS coordinates'
            : 'Location unavailable';
    final createdValue = data['createdAt'];
    final updatedValue = data['updatedAt'];
    final createdAt = createdValue is Timestamp
        ? createdValue.toDate()
        : updatedValue is Timestamp
            ? updatedValue.toDate()
            : null;
    final rawRef = stringValue('refNumber');
    final source = stringValue('source');
    final anonymous = data['isAnonymous'] == true;
    final reporterUid = stringValue('reportedBy');

    return AdminIncidentDetailsData(
      documentId: documentId,
      refNumber: rawRef.isEmpty ? documentId : rawRef,
      type: type,
      description: stringValue('description'),
      location: location,
      status: _prettyStatus(stringValue('status', 'Active')),
      reporterUid: reporterUid,
      source: source,
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
      isAnonymous: anonymous,
      isSos: source == 'panic_button' || type.toLowerCase() == 'emergency',
    );
  }
}

String _prettyStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll('_', ' ');
  if (normalized.isEmpty) return 'Unknown';
  if (normalized == 'in progress') return 'In Progress';
  if (normalized == 'active' || normalized == 'open') return 'Pending';
  return normalized.split(' ').map((word) {
    if (word.isEmpty) return word;
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }).join(' ');
}

Future<void> showAdminIncidentDetails(
  BuildContext context,
  AdminIncidentDetailsData incident,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: _detailPaper,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.82;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            children: [
              Row(
                children: [
                  Icon(
                    incident.isSos ? Icons.warning_amber_rounded : Icons.circle,
                    color: incident.isSos ? _detailAlert : _detailGreen,
                    size: incident.isSos ? 21 : 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      incident.isSos ? 'SOS EMERGENCY' : 'INCIDENT REPORT',
                      style: const TextStyle(
                        color: _detailGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy all report details',
                    onPressed: () => _copyToClipboard(
                      sheetContext,
                      incident.copyText,
                      'Report details copied',
                    ),
                    icon: const Icon(Icons.copy_all_outlined, color: _detailGreen),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                incident.type,
                style: const TextStyle(
                  color: _detailInk,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                'REF ${incident.refNumber}',
                style: const TextStyle(
                  color: _detailMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _detailRule),
              _detailRow('STATUS', incident.status),
              _detailRow('REPORTED', incident.formattedTime),
              _detailRow('LOCATION', incident.location),
              if (incident.hasCoordinates)
                _coordinateRow(sheetContext, incident),
              if (incident.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: _DetailLabel('DESCRIPTION')),
                    IconButton(
                      tooltip: 'Copy description',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyToClipboard(
                        sheetContext,
                        incident.description,
                        'Description copied',
                      ),
                      icon: const Icon(Icons.copy_outlined, size: 17, color: _detailGreen),
                    ),
                  ],
                ),
                SelectableText(
                  incident.description,
                  style: const TextStyle(color: _detailInk, fontSize: 13, height: 1.5),
                ),
              ],
              const SizedBox(height: 12),
              _detailRow(
                'REPORTED BY',
                incident.isAnonymous
                    ? 'Anonymous'
                    : incident.reporterUid.isEmpty
                        ? 'Reporter ID unavailable'
                        : incident.reporterUid,
              ),
              if (incident.source.isNotEmpty)
                _detailRow('SOURCE', incident.source),
              const SizedBox(height: 12),
              if (incident.hasCoordinates)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMap(sheetContext, incident),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open location in Google Maps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _detailGreen,
                      side: const BorderSide(color: _detailGreen),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No GPS coordinates were saved for this report, so a map location cannot be opened.',
                    style: TextStyle(color: _detailMuted, fontSize: 11, height: 1.4),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailLabel(label),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(color: _detailInk, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

Widget _coordinateRow(
  BuildContext context,
  AdminIncidentDetailsData incident,
) {
  return Padding(
    padding: const EdgeInsets.only(top: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailLabel('GPS COORDINATES'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _openMap(context, incident),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          incident.coordinateText,
                          style: const TextStyle(
                            color: _detailGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 15, color: _detailGreen),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy coordinates',
              onPressed: () => _copyToClipboard(
                context,
                incident.coordinateText,
                'Coordinates copied',
              ),
              icon: const Icon(Icons.copy_outlined, size: 17, color: _detailGreen),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DetailLabel extends StatelessWidget {
  final String text;
  const _DetailLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _detailMuted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}

Future<void> _copyToClipboard(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(confirmation),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<void> _openMap(
  BuildContext context,
  AdminIncidentDetailsData incident,
) async {
  if (!incident.hasCoordinates) return;
  final uri = Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query': '${incident.latitude},${incident.longitude}',
    },
  );
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app on this device.')),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the map. Check your internet connection.')),
    );
  }
}
