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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final User? _user;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationStream;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    final uid = _user?.uid;
    _notificationStream = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUid', isEqualTo: uid)
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
          'SMARTSAFE  /  ALERTS',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.15,
          ),
        ),
        actions: [
          _markAllReadAction(),
          const SizedBox(width: 10),
        ],
      ),
      body: _user == null || _notificationStream == null
          ? _stateNotice(
              icon: Icons.lock_outline,
              title: 'Sign in to view alerts.',
              body: 'Campus updates addressed to you will appear here.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _notificationStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _stateNotice(
                    icon: Icons.cloud_off_outlined,
                    title: 'Alerts could not load.',
                    body:
                        'Check your connection and Firestore rules. You can only read notices addressed to your account.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                final alerts = (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(_FieldGuideNotification.fromDocument)
                    .toList()
                  ..sort((a, b) {
                    final aTime = a.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bTime = b.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bTime.compareTo(aTime);
                  });
                final unreadCount = alerts.where((alert) => !alert.isRead).length;

                if (alerts.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
                    children: [
                      _intro(0),
                      const SizedBox(height: 26),
                      const _InlineNotice(
                        text: 'No alerts yet. Campus notices and updates addressed to your account will appear here.',
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1, color: _rule),
                      const SizedBox(height: 12),
                      const _InlineNotice(
                        text: 'Alerts are read from Firestore. A trusted staff tool or server process must create notification documents.',
                      ),
                    ],
                  );
                }

                final grouped = _groupAlerts(alerts);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
                  children: [
                    _intro(unreadCount),
                    const SizedBox(height: 26),
                    for (final group in grouped.entries) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.key.toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                color: _green,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          Text(
                            group.value.length.toString().padLeft(2, '0'),
                            style: GoogleFonts.spaceGrotesk(
                              color: _muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: _rule),
                      for (final alert in group.value)
                        _AlertRow(
                          alert: alert,
                          onTap: () => _openAlert(alert),
                        ),
                      const SizedBox(height: 22),
                    ],
                    const _InlineNotice(
                      text: 'Alerts are loaded from Firestore. Delivery requires a trusted app or server process to create notification documents.',
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _markAllReadAction() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final hasUnread = docs.any((doc) => doc.data()['isRead'] != true);
        if (!hasUnread) return const SizedBox.shrink();
        return TextButton(
          onPressed: _markingAllRead || !snapshot.hasData
              ? null
              : () => _markAllRead(docs),
          style: TextButton.styleFrom(
            foregroundColor: _green,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: _markingAllRead
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              : const Text(
                  'MARK READ',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                ),
        );
      },
    );
  }

  Widget _intro(int unreadCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Campus\nupdates.',
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 34,
            height: 1.02,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: unreadCount > 0 ? _alert : _green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                unreadCount == 0
                    ? 'You are up to date.'
                    : '$unreadCount unread ${unreadCount == 1 ? 'notice' : 'notices'}',
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
      ],
    );
  }

  Map<String, List<_FieldGuideNotification>> _groupAlerts(
    List<_FieldGuideNotification> alerts,
  ) {
    final result = <String, List<_FieldGuideNotification>>{};
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    for (final alert in alerts) {
      final date = alert.createdAt?.toLocal();
      final label = date == null
          ? 'Earlier'
          : DateUtils.dateOnly(date) == today
              ? 'Today'
              : DateUtils.dateOnly(date) == yesterday
                  ? 'Yesterday'
                  : DateFormat('MMMM d, yyyy').format(date);
      result.putIfAbsent(label, () => <_FieldGuideNotification>[]).add(alert);
    }
    return result;
  }

  Future<void> _openAlert(_FieldGuideNotification alert) async {
    if (!alert.isRead) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(alert.id)
            .update({'isRead': true});
      } catch (_) {
        if (mounted) _showMessage('Could not mark this alert as read.');
      }
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _paper,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.typeLabel.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: alert.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                alert.title,
                style: GoogleFonts.spaceGrotesk(
                  color: _ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                alert.body,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _rule),
              const SizedBox(height: 10),
              Text(
                alert.timeLabel,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final unread = documents.where((doc) => doc.data()['isRead'] != true).toList();
    if (unread.isEmpty) return;
    setState(() => _markingAllRead = true);
    try {
      for (var start = 0; start < unread.length; start += 450) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (start + 450 < unread.length) ? start + 450 : unread.length;
        for (final doc in unread.sublist(start, end)) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
      if (mounted) _showMessage('All alerts marked as read.');
    } catch (_) {
      if (mounted) {
        _showMessage('Could not update all alerts. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
      ),
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

class _FieldGuideNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime? createdAt;
  final bool isRead;

  const _FieldGuideNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory _FieldGuideNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawCreatedAt = data['createdAt'];
    final rawTitle = data['title'];
    final rawBody = data['body'] ?? data['message'];
    final rawType = data['type'];
    return _FieldGuideNotification(
      id: document.id,
      title: rawTitle is String && rawTitle.trim().isNotEmpty
          ? rawTitle.trim()
          : 'Campus update',
      body: rawBody is String && rawBody.trim().isNotEmpty
          ? rawBody.trim()
          : 'No additional details were provided.',
      type: rawType is String ? rawType.trim().toLowerCase() : '',
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : null,
      isRead: data['isRead'] == true,
    );
  }

  String get typeLabel {
    if (type.isNotEmpty) return type.replaceAll('_', ' ');
    final titleLower = title.toLowerCase();
    if (titleLower.contains('emergency') || titleLower.contains('sos')) {
      return 'Emergency notice';
    }
    return 'Campus notice';
  }

  Color get color {
    final label = '$type $title'.toLowerCase();
    if (label.contains('emergency') || label.contains('sos') || label.contains('panic')) {
      return _alert;
    }
    if (label.contains('resolved') || label.contains('patrol')) return _green;
    return const Color(0xFF185FA5);
  }

  String get timeLabel => createdAt == null
      ? 'Time unavailable'
      : DateFormat('EEEE, d MMMM yyyy · h:mm a').format(createdAt!.toLocal());
}

class _AlertRow extends StatelessWidget {
  final _FieldGuideNotification alert;
  final VoidCallback onTap;

  const _AlertRow({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time = alert.createdAt == null
        ? 'TIME UNAVAILABLE'
        : DateFormat('h:mm a').format(alert.createdAt!.toLocal()).toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _rule)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 4, right: 11),
              decoration: BoxDecoration(
                color: alert.isRead ? _rule : _alert,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: alert.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.spaceGrotesk(
                          color: _muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    alert.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.typeLabel.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: alert.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String text;

  const _InlineNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: _muted, fontSize: 12, height: 1.45),
    );
  }
}
