import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/user_avatar.dart';
import '../widgets/formatted_whatsapp_text.dart';

import 'package:jimpitan/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:jimpitan/utils/api_service.dart';
import 'dart:async';
import 'package:swipe_to/swipe_to.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class ChatRoomPage extends StatefulWidget {
  final String villageId;
  final String roomId;
  final String roomName;
  final String? targetUid;
  final String? targetFoto;

  const ChatRoomPage({
    super.key,
    required this.villageId,
    required this.roomId,
    required this.roomName,
    this.targetUid,
    this.targetFoto,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  // AudioPlayer _audioPlayer = AudioPlayer(); (Dihapus, diganti SystemSound)

  double _getEmojiFontSize(String text) {
    String withoutSpace = text.replaceAll(RegExp(r'\s+'), '');
    if (withoutSpace.isEmpty) return 15.0;

    // Jika ada karakter dengan kode unicode di bawah 8000, asumsikan itu teks/simbol biasa (bukan emoji)
    bool hasNormalText = withoutSpace.runes.any((rune) => rune < 8000);
    if (hasNormalText) {
      return 15.0;
    }

    int count = withoutSpace.characters.length;
    if (count == 1) return 48.0;
    if (count == 2) return 36.0;
    if (count == 3) return 28.0;
    return 15.0;
  }

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _userData;
  bool _showEmoji = false;
  String? _editingMessageId;
  Map<String, dynamic>? _replyingToMessage;

  List<dynamic> _messages = [];
  Map<String, dynamic>? _targetUserData;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchMessages(isBackground: true);
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    if (currentUser == null) return;

    // Asumsikan targetUid adalah room target (entah personal/group). Jika personal, backend menggunakan query sender/receiver.
    // Tetapi jika backend update mendukung roomId, kita gunakan targetUid = roomId.
    final target = widget.targetUid ?? widget.roomId;

    final messages = await ApiService.getMessages(
      widget.villageId,
      target,
      currentUser!.uid,
      roomId: widget.roomId,
    );
    // Sort descending by created_at to match previous logic (oldest at bottom in ListView.builder reversed)
    messages.sort((a, b) {
      final tA = DateTime.tryParse(a['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
      final tB = DateTime.tryParse(b['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
      return tB.compareTo(tA); // Descending
    });

    if (mounted) {
      setState(() {
        _messages = messages;
        if (!isBackground) _isLoading = false;
      });
    }

    // Tandai pesan sebagai sudah dibaca
    ApiService.markMessagesRead(
      widget.villageId,
      currentUser!.uid,
      roomId: widget.roomId,
      senderUid: widget.targetUid,
    );
  }

  Future<void> _loadUserData() async {
    if (currentUser?.email != null) {
      final users = await ApiService.getUsers(widget.villageId);
      final me = users.firstWhere(
        (u) => u['email'] == currentUser!.email,
        orElse: () => null,
      );
      if (me != null && mounted) {
        setState(() {
          _userData = me;
        });
      }

      if (widget.targetUid != null) {
        final target = users.firstWhere(
          (u) => u['uid'] == widget.targetUid,
          orElse: () => null,
        );
        if (target != null && mounted) {
          setState(() {
            _targetUserData = target;
          });
        }
      }
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _msgController.text = _msgController.text + emoji.emoji;
  }

  void _onBackspacePressed() {
    _msgController
      ..text = _msgController.text.characters.skipLast(1).toString()
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: _msgController.text.length),
      );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    _msgController.clear();

    try {
      if (_editingMessageId != null) {
        // PROSES EDIT PESAN
        await ApiService.updateMessage(
          widget.villageId,
          _editingMessageId!,
          message: text,
          isEdited: true,
        );
        setState(() {
          _editingMessageId = null;
        });
        _fetchMessages();
        return;
      }

      // PROSES KIRIM PESAN BARU
      final senderName =
          _userData?['name'] ?? 'Warga';

      await ApiService.sendMessage(
        widget.villageId,
        currentUser!.uid,
        widget.targetUid, // Boleh null untuk group chat
        text,
        roomId: widget.roomId,
        senderName: senderName,
        replyToId: _replyingToMessage?['id'],
        replyToMessage: _replyingToMessage?['message'] ?? _replyingToMessage?['text'],
        replyToSenderName: _replyingToMessage?['senderName'] ?? 'Warga',
      );

      setState(() {
        _replyingToMessage = null;
      });

      _fetchMessages();

      // Mainkan suara sistem alih-alih file .wav eksternal
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (e) {
        debugPrint('Failed to play sound: $e');
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim pesan: $e')));
      }
    }
  }

  void _showMessageOptions(Map<String, dynamic> data, BuildContext bubbleContext) async {
    if (data['isDeleted'] == true) return;

    final sentTime =
        DateTime.tryParse(data['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(sentTime);

    // Batas waktu WA: Edit max 15 menit, Hapus max 2 hari (48 jam)
    final canEdit = difference.inMinutes <= 15;
    final canDelete = difference.inHours <= 48;

    final renderBox = bubbleContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
    final x = isMe ? offset.dx + size.width : offset.dx;

    // Default position is at the bottom of the bubble
    double dy = offset.dy + size.height;
    
    // If placing it below the bubble would go off-screen, place it above the bubble instead.
    // Menu height is ~160
    if (dy + 160 > overlay.size.height) {
      dy = offset.dy - 160;
    }

    final relativeRect = RelativeRect.fromRect(
      Rect.fromLTWH(x, dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: relativeRect,
      color: Colors.white.withValues(alpha: 0.85),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'copy',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 12),
              const Text('Salin Pesan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, color: Colors.blue, size: 18),
                const SizedBox(width: 12),
                const Text('Edit Pesan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, color: Colors.red, size: 18),
                const SizedBox(width: 12),
                const Text('Hapus Pesan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'forward',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shortcut, color: Colors.green, size: 18),
              const SizedBox(width: 12),
              const Text('Teruskan Pesan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;

    if (result == 'copy') {
      Clipboard.setData(ClipboardData(text: data['message'] ?? data['text'] ?? ''));
      CustomToast.show(context, 'Pesan disalin');
    } else if (result == 'edit') {
      setState(() {
        _editingMessageId = data['id'];
        _msgController.text = data['message'] ?? data['text'] ?? '';
        _focusNode.requestFocus();
      });
    } else if (result == 'delete') {
      await ApiService.updateMessage(
        widget.villageId,
        data['id'],
        isDeleted: true,
      );
      _fetchMessages();
    } else if (result == 'forward') {
      _showForwardDialog(data);
    }
  }

  void _showForwardDialog(Map<String, dynamic> messageData) async {
    final users = await ApiService.getUsers(widget.villageId);
    
    // Siapkan daftar grup
    List<Map<String, dynamic>> contacts = [];
    contacts.add({
      'uid': 'GROUP_${widget.villageId}',
      'name': 'Grup Warga RT',
      'isGroup': true,
    });
    if (_userData != null) {
      final rolesData = _userData!['roles'];
      if ((rolesData is List && (rolesData.contains('ADMIN') || rolesData.contains('SUPER_ADMIN') || rolesData.contains('ADMIN_DESA'))) ||
          (rolesData is String && (rolesData.contains('ADMIN') || rolesData.contains('SUPER_ADMIN') || rolesData.contains('ADMIN_DESA')))) {
        contacts.add({
          'uid': 'GROUP_ADMIN_${widget.villageId}',
          'name': 'Grup Pengurus',
          'isGroup': true,
        });
      }
    }

    // Tambahkan warga
    for (var u in users) {
      if (u['uid'] != currentUser?.uid) {
        contacts.add({
          'uid': u['uid'],
          'name': u['name'] ?? 'Warga',
          'isGroup': false,
          'foto': u['foto'],
        });
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Teruskan ke...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final c = contacts[index];
                      final isGroup = c['isGroup'] == true;
                      
                      return ListTile(
                        leading: UserAvatar(
                          userData: c,
                          radius: 20,
                        ),
                        title: Text(c['name'], style: TextStyle(fontWeight: isGroup ? FontWeight.bold : FontWeight.normal)),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          
                          // Kirim pesan
                          final senderName = _userData?['name'] ?? 'Warga';
                          final targetId = c['uid'];
                          final isGroupTarget = c['isGroup'] == true;

                          try {
                            await ApiService.sendMessage(
                              widget.villageId,
                              currentUser!.uid,
                              isGroupTarget ? null : targetId, // receiverUid
                              messageData['message'] ?? messageData['text'] ?? '',
                              roomId: isGroupTarget ? targetId : null,
                              senderName: senderName,
                              isForwarded: true,
                            );
                            messenger.showSnackBar(const SnackBar(content: Text('Pesan berhasil diteruskan')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Gagal meneruskan pesan: $e')));
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) return 'Hari Ini';
    if (msgDate == yesterday) return 'Kemarin';
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showEmoji) {
          setState(() {
            _showEmoji = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF8FAFC,
        ), // Modern light slate background
        appBar: AppBar(
          title: widget.targetUid == null
              ? Text(widget.roomName)
              : Builder(
                  builder: (context) {
                    String statusText = '';
                    Color statusColor = Colors.grey;
                    if (_targetUserData != null) {
                      final data = _targetUserData!;
                      bool isOnline = data['isOnline'] == true;
                      final ts = data['lastSeen'];
                      DateTime? lastSeenDate;
                      if (ts != null) {
                        lastSeenDate = DateTime.tryParse(ts.toString())?.toLocal();
                      }
                      if (isOnline) {
                        if (lastSeenDate != null &&
                            DateTime.now().difference(lastSeenDate).inSeconds > 150) {
                          isOnline = false;
                        }
                      }
                      if (isOnline) {
                        statusText = 'Online';
                        statusColor = Colors.green;
                      } else {
                        if (lastSeenDate != null) {
                          final diff = DateTime.now().difference(lastSeenDate);
                          if (diff.inMinutes < 1) {
                            statusText = 'Baru saja';
                          } else if (diff.inHours < 24) {
                            statusText =
                                'Terakhir dilihat pukul ${lastSeenDate.hour.toString().padLeft(2, '0')}:${lastSeenDate.minute.toString().padLeft(2, '0')}';
                          } else if (diff.inDays < 7) {
                            statusText =
                                'Terakhir dilihat ${diff.inDays} hari yang lalu';
                          } else {
                            statusText =
                                'Terakhir dilihat ${lastSeenDate.day}/${lastSeenDate.month}/${lastSeenDate.year}';
                          }
                        } else {
                          statusText = 'Offline';
                        }
                      }
                    }

                    return Row(
                      children: [
                        UserAvatar(
                          userData: _targetUserData ?? {'name': widget.roomName},
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.roomName,
                                style: const TextStyle(fontSize: 18),
                              ),
                              if (statusText.isNotEmpty)
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Kirim pesan pertama Anda!'),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final data = _messages[index];
                        final isMe = data['senderUid'] == currentUser?.uid;
                        final isDeleted = data['isDeleted'] == true;
                        final isEdited = data['isEdited'] == true;

                        DateTime? currentDateTime = DateTime.tryParse(
                          data['createdAt'] ?? '',
                        )?.toLocal();
                        final timeStr = currentDateTime != null
                            ? DateFormat('HH:mm').format(currentDateTime)
                            : '';

                        // Cek group tanggal (bandingkan dengan pesan sebelumnya yang chronologically NEXT di reverse list)
                        bool showDateHeader = false;
                        if (index == _messages.length - 1) {
                          showDateHeader = true;
                        } else {
                          final prevData = _messages[index + 1];
                          DateTime? prevDateTime = DateTime.tryParse(
                            prevData['createdAt'] ?? '',
                          )?.toLocal();

                          if (currentDateTime != null && prevDateTime != null) {
                            if (currentDateTime.day != prevDateTime.day ||
                                currentDateTime.month != prevDateTime.month ||
                                currentDateTime.year != prevDateTime.year) {
                              showDateHeader = true;
                            }
                          }
                        }

                        Widget bubble = SwipeTo(
                          onRightSwipe: (details) {
                            if (!isDeleted) {
                              setState(() {
                                _replyingToMessage = data;
                                _focusNode.requestFocus();
                              });
                            }
                          },
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Builder(
                              builder: (bubbleContext) => GestureDetector(
                                onLongPress: (!isDeleted)
                                    ? () => _showMessageOptions(data, bubbleContext)
                                    : null,
                              child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.8,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isDeleted
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.block,
                                            size: 14,
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.black45,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pesan ini telah dihapus',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.black45,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (data['isForwarded'] == true) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.shortcut,
                                                  size: 12,
                                                  color: isMe ? Colors.white70 : Colors.black54,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Diteruskan',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: isMe ? Colors.white70 : Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          if (!isMe && widget.targetUid == null) ...[
                                            Text(
                                              data['senderName'] ?? 'Anonim',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          if (data['replyToMessage'] != null) ...[
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['replyToSenderName'] ?? 'Warga',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isMe ? Colors.white : AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  FormattedWhatsAppText(
                                                    text: data['replyToMessage'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isMe ? Colors.white70 : Colors.black87,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          FormattedWhatsAppText(
                                            text: data['message'] ??
                                                data['text'] ??
                                                '',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: _getEmojiFontSize(
                                                data['message'] ??
                                                    data['text'] ??
                                                    '',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isEdited) ...[
                                                Text(
                                                  '(Telah diedit)',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : Colors.black45,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Builder(
                                                  builder: (context) {
                                                    IconData tickIcon =
                                                        Icons.done;
                                                    Color tickColor =
                                                        Colors.white70;
                                                    if (widget.targetUid ==
                                                        null) {
                                                      // Group chat
                                                      tickIcon = Icons.done_all;
                                                    } else {
                                                      final isRead =
                                                          data['isRead'] ==
                                                              true ||
                                                          data['isRead'] == 1 ||
                                                          data['isRead'] ==
                                                              '1' ||
                                                          data['is_read'] ==
                                                              true ||
                                                          data['is_read'] ==
                                                              1 ||
                                                          data['is_read'] ==
                                                              '1';
                                                      if (isRead) {
                                                        tickIcon =
                                                            Icons.done_all;
                                                        tickColor = Colors
                                                            .white; // Read status in primary color bubble
                                                      }
                                                    }
                                                    return Icon(
                                                      tickIcon,
                                                      size: 14,
                                                      color: tickColor,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),
                            ),
                          ),
                        );

                        if (showDateHeader && currentDateTime != null) {
                          return Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getDateLabel(currentDateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              bubble,
                            ],
                          );
                        }

                        return bubble;
                      },
                    ),
            ),

            // Kolom Input & Batal Edit
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (_replyingToMessage != null)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(left: BorderSide(color: AppTheme.primaryColor, width: 4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _replyingToMessage!['senderName'] ?? 'Warga',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _replyingToMessage!['message'] ?? _replyingToMessage!['text'] ?? '',
                                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _replyingToMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_editingMessageId != null)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Sedang mengedit pesan',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _editingMessageId = null;
                                  _msgController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9), // Slate 100
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _showEmoji
                                          ? Icons.keyboard
                                          : Icons.emoji_emotions_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      if (_showEmoji) {
                                        _focusNode.requestFocus();
                                      } else {
                                        _focusNode.unfocus();
                                        setState(() {
                                          _showEmoji = true;
                                        });
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _msgController,
                                      focusNode: _focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Ketik pesan...',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      minLines: 1,
                                      maxLines: 5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            radius: 24,
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Emoji Picker
            if (_showEmoji)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: _onEmojiSelected,
                  onBackspacePressed: _onBackspacePressed,
                  config: Config(
                    emojiViewConfig: EmojiViewConfig(
                      columns: 7,
                      emojiSizeMax:
                          32 *
                          (foundation.defaultTargetPlatform ==
                                  TargetPlatform.iOS
                              ? 1.30
                              : 1.0),
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

