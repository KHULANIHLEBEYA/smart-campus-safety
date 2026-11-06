import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'incident_history_screen.dart';

const Color _detailPaper = Color(0xFFF7F6F0);
const Color _detailGreen = Color(0xFF0F6E56);
const Color _detailInk = Color(0xFF182522);
const Color _detailMuted = Color(0xFF727B77);
const Color _detailRule = Color(0xFFDFE4DE);
const Color _detailAlert = Color(0xFFD85A30);

class IncidentDetailsScreen extends StatelessWidget {
  final Incident incident;

  const IncidentDetailsScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('EEEE, d MMM yyyy · h:mm a')
        .format(incident.timestamp.toLocal());

    return Scaffold(
      backgroundColor: _detailPaper,
      appBar: AppBar(
        backgroundColor: _detailPaper,
        foregroundColor: _detailGreen,
        surfaceTintColor: _detailPaper,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 22,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INCIDENT DETAILS',
              style: GoogleFonts.spaceGrotesk(
                color: _detailMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Report record',
              style: GoogleFonts.spaceGrotesk(
                color: _detailInk,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _detailRule),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusLabel(status: incident.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'REF #${incident.id}',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.spaceGrotesk(
                      color: _detailMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              incident.title,
              style: GoogleFonts.spaceGrotesk(
                color: _detailInk,
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: _detailRule),
            const SizedBox(height: 22),
            const _SectionHeading(index: '01', title: 'Report overview'),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: incident.location,
            ),
            const Divider(height: 28, color: _detailRule),
            _DetailRow(
              icon: Icons.access_time_outlined,
              label: 'Reported',
              value: timeText,
            ),
            const Divider(height: 28, color: _detailRule),
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Reported by',
              value: incident.reportedBy,
            ),
            const SizedBox(height: 30),
            const _SectionHeading(index: '02', title: 'Description'),
            const SizedBox(height: 14),
            SelectableText(
              incident.description.trim().isEmpty
                  ? 'No description was provided.'
                  : incident.description,
              style: const TextStyle(
                color: _detailInk,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 30),
            const _SafetyNotice(),
          ],
        ),
      ),
    );
  }
}

Color _incidentStatusColor(IncidentStatus status) {
  switch (status) {
    case IncidentStatus.active:
      return const Color(0xFF993C1D);
    case IncidentStatus.done:
      return _detailGreen;
    default:
      return const Color(0xFF854F0B);
  }
}

class _StatusLabel extends StatelessWidget {
  final IncidentStatus status;

  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _incidentStatusColor(status);
    return Semantics(
      label: 'Incident status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.24)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          status.label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String index;
  final String title;

  const _SectionHeading({required this.index, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          index,
          style: GoogleFonts.spaceGrotesk(
            color: _detailGreen,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _detailInk,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _detailGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: _detailMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  color: _detailInk,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: _detailAlert, width: 3),
          top: BorderSide(color: _detailRule),
          right: BorderSide(color: _detailRule),
          bottom: BorderSide(color: _detailRule),
        ),
      ),
      child: const Text(
        'This page shows the report details available in the app. For immediate help, contact campus security through its official emergency channel.',
        style: TextStyle(color: _detailMuted, fontSize: 11, height: 1.45),
      ),
    );
  }
}
