import 'dart:async';
import 'package:flutter/services.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class ManualScanPage extends StatefulWidget {
  final String villageId;
  const ManualScanPage({super.key, required this.villageId});

  @override
  State<ManualScanPage> createState() => _ManualScanPageState();
}

class _ManualScanPageState extends State<ManualScanPage> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _historyList = [];
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  Map<String, Map<String, dynamic>> _kkPhotos = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadPhotos();
    // Polling secara background tiap 3 detik untuk realtime tanpa me-refresh UI secara kasar
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchDataSilent();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getJimpitanHistory(widget.villageId);
      if (mounted) {
        setState(() {
          _historyList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final users = await ApiService.getUsers(widget.villageId);
      final Map<String, Map<String, dynamic>> photos = {};
      // Pass 1: Temukan foto Kepala Keluarga untuk setiap kkId / noKK
      final Map<String, Map<String, dynamic>> kkPhotoMap = {};
      
      for (var d in users) {
        final statusHubungan = (d['statusHubungan'] ?? '').toString().toLowerCase();
        if (statusHubungan == 'kepala keluarga') {
          final kkId = d['kkId']?.toString() ?? '';
          final noKk = d['noKK']?.toString() ?? '';
          final photoData = {
            'foto': d['foto'],
            'photoUrl': d['photoUrl'],
          };
          if (kkId.isNotEmpty) kkPhotoMap[kkId] = photoData;
          if (noKk.isNotEmpty) kkPhotoMap[noKk] = photoData;
        }
      }

      // Pass 2: Petakan SEMUA id (uid, code, uniqueCode) milik anggota keluarga ke foto Kepala Keluarganya!
      for (var d in users) {
        final uid = d['uid']?.toString() ?? '';
        final code = d['code']?.toString() ?? '';
        final uniqueCode = d['uniqueCode']?.toString() ?? '';
        final kkId = d['kkId']?.toString() ?? '';
        final noKk = d['noKK']?.toString() ?? '';

        // Ambil foto KK jika ada, jika tidak ada fallback ke foto anggota itu sendiri
        Map<String, dynamic> photoDataToUse = {
          'foto': d['foto'],
          'photoUrl': d['photoUrl'],
        };

        if (kkId.isNotEmpty && kkPhotoMap.containsKey(kkId)) {
          photoDataToUse = kkPhotoMap[kkId]!;
        } else if (noKk.isNotEmpty && kkPhotoMap.containsKey(noKk)) {
          photoDataToUse = kkPhotoMap[noKk]!;
        }

        if (uid.isNotEmpty) photos[uid] = photoDataToUse;
        if (code.isNotEmpty) photos[code] = photoDataToUse;
        if (uniqueCode.isNotEmpty) photos[uniqueCode] = photoDataToUse;
        if (noKk.isNotEmpty) photos[noKk] = photoDataToUse;
        if (kkId.isNotEmpty) photos[kkId] = photoDataToUse;
      }
      if (mounted) {
        setState(() {
          _kkPhotos = photos;
        });
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
    }
  }

  Future<void> _fetchDataSilent() async {
    try {
      final data = await ApiService.getJimpitanHistory(widget.villageId);
      if (mounted) {
        setState(() {
          _historyList = data;
        });
      }
    } catch (e) {
      // Abaikan error pada silent update agar tidak mengganggu UI pengguna
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchInitialData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _deleteHistory(String id) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AppModalDialog(
        title: 'Hapus Jimpitan',
        headerIcon: Icons.delete,
        scrollable: false,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Anda yakin ingin menghapus data jimpitan manual ini?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      EasyLoading.show(status: 'Menghapus...');
                      try {
                        bool success = await ApiService.deleteJimpitanHistory(
                          id,
                        );
                        if (!mounted) return;
                        if (success) {
                          CustomToast.show(context, 'Berhasil menghapus data');
                          _fetchInitialData();
                        } else {
                          CustomToast.show(
                            context,
                            'Gagal menghapus data',
                            isError: true,
                          );
                        }
                        if (mounted) {
                          CustomToast.show(context, 'Data berhasil dihapus');
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomToast.show(context, 'Error: $e', isError: true);
                        }
                      } finally {
                        EasyLoading.dismiss();
                      }
                    },
                    child: const Text(
                      'Hapus',
                      style: TextStyle(color: Colors.white),
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

  Future<void> _showManualInputDialog() async {
    EasyLoading.show(status: 'Memuat data warga...');
    List<dynamic> users = [];
    int currentNominal = 0;
    try {
      users = await ApiService.getUsers(widget.villageId);
      final history = await ApiService.getJimpitanHistory(widget.villageId);
      if (mounted) {
        setState(() {
          _historyList = history;
        });
      }
      final tariffs = await ApiService.getTariffs(widget.villageId);
      final tariffDoc = tariffs.cast<Map<String, dynamic>?>().firstWhere(
        (t) => t != null && t['id'] == '${widget.villageId}_jimpitan',
        orElse: () => null,
      );
      currentNominal = (tariffDoc?['amount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        CustomToast.show(context, 'Gagal memuat data: $e', isError: true);
      }
      return;
    }
    EasyLoading.dismiss();

    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final alreadyPaidKkIds = _historyList
        .where((data) {
          if (data['date'] != null && data['date'].toString().isNotEmpty) {
            return data['date'].toString().startsWith(selectedDateStr);
          }
          DateTime? dt;
          if (data['timestamp'] is String) {
            dt = DateTime.tryParse(data['timestamp']);
          }
          if (dt == null) return false;
          return DateFormat('yyyy-MM-dd').format(dt.toLocal()) ==
              selectedDateStr;
        })
        .map((e) => (e['kkId'] ?? '').toString().trim().toLowerCase())
        .toSet();

    final kkUsers = users.cast<Map<String, dynamic>>().where((u) {
      final statusHubungan = (u['statusHubungan'] ?? '').toString();
      final roles = u['roles'];
      final isKK =
          statusHubungan == 'Kepala Keluarga' ||
          (roles is List && roles.contains('KK')) ||
          roles == 'KK' ||
          u['isHeadOfFamily'] == true;
      final statusHidup = u['statusHidup']?.toString() ?? 'Hidup';
      final isAlive =
          statusHidup == 'Hidup' || statusHidup == 'Aktif' || statusHidup == '';

      final uniqueCode = (u['uniqueCode'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final kkId = (u['kkId'] ?? '').toString().trim().toLowerCase();
      final uid = (u['uid'] ?? u['docId'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final familyId = (u['familyId'] ?? '').toString().trim().toLowerCase();
      final noKk = (u['noKK'] ?? '').toString().trim().toLowerCase();

      bool hasPaid =
          (uniqueCode.isNotEmpty && alreadyPaidKkIds.contains(uniqueCode)) ||
          (kkId.isNotEmpty && alreadyPaidKkIds.contains(kkId)) ||
          (uid.isNotEmpty && alreadyPaidKkIds.contains(uid)) ||
          (familyId.isNotEmpty && alreadyPaidKkIds.contains(familyId)) ||
          (noKk.isNotEmpty && alreadyPaidKkIds.contains(noKk));

      if (!hasPaid && u['familyMembers'] is List) {
        for (var member in u['familyMembers']) {
          final mUniqueCode = (member['uniqueCode'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final mKkId = (member['kkId'] ?? '').toString().trim().toLowerCase();
          final mUid = (member['uid'] ?? member['docId'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if ((mUniqueCode.isNotEmpty &&
                  alreadyPaidKkIds.contains(mUniqueCode)) ||
              (mKkId.isNotEmpty && alreadyPaidKkIds.contains(mKkId)) ||
              (mUid.isNotEmpty && alreadyPaidKkIds.contains(mUid))) {
            hasPaid = true;
            break;
          }
        }
      }

      return isKK && isAlive && !hasPaid;
    }).toList();

    if (kkUsers.isEmpty) {
      if (mounted) CustomToast.show(context, 'Data Kepala Keluarga kosong.');
      return;
    }

    if (currentNominal <= 0) {
      if (mounted) {
        CustomToast.show(
          context,
          'Tarif jimpitan belum diatur atau bernilai 0.',
        );
      }
      return;
    }

    Set<String> selectedKkIds = {};
    String searchQuery = '';
    final searchController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filteredUsers = kkUsers.where((u) {
              final name = (u['name'] ?? '').toString().toLowerCase();
              final kkId = (u['uniqueCode'] ?? u['kkId'] ?? '')
                  .toString()
                  .toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || kkId.contains(q);
            }).toList();

            bool allSelected =
                filteredUsers.isNotEmpty &&
                filteredUsers.every(
                  (u) => selectedKkIds.contains(
                    (u['uniqueCode'] ?? u['kkId'] ?? '').toString(),
                  ),
                );

            return AppModalDialog(
              title: 'Input Manual Jimpitan',
              headerIcon: Icons.payments,
              scrollable: false,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Cari Warga (Nama / Kode)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tarif: Rp $currentNominal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (allSelected) {
                              for (var u in filteredUsers) {
                                selectedKkIds.remove(
                                  (u['uniqueCode'] ?? u['kkId'] ?? '')
                                      .toString(),
                                );
                              }
                            } else {
                              for (var u in filteredUsers) {
                                selectedKkIds.add(
                                  (u['uniqueCode'] ?? u['kkId'] ?? '')
                                      .toString(),
                                );
                              }
                            }
                          });
                        },
                        child: Text(
                          allSelected ? 'Batal Semua' : 'Pilih Semua',
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final u = filteredUsers[index];
                        final id = (u['uniqueCode'] ?? u['kkId'] ?? '')
                            .toString();
                        final name = u['name'] ?? 'Unknown';
                        return CheckboxListTile(
                          value: selectedKkIds.contains(id),
                          title: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            id,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedKkIds.add(id);
                              } else {
                                selectedKkIds.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedKkIds.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(dialogContext);
                                  EasyLoading.show(
                                    status:
                                        'Menyimpan ${selectedKkIds.length} data...',
                                  );

                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  int successCount = 0;

                                  final nowTime = DateTime.now();
                                  final recordTime = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    nowTime.hour,
                                    nowTime.minute,
                                    nowTime.second,
                                  );
                                  final nowStr = recordTime.toIso8601String();
                                  final dateStr = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_selectedDate);

                                  final scannerName = await ApiService.getCurrentCitizenName(widget.villageId);

                                  for (String id in selectedKkIds) {
                                    final u = kkUsers.firstWhere(
                                      (user) =>
                                          (user['uniqueCode'] ??
                                                  user['kkId'] ??
                                                  '')
                                              .toString() ==
                                          id,
                                    );
                                    final name = u['name'] ?? 'Unknown';

                                    final success =
                                        await ApiService.createJimpitanHistory({
                                          'kkId': id,
                                          'name': name,
                                          'amount': currentNominal,
                                          'scannedBy':
                                              currentUser?.uid ?? 'unknown',
                                          'scannedByName': scannerName,
                                          'timestamp': nowStr,
                                          'date': dateStr,
                                          'type': 'MANUAL',
                                          'villageId': widget.villageId,
                                        });

                                    if (success) successCount++;
                                  }

                                  EasyLoading.dismiss();
                                  if (!mounted) return;
                                  if (successCount > 0) {
                                    CustomToast.show(
                                      context,
                                      'Berhasil menyimpan $successCount dari ${selectedKkIds.length} data.',
                                    );
                                    _fetchInitialData();
                                  } else {
                                    CustomToast.show(
                                      context,
                                      'Gagal menyimpan data.',
                                      isError: true,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Simpan (${selectedKkIds.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedHeader(
    BuildContext context,
    Color primaryColor,
    int totalAmount,
    int totalWarga,
    int totalScan,
    int totalTagihan,
    int totalManual,
    NumberFormat currencyFormat,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final secondaryColor = AppTheme.secondaryColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dekorasi lingkaran kanan atas
          Positioned(
            top: -40,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Dekorasi lingkaran kiri bawah
          Positioned(
            bottom: -30,
            left: -30,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Konten Header
          Column(
            children: [
              SizedBox(height: topPadding + 10),
              // Top Bar Navigation (Back Button, Title, Actions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Scan Manual Jimpitan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showManualInputDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _handleRefresh,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.date_range,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Summary Stats Area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    const Text(
                      'Total Terkumpul',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFormat.format(totalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 2,
                        bottom: 12,
                      ),
                      child: Text(
                        DateFormat(
                          'EEEE, dd MMM yyyy',
                          'id_ID',
                        ).format(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            Icons.people,
                            '$totalWarga',
                            'Total Warga',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildStatItem(
                            Icons.qr_code_scanner,
                            '$totalScan',
                            'Via Scan',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildStatItem(
                            Icons.event_available,
                            '$totalTagihan',
                            'Via Tagihan',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildStatItem(
                            Icons.edit_note,
                            '$totalManual',
                            'Via Manual',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0,
      0,
      0,
    );
    DateTime endDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
    );

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, primaryColor, _) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Builder(
              builder: (context) {
                if (_isLoading && _historyList.isEmpty) {
                  return Column(
                    children: [
                      _buildUnifiedHeader(
                        context,
                        primaryColor,
                        0,
                        0,
                        0,
                        0,
                        0,
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ),
                      ),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  );
                }
                if (_error != null && _historyList.isEmpty) {
                  return Column(
                    children: [
                      _buildUnifiedHeader(
                        context,
                        primaryColor,
                        0,
                        0,
                        0,
                        0,
                        0,
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Terjadi kesalahan: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _handleRefresh,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Local filtering and sorting to avoid composite index requirement
                final allDocs = _historyList;
                final selectedDateStr = DateFormat(
                  'yyyy-MM-dd',
                ).format(_selectedDate);

                final filteredDocs = allDocs.where((data) {
                  if (data['date'] != null &&
                      data['date'].toString().isNotEmpty) {
                    return data['date'].toString().startsWith(selectedDateStr);
                  }

                  DateTime? dt;
                  if (data['timestamp'] is String) {
                    dt = DateTime.tryParse(data['timestamp']);
                  }
                  if (dt == null) return false;
                  return dt.toLocal().isAfter(
                        startDate.subtract(const Duration(seconds: 1)),
                      ) &&
                      dt.toLocal().isBefore(
                            endDate.add(const Duration(seconds: 1)),
                          );
                }).toList();

                filteredDocs.sort((a, b) {
                  DateTime? tsA;
                  if (a['timestamp'] is String) {
                    tsA = DateTime.tryParse(a['timestamp']);
                  }
                  DateTime? tsB;
                  if (b['timestamp'] is String) {
                    tsB = DateTime.tryParse(b['timestamp']);
                  }

                  if (tsA == null || tsB == null) return 0;
                  return tsB.compareTo(tsA); // descending
                });

                // Hitung Total Saldo dan Statistik
                int totalAmount = 0;
                int totalScan = 0;
                int totalTagihan = 0;
                int totalManual = 0;

                for (var data in filteredDocs) {
                  totalAmount += (data['amount'] as num?)?.toInt() ?? 0;
                  if (data['type'] == 'TAGIHAN') {
                    totalTagihan++;
                  } else if (data['type'] == 'MANUAL') {
                    totalManual++;
                  } else {
                    totalScan++;
                  }
                }
                int totalWarga = filteredDocs.length;

                final currencyFormat = NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                );

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppTheme.primaryColor,
                  child: Column(
                    children: [
                      // Unified Header
                      _buildUnifiedHeader(
                        context,
                        primaryColor,
                        totalAmount,
                        totalWarga,
                        totalScan,
                        totalTagihan,
                        totalManual,
                        currencyFormat,
                      ),

                // List Transaksi
                Expanded(
                  child: filteredDocs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.3,
                            ),
                            const Center(
                              child: Text(
                                'Tidak ada data scan pada tanggal ini.',
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            80 + (bottomPadding > 0 ? bottomPadding : 16),
                          ),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final data =
                                filteredDocs[index] as Map<String, dynamic>;
                            final String name = data['name'] ?? 'Anonim';
                            final int amount =
                                (data['amount'] as num?)?.toInt() ?? 0;

                            String timeString = '';
                            if (data['timestamp'] != null) {
                              DateTime? ts = DateTime.tryParse(
                                data['timestamp'],
                              );
                              if (ts != null) {
                                timeString = DateFormat('HH:mm').format(ts);
                              }
                            }

                            // Styling berdasarkan tipe transaksi
                            final String type = data['type'] ?? 'JIMPITAN';

                            final String kkId = (data['kkId'] ?? '').toString();
                            final String userUid = (data['userUid'] ?? data['uid'] ?? '').toString();
                            final String uniqueCode = (data['uniqueCode'] ?? data['code'] ?? '').toString();
                            
                            Map<String, dynamic>? photoData;
                            if (kkId.isNotEmpty && _kkPhotos.containsKey(kkId)) {
                              photoData = _kkPhotos[kkId];
                            } else if (userUid.isNotEmpty && _kkPhotos.containsKey(userUid)) {
                              photoData = _kkPhotos[userUid];
                            } else if (uniqueCode.isNotEmpty && _kkPhotos.containsKey(uniqueCode)) {
                              photoData = _kkPhotos[uniqueCode];
                            }

                            final Map<String, dynamic> combinedData = Map.from(data);
                            if (photoData != null) {
                              combinedData['foto'] = photoData['foto'];
                              combinedData['photoUrl'] = photoData['photoUrl'];
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '${index + 1}.',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      UserAvatar(userData: combinedData, radius: 18),
                                    ],
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    data['type'] == 'TAGIHAN'
                                        ? 'Pembayaran Tagihan • $timeString'
                                        : data['type'] == 'MANUAL'
                                        ? 'Input Manual • $timeString'
                                        : 'Discan oleh: ${data['scannedByName'] ?? 'Petugas'} • $timeString',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                    ),
                                  ),
                                  trailing: type == 'MANUAL'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              currencyFormat.format(amount),
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () => _deleteHistory(
                                                data['id'] ??
                                                    data['docId'] ??
                                                    '',
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          currencyFormat.format(amount),
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                  isThreeLine: false,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
},
);
    }
  }
