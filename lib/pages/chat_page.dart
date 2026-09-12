import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/pages/chat_room_page.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/widgets/user_avatar.dart';
import 'dart:async';
class ChatPage extends StatefulWidget {
  final String villageId;
  final Map<String, bool> permissions;

  const ChatPage({
    super.key,
    required this.villageId,
    required this.permissions,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  Map<String, dynamic>? _currentUserData;
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _loadData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool isBackground = false}) async {
    final allUsers = await ApiService.getUsers(widget.villageId);

    if (currentUser != null) {
      final me = allUsers.firstWhere(
        (u) => u['email'] == currentUser!.email,
        orElse: () => null,
      );
      if (me != null && mounted) {
        setState(() {
          _currentUserData = me;
        });
      }
    }

    // Ambil super admin dari desa ini
    final superAdmins = allUsers
        .where(
          (u) =>
              u['uid'] != currentUser?.uid &&
              (u['roles']?.toString().contains('SUPER_ADMIN') ?? false),
        )
        .toList();

    // Tambahkan Super Admin dari pusat jika tidak ada di desa ini
    if (superAdmins.isEmpty) {
      try {
        final centralUsers = await ApiService.getUsers('');
        final centralAdmins = centralUsers
            .where(
              (u) => u['roles']?.toString().contains('SUPER_ADMIN') ?? false,
            )
            .toList();
        superAdmins.addAll(centralAdmins);
      } catch (e) {
        debugPrint('Gagal memuat admin pusat: $e');
      }
    }

    final otherUsers = allUsers
        .where(
          (u) =>
              u['uid'] != currentUser?.uid &&
              u['status'] == 'ACTIVE' &&
              !(u['roles']?.toString().contains('SUPER_ADMIN') ?? false),
        )
        .toList();

    if (mounted) {
      setState(() {
        _users = [...superAdmins, ...otherUsers];
        _filteredUsers = _filterUsers(_users, _searchQuery);
        if (!isBackground) _isLoading = false;
      });
    }

    // Ambil unread counts
    if (currentUser != null) {
      final counts = await ApiService.getUnreadCounts(
        widget.villageId,
        currentUser!.uid,
      );
      if (mounted) {
        setState(() {
          _unreadCounts = counts;
        });
      }
    }
  }

