import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/widgets/user_avatar.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class ExemptionsPage extends StatefulWidget {
  final String villageId;
  final Map<String, bool> permissions;

  const ExemptionsPage({
    super.key,
    required this.villageId,
    required this.permissions,
  });

  @override
  State<ExemptionsPage> createState() => _ExemptionsPageState();
}

class _ExemptionsPageState extends State<ExemptionsPage> {
  late Future<List<dynamic>> _exemptionsFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, Map<String, dynamic>> _kkPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _exemptionsFuture = ApiService.getExemptions(widget.villageId);
    });
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final users = await ApiService.getUsers(widget.villageId);
      final Map<String, Map<String, dynamic>> photos = {};
      
      for (var data in users) {
        final noKk = data['noKK']?.toString() ?? '';
        final code = data['code']?.toString() ?? '';
        final kkId = noKk.isNotEmpty ? noKk : (code.isNotEmpty ? code : (data['uid'] ?? ''));
        
        if (kkId.isNotEmpty) {
           if (!photos.containsKey(kkId)) {
             photos[kkId] = {
               'foto': data['foto'],
               'photoUrl': data['photoUrl'],
             };
           }
           
           if (data['statusHubungan'] == 'Kepala Keluarga') {
             photos[kkId]!['foto'] = data['foto'] ?? photos[kkId]!['foto'];
             photos[kkId]!['photoUrl'] = data['photoUrl'] ?? photos[kkId]!['photoUrl'];
           }
        }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isActiveExemption(Map<String, dynamic> data) {
    final now = DateTime.now();
    DateTime? startDate;
    if (data['startDate'] is String) startDate = DateTime.tryParse(data['startDate'])?.toLocal();
    
    DateTime? endDate;
    if (data['endDate'] is String) endDate = DateTime.tryParse(data['endDate'])?.toLocal();
    
    if (startDate == null) return false;
    if (startDate.isAfter(now)) return false;
    if (endDate != null && endDate.isBefore(now)) return false;
    return true;
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Permanen';
    if (ts is String) {
      final dt = DateTime.tryParse(ts)?.toLocal();
      if (dt != null) {
        return DateFormat('dd MMM yyyy', 'id').format(dt);
      }
    }
    return 'Invalid Date';
  }

  Future<void> _showFormDialog([Map<String, dynamic>? editData]) async {
    Map<String, dynamic>? selectedKk;
    Map<String, dynamic>? selectedTariff;
    DateTime startDate = DateTime.now();
    DateTime? endDate;
    final reasonController = TextEditingController();
    bool isPermanent = true;

    if (editData != null) {
      selectedKk = {'id': editData['kkId'], 'name': editData['kkName']};
      selectedTariff = {'id': editData['tariffId'], 'name': editData['tariffName']};
      
      final dynamic sDate = editData['startDate'];
      if (sDate is String) startDate = DateTime.tryParse(sDate)?.toLocal() ?? DateTime.now();

      final dynamic eDate = editData['endDate'];
      if (eDate is String) endDate = DateTime.tryParse(eDate)?.toLocal();
      
      isPermanent = endDate == null;
      reasonController.text = editData['reason'] ?? '';
    }

    final users = await ApiService.getUsers(widget.villageId);

    // Filter hanya Kepala Keluarga
    final kkDocs = users.where((data) {
      final statusHubungan = data['statusHubungan']?.toString();
      if (statusHubungan == null || statusHubungan.isEmpty) {
        final familyId = data['familyId']?.toString();
        final code = data['code']?.toString();
        return familyId == null || familyId.isEmpty || familyId == code;
      }
      return statusHubungan == 'Kepala Keluarga';
    }).toList();

    final kkList = kkDocs.map((data) {
      final noKk = data['noKK']?.toString() ?? '';
      final code = data['code']?.toString() ?? '';
      final kkId = noKk.isNotEmpty ? noKk : (code.isNotEmpty ? code : (data['uid'] ?? ''));
      return <String, dynamic>{
        'id': kkId, 
        'name': data['name'] ?? 'No Name',
        'foto': data['foto'],
        'photoUrl': data['photoUrl'],
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final tariffs = await ApiService.getTariffs(widget.villageId);
    final activeTariffs = tariffs.where((t) => t['isActive'] == true).toList();

    final tariffList = activeTariffs.map((data) {
      return <String, dynamic>{'id': data['id'], 'name': data['name'] ?? data['id']};
    }).toList();

    if (!mounted) return;

    InputDecoration inputDeco(IconData icon) => InputDecoration(
      prefixIcon: Icon(icon, color: Colors.black45, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppModalDialog(
          title: editData == null ? 'Tambah Pembebasan' : 'Edit Pembebasan',
          headerIcon: Icons.person_off_outlined,
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih KK', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final result = await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => _KkSearchSheet(kkList: kkList),
                      );
                      if (result != null) setDialogState(() => selectedKk = result);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: selectedKk != null
                            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.family_restroom, color: Colors.black45, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedKk != null
                                  ? selectedKk!['name'] as String
                                  : 'Ketuk untuk cari keluarga...',
                              style: TextStyle(
                                color: selectedKk != null ? Colors.black87 : Colors.black38,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            selectedKk != null ? Icons.check_circle : Icons.search,
                            color: selectedKk != null ? AppTheme.primaryColor : Colors.black38,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text('Jenis Iuran yang Dibebaskan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButton<String>(
                      value: selectedTariff?['id'] as String?,
                      hint: const Text('Pilih Jenis Iuran'),
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down),
                      items: tariffList.map((t) => DropdownMenuItem<String>(
                        value: t['id'] as String,
                        child: Text(t['name'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final t = tariffList.firstWhere((element) => element['id'] == val);
                          setDialogState(() => selectedTariff = t);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Alasan Pembebasan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: inputDeco(Icons.note_outlined).copyWith(hintText: 'Contoh: Dhuafa, Lansia, Musibah'),
                  ),
                  const SizedBox(height: 16),

                  const Text('Tanggal Mulai', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2099),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, color: Colors.black45, size: 20),
                        const SizedBox(width: 12),
                        Text(DateFormat('dd MMM yyyy', 'id').format(startDate)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    value: isPermanent,
                    onChanged: (val) => setDialogState(() {
                      isPermanent = val;
                      if (val) endDate = null;
                    }),
                    title: const Text('Pembebasan Permanen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Matikan untuk atur tanggal berakhir'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppTheme.primaryColor,
                  ),

                  if (!isPermanent) ...[
                    const Text('Tanggal Berakhir', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: startDate,
                          lastDate: DateTime(2099),
                        );
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          const Icon(Icons.event_busy, color: Colors.black45, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            endDate != null ? DateFormat('dd MMM yyyy', 'id').format(endDate!) : 'Pilih tanggal berakhir',
                            style: TextStyle(color: endDate != null ? Colors.black87 : Colors.black38),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedKk == null || selectedTariff == null) {
                              CustomToast.show(context, 'Harap pilih KK dan Jenis Iuran');
                              return;
                            }
                            if (!isPermanent && endDate == null) {
                              CustomToast.show(context, 'Harap pilih tanggal berakhir atau centang Permanen');
                              return;
                            }
                            final data = {
                              'id': editData?['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              'kkId': selectedKk!['id'],
                              'kkName': selectedKk!['name'],
                              'tariffId': selectedTariff!['id'],
                              'tariffName': selectedTariff!['name'],
                              'reason': reasonController.text.trim(),
                              'startDate': startDate.toIso8601String(),
                              'endDate': isPermanent ? null : endDate!.toIso8601String(),
                              'villageId': widget.villageId,
                              'createdAt': DateTime.now().toIso8601String(),
                            };
                            
                            EasyLoading.show(status: 'Menyimpan...');
                            bool success = false;
                            try {
                              if (editData == null) {
                                success = await ApiService.createExemption(data);
                              } else {
                                success = await ApiService.updateExemption(editData['id'].toString(), data);
                              }
                              if (success && context.mounted) {
                              if (mounted) CustomToast.show(context, 'Data berhasil disimpan');
                                Navigator.pop(context);
                                _loadData();
                                CustomToast.show(context, 'Pembebasan iuran berhasil disimpan');
                              } else if (context.mounted) {
                                CustomToast.show(context, 'Gagal menyimpan pembebasan iuran', isError: true);
                              }
                            } catch (e) {
                              EasyLoading.showError('Terjadi kesalahan');
                            } finally {
                              EasyLoading.dismiss();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    reasonController.dispose();
  }

  Future<void> _deleteExemption(String docId, String kkName, String tariffName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Hapus Pembebasan?',
        headerIcon: Icons.warning_amber_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('KK "$kkName" akan kembali dikenakan iuran "$tariffName". Yakin hapus?'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      EasyLoading.show(status: 'Menghapus...');
      try {
        bool success = await ApiService.deleteExemption(docId);
        if (success && mounted) {
          _loadData();
        }
        if (mounted) CustomToast.show(context, 'Data berhasil dihapus');
      } catch (e) {
        EasyLoading.showError('Gagal menghapus');
      } finally {
        EasyLoading.dismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration searchDeco = InputDecoration(
      prefixIcon: const Icon(Icons.search, color: Colors.black45),
      hintText: 'Cari nama KK atau jenis iuran...',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: CustomGradientAppBar(
        titleText: 'Pembebasan Iuran',
        actions: [
          if (widget.permissions['create'] == true)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
              onPressed: _showFormDialog,
              tooltip: 'Tambah Pembebasan',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: searchDeco,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _exemptionsFuture,
              builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                  }
                  final docs = snapshot.data ?? [];
                  
                  // Sort locally by createdAt descending
                  final sortedDocs = List<dynamic>.from(docs)
                    ..sort((a, b) {
                      final dataA = a as Map<String, dynamic>;
                      final dataB = b as Map<String, dynamic>;
                      final timeA = dataA['createdAt']?.toString() ?? '';
                      final timeB = dataB['createdAt']?.toString() ?? '';
                      return timeB.compareTo(timeA); // descending
                    });

                  final filtered = sortedDocs.where((d) {
                    final data = d as Map<String, dynamic>;
                    final kkName = (data['kkName'] ?? '').toString().toLowerCase();
                    final tariffName = (data['tariffName'] ?? '').toString().toLowerCase();
                    return kkName.contains(_searchQuery) || tariffName.contains(_searchQuery);
                  }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Belum Ada Pembebasan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        const Text('Tap + untuk menambah pembebasan iuran', style: TextStyle(color: Colors.black45)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index] as Map<String, dynamic>;
                    final docId = data['id'].toString();
                    final isActive = _isActiveExemption(data);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.25) : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: widget.permissions['edit'] == true ? () => _showFormDialog(data) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserAvatar(
                                  userData: {
                                    ...data,
                                    'name': data['kkName'],
                                    if (_kkPhotos.containsKey(data['kkId']))
                                      ..._kkPhotos[data['kkId']]!,
                                  },
                                  radius: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(data['kkName'] ?? '-',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B))),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              isActive ? 'Aktif' : 'Berakhir',
                                              style: TextStyle(
                                                fontSize: 11, fontWeight: FontWeight.bold,
                                                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Iuran: ${data['tariffName'] ?? '-'}',
                                          style: TextStyle(fontSize: 13, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                                      if ((data['reason'] ?? '').toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(data['reason'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        const Icon(Icons.calendar_today, size: 12, color: Colors.black38),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_formatDate(data['startDate'])} → ${_formatDate(data['endDate'])}',
                                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                                if (widget.permissions['delete'] == true)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    onPressed: () => _deleteExemption(docId, data['kkName'] ?? '-', data['tariffName'] ?? '-'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom sheet pencarian KK
// ─────────────────────────────────────────────────────────────
class _KkSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> kkList;
  const _KkSearchSheet({required this.kkList});

  @override
  State<_KkSearchSheet> createState() => _KkSearchSheetState();
}

class _KkSearchSheetState extends State<_KkSearchSheet> {
  String _query = '';
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.kkList;
  }

  void _onSearch(String q) {
    setState(() {
      _query = q.toLowerCase();
      _filtered = widget.kkList
          .where((kk) => (kk['name'] as String).toLowerCase().contains(_query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Pilih Kepala Keluarga',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(height: 12),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Cari nama KK...',
                    prefixIcon: const Icon(Icons.search, color: Colors.black45),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // List
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('Tidak ditemukan', style: TextStyle(color: Colors.black45)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final kk = _filtered[index];
                          return ListTile(
                            leading: UserAvatar(
                              userData: kk,
                              radius: 20,
                            ),
                            title: Text(kk['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () => Navigator.pop(context, kk),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
