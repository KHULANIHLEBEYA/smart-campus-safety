import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color _usersPaper = Color(0xFFF7F6F0);
const Color _usersGreen = Color(0xFF0F6E56);
const Color _usersInk = Color(0xFF182522);
const Color _usersMuted = Color(0xFF727B77);
const Color _usersRule = Color(0xFFDFE4DE);

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _searchController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _userStream;
  String _query = '';
  _UserRoleFilter _filter = _UserRoleFilter.all;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _usersPaper,
      body: Column(
        children: [
          _masthead(context),
          _searchField(),
          _roleFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    icon: Icons.cloud_off_outlined,
                    title: 'Directory unavailable',
                    detail: 'Check your connection and staff Firestore access.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _usersGreen));
                }
                final users = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .map(_CampusUser.fromDocument)
                    .toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                final filtered = users.where(_matches).toList();
                if (filtered.isEmpty) {
                  return _message(
                    icon: users.isEmpty ? Icons.people_outline : Icons.search_off_outlined,
                    title: users.isEmpty ? 'No profiles yet' : 'No matching profiles',
                    detail: users.isEmpty
                        ? 'Registered student and staff profiles will appear here.'
                        : 'Try a different name, email, ID, or role filter.',
                  );
                }
                return RefreshIndicator(
                  color: _usersGreen,
                  onRefresh: () async { await FirebaseFirestore.instance.collection('users').get(); },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          '${filtered.length} PROFILE${filtered.length == 1 ? '' : 'S'}',
                          style: GoogleFonts.spaceGrotesk(color: _usersMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                      ),
                      ...filtered.map(_userRow),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(_CampusUser user) {
    if (_filter != _UserRoleFilter.all && user.role != _filter.role) return false;
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return user.name.toLowerCase().contains(q) ||
        user.email.toLowerCase().contains(q) ||
        user.identifier.toLowerCase().contains(q) ||
        user.faculty.toLowerCase().contains(q);
  }

  Widget _masthead(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _usersGreen,
      padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 16, 22, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SMARTSAFE  /  CAMPUS DIRECTORY', style: GoogleFonts.spaceGrotesk(color: Colors.white.withValues(alpha: 0.76), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 14),
          Text('People on campus.', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
          const SizedBox(height: 5),
          const Text('Directory profiles from the live user register.', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 17, 22, 5),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: const TextStyle(color: _usersInk, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search name, email, ID, faculty…',
          hintStyle: const TextStyle(color: _usersMuted, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: _usersGreen, size: 20),
          suffixIcon: _query.isEmpty ? null : IconButton(
            tooltip: 'Clear search',
            onPressed: () { _searchController.clear(); setState(() => _query = ''); },
            icon: const Icon(Icons.close, size: 18, color: _usersMuted),
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: _usersRule)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _usersRule)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _usersGreen, width: 1.5)),
        ),
      ),
    );
  }

  Widget _roleFilters() {
    final filters = _UserRoleFilter.values;
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
              child: Text(filter.label.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                color: selected ? _usersGreen : _usersMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _userRow(_CampusUser user) {
    final joined = user.createdAt == null
        ? 'Registered date unavailable'
        : 'Joined ${DateFormat('d MMM yyyy').format(user.createdAt!.toLocal())}';
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _usersRule))),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _usersGreen.withValues(alpha: 0.09), shape: BoxShape.circle),
            child: Text(user.initials, style: GoogleFonts.spaceGrotesk(color: _usersGreen, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(color: _usersInk, fontSize: 13, fontWeight: FontWeight.w700)),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _usersMuted, fontSize: 11)),
                ],
                const SizedBox(height: 5),
                Text(
                  [user.roleLabel, if (user.identifier.isNotEmpty) user.identifier, if (user.faculty.isNotEmpty) user.faculty, joined].join('  /  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(color: _usersMuted, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message({required IconData icon, required String title, required String detail}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: _usersMuted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _usersInk, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _usersMuted, height: 1.4)),
        ]),
      ),
    );
  }
}

enum _UserRoleFilter { all, student, staff, security, admin }

extension on _UserRoleFilter {
  String get label => switch (this) {
        _UserRoleFilter.all => 'All',
        _UserRoleFilter.student => 'Students',
        _UserRoleFilter.staff => 'Staff',
        _UserRoleFilter.security => 'Security',
        _UserRoleFilter.admin => 'Admins',
      };

  String get role => switch (this) {
        _UserRoleFilter.all => '',
        _UserRoleFilter.student => 'student',
        _UserRoleFilter.staff => 'staff',
        _UserRoleFilter.security => 'security',
        _UserRoleFilter.admin => 'admin',
      };
}

class _CampusUser {
  final String name;
  final String email;
  final String identifier;
  final String faculty;
  final String role;
  final DateTime? createdAt;

  const _CampusUser({
    required this.name,
    required this.email,
    required this.identifier,
    required this.faculty,
    required this.role,
    required this.createdAt,
  });

  String get roleLabel => switch (role) {
        'admin' => 'Admin',
        'security' => 'Security',
        'staff' => 'Staff',
        'student' => 'Student',
        _ => 'Unassigned role',
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  factory _CampusUser.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    String text(String key, [String fallback = '']) {
      final value = data[key];
      return value is String ? value.trim() : fallback;
    }
    final name = text('fullName', '');
    final createdValue = data['createdAt'];
    return _CampusUser(
      name: name.isEmpty ? 'Name not provided' : name,
      email: text('email'),
      identifier: text('studentOrStaffId'),
      faculty: text('faculty'),
      role: text('role', 'unknown').toLowerCase(),
      createdAt: createdValue is Timestamp ? createdValue.toDate() : null,
    );
  }
}