  List<dynamic> _filterUsers(List<dynamic> users, String query) {
    if (query.isEmpty) return users;
    final q = query.toLowerCase();
    return users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final nik = (u['nik'] ?? '').toString().toLowerCase();
      return name.contains(q) || nik.contains(q);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredUsers = _filterUsers(_users, query);
    });
  }

  bool _isUserOnline(Map user) {
    if (user['isOnline'] != true) return false;
    final ts = user['lastSeen'];
    if (ts == null) return false;
    final date = DateTime.tryParse(ts.toString())?.toLocal();
    if (date == null) return false;
    // Anggap online jika ada aktivitas dalam 2.5 menit terakhir
    return DateTime.now().difference(date).inSeconds <= 150;
  }

  // Membuat roomId yang unik dan konsisten untuk personal chat
  String _getPersonalRoomId(String targetUid) {
    if (currentUser == null) return '';
    final uids = [currentUser!.uid, targetUid];
    uids.sort(); // Urutkan agar kombinasi uid A dan B selalu menghasilkan ID yang sama
    return 'PERSONAL_${uids[0]}_${uids[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomGradientAppBar(
        title: Builder(
          builder: (context) {
            String userName = 'Memuat...';

            if (_currentUserData != null) {
              final data = _currentUserData!;
              userName = data['name'] ?? 'Pengguna';
            }

            return Row(
              children: [
                UserAvatar(
                  userData: _currentUserData,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Grup Resmi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    bool isAdmin = false;
                    if (_currentUserData != null) {
                      final data = _currentUserData!;
                      final rolesData = data['roles'];

                      if (rolesData is List) {
                        if (rolesData.contains('ADMIN') ||
                            rolesData.contains('SUPER_ADMIN') ||
                            rolesData.contains('ADMIN_DESA')) {
                          isAdmin = true;
                        }
                      } else if (rolesData is String) {
                        if (rolesData.contains('ADMIN') ||
                            rolesData.contains('SUPER_ADMIN') ||
                            rolesData.contains('ADMIN_DESA')) {
                          isAdmin = true;
                        }
                      }
                    }

                    final groupRoomId = 'GROUP_${widget.villageId}';
                    final groupUnread = _unreadCounts[groupRoomId] ?? 0;
                    const adminRoomId = 'GROUP_ADMINS';
                    final adminUnread = _unreadCounts[adminRoomId] ?? 0;

                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: const Icon(
                              Icons.groups,
                              color: Colors.white,
                            ),
                          ),
                          title: const Text(
                            'Grup Warga RT',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Ruang diskusi seluruh warga RT',
                          ),
                          trailing: groupUnread > 0
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    groupUnread > 99
                                        ? '99+'
                                        : groupUnread.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            if (currentUser != null) {
                              ApiService.markMessagesRead(
                                widget.villageId,
                                currentUser!.uid,
                                roomId: groupRoomId,
                              );
                              setState(() {
                                _unreadCounts.remove(groupRoomId);
                              });
                            }
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomPage(
                                  villageId: widget.villageId,
                                  roomId: groupRoomId,
                                  roomName: 'Grup Warga RT',
                                ),
                              ),
                            );
                            _loadData(isBackground: true);
                          },
                        ),
                        if (isAdmin)
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                              ),
                            ),
                            title: const Text(
                              'Grup Admin Pusat',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Koordinasi Super Admin & Admin Desa',
                            ),
                            trailing: adminUnread > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      adminUnread > 99
                                          ? '99+'
                                          : adminUnread.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () async {
                              if (currentUser != null) {
                                ApiService.markMessagesRead(
                                  widget.villageId,
                                  currentUser!.uid,
                                  roomId: adminRoomId,
                                );
                                setState(() {
                                  _unreadCounts.remove(adminRoomId);
                                });
                              }
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatRoomPage(
                                    villageId: widget.villageId,
                                    roomId: adminRoomId,
                                    roomName: 'Grup Admin Pusat',
                                  ),
                                ),
                              );
                              _loadData(isBackground: true);
                            },
                          ),
                      ],
                    );
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau NIK warga...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Kontak Warga (Personal Chat)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              if (_isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (_filteredUsers.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ada kontak "$_searchQuery"'
                              : 'Belum ada data warga aktif.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final users = List.from(_filteredUsers);

              // Urutkan: Super Admin dulu, baru Online, baru Terakhir Aktif
              users.sort((a, b) {
                final isSuperA =
                    a['roles']?.toString().contains('SUPER_ADMIN') ?? false;
                final isSuperB =
                    b['roles']?.toString().contains('SUPER_ADMIN') ?? false;
                if (isSuperA && !isSuperB) return -1;
                if (!isSuperA && isSuperB) return 1;

                DateTime getEffectiveLastSeen(Map user) {
                  if (_isUserOnline(user)) return DateTime.now();
                  final ts = DateTime.tryParse(
                    user['lastSeen']?.toString() ?? '',
                  )?.toLocal();
                  if (ts != null) return ts;
                  return DateTime.fromMillisecondsSinceEpoch(0); // Paling lama
                }

                final timeA = getEffectiveLastSeen(a as Map);
                final timeB = getEffectiveLastSeen(b as Map);

                return timeB.compareTo(timeA); // Descending
              });

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final userData = Map<String, dynamic>.from(users[index] as Map);
                  final targetUid = userData['uid'] ?? '';
                  final name = userData['name'] ?? 'Warga Tanpa Nama';
                  final roomId = _getPersonalRoomId(targetUid);
                  final unreadCount =
                      _unreadCounts[targetUid] ?? _unreadCounts[roomId] ?? 0;
                  final isSuper =
                      userData['roles']?.toString().contains('SUPER_ADMIN') ??
                      false;

                  final isOnline = _isUserOnline(userData as Map);

                  String lastSeenText = 'Offline';
                  if (isOnline) {
                    lastSeenText = 'Online';
                  } else {
                    final ts = userData['lastSeen'];
                    if (ts != null) {
                      final date =
                          DateTime.tryParse(ts.toString())?.toLocal() ?? DateTime.now();
                      final diff = DateTime.now().difference(date);
                      if (diff.inMinutes < 1) {
                        lastSeenText = 'Terakhir aktif baru saja';
                      } else if (diff.inMinutes < 60) {
                        lastSeenText =
                            'Terakhir aktif ${diff.inMinutes} menit lalu';
                      } else if (diff.inHours < 24) {
                        lastSeenText =
                            'Terakhir aktif hari ini ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                      } else if (diff.inDays < 7) {
                        lastSeenText =
                            'Terakhir aktif ${diff.inDays} hari lalu';
                      } else {
                        lastSeenText =
                            'Terakhir aktif ${date.day}/${date.month}/${date.year}';
                      }
                    }
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    leading: Stack(
                      children: [
                        UserAvatar(
                          userData: userData,
                          radius: 26,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSuper
                                  ? AppTheme.primaryColor
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (isSuper)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PUSAT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (isOnline)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Online',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (!isOnline)
                          Expanded(
                            child: Text(
                              lastSeenText,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    onTap: () async {
                      // Jadikan async
                      final roomId = _getPersonalRoomId(targetUid);
                      // Mark messages as read
                      if (currentUser != null) {
                        ApiService.markMessagesRead(
                          widget.villageId,
                          currentUser!.uid,
                          senderUid: targetUid,
                        );
                        setState(() {
                          _unreadCounts.remove(roomId);
                          _unreadCounts.remove(targetUid);
                        });
                      }
                      await Navigator.push(
                        // Tambahkan await
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomPage(
                            villageId: widget.villageId,
                            roomId: roomId,
                            roomName: name,
                            targetUid: targetUid,
                            targetFoto: userData['foto'],
                          ),
                        ),
                      );

                      // Setelah kembali dari chat room, muat ulang data unread
                      _loadData(isBackground: true);
                    },
                  );
                }, childCount: users.length),
              );
            },
          ),
        ],
      ),
    );
  }
}

