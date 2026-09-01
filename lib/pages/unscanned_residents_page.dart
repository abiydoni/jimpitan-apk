import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';

class UnscannedResidentsPage extends StatefulWidget {
  final String villageId;
  final Map<String, dynamic>? permissions;
  final List<dynamic>? currentUserRoles;

  const UnscannedResidentsPage({
    super.key,
    required this.villageId,
    this.permissions,
    this.currentUserRoles,
  });

  @override
  State<UnscannedResidentsPage> createState() => _UnscannedResidentsPageState();
}

class _UnscannedResidentsPageState extends State<UnscannedResidentsPage> {
  bool get _canSeePrivateData {
    final permissions = widget.permissions ?? {};
    final roles = (widget.currentUserRoles ?? []).map((r) => r.toString()).toList();
    return permissions['edit'] == true ||
        permissions['add'] == true ||
        roles.contains('SUPER_ADMIN') ||
        roles.contains('ADMIN_DESA');
  }

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _users = [];
  List<dynamic> _history = [];
  List<dynamic> _journals = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Realtime polling
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchDataSilent();
    });
  }

  Future<void> _fetchDataSilent() async {
    try {
      final history = await ApiService.getJimpitanHistory(widget.villageId);
      final journals = await ApiService.getDuesJournals(widget.villageId);
      if (mounted) {
        setState(() {
          _history = history;
          _journals = journals;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await ApiService.getUsers(widget.villageId);
      final history = await ApiService.getJimpitanHistory(widget.villageId);
      final journals = await ApiService.getDuesJournals(widget.villageId);
      if (mounted) {
        setState(() {
          _users = users.where((u) => u['status'] == 'ACTIVE').toList();
          _history = history;
          _journals = journals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Warga Belum Scan'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pilih Tanggal',
            onPressed: () => _selectDate(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Header tanggal dengan gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_off,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isToday
                              ? 'Belum Scan — Hari Ini'
                              : 'Belum Scan — ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday
                              ? 'Data diperbarui secara realtime'
                              : DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                                  .format(_selectedDate),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_calendar,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM').format(_selectedDate),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama kepala keluarga...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // Stream builder — stream KK (Kepala Keluarga)
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : Builder(
              builder: (context) {
                final allUsers = _users;

                // Filter hanya Kepala Keluarga
                final kkUsers = allUsers.where((data) {
                  final statusHubungan =
                      data['statusHubungan']?.toString() ?? '';
                  if (statusHubungan.isNotEmpty) {
                    return statusHubungan == 'Kepala Keluarga';
                  }
                  final familyId = data['familyId']?.toString() ?? '';
                  final code = data['code']?.toString() ?? '';
                  return familyId.isEmpty || familyId == code;
                }).toList();

                final startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
                final endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
                
                final scannedIds = <String>{};
                final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

                final history = _history;
                final journals = _journals; 

                // Kopi paste langsung dari scan_report_page.dart
                final filteredDocs = history.where((data) {
                  if (data['date'] != null && data['date'].toString().isNotEmpty) {
                    return data['date'].toString().startsWith(selectedDateStr);
                  }

                  DateTime? dt;
                  if (data['timestamp'] is String) dt = DateTime.tryParse(data['timestamp']);
                  if (dt == null) return false;
                  return dt.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                         dt.isBefore(endDate.add(const Duration(seconds: 1)));
                }).toList();

                for (var data in filteredDocs) {
                  final uidStr = data['scannedBy']?.toString();
                  if (uidStr != null && uidStr.isNotEmpty) {
                    scannedIds.add(uidStr);
                  }
                  final kkStr = data['kkId']?.toString();
                  if (kkStr != null && kkStr.isNotEmpty) {
                    scannedIds.add(kkStr);
                  }
                }

                // ALSO check DuesJournal (Pembayaran Manual / Tagihan Harian)
                if (journals.isNotEmpty) {
                  for (var data in journals) {
                    final type = data['type']?.toString() ?? '';
                    final dateStr = data['date']?.toString() ?? '';
                    final paidDates = data['paidDates'];
                    
                    bool isMatch = false;
                    if (paidDates != null && paidDates is List) {
                      if (paidDates.contains(selectedDateStr)) {
                        isMatch = true;
                      }
                    } else if (dateStr.startsWith(selectedDateStr)) {
                       if (type == 'Harian' || type == 'Jimpitan' || type == 'Jimpitan Default') {
                          isMatch = true;
                       }
                    }

                    if (isMatch) { // Menyembunyikan yang nilainya lebih besar dari nol
                      final kkStr = data['kkId']?.toString();
                      if (kkStr != null && kkStr.isNotEmpty) {
                        scannedIds.add(kkStr);
                      }
                    }
                  }
                }


                    // Filter KK yang belum scan:
                    final unscanned = kkUsers.where((data) {
                  final uniqueCode = data['uniqueCode']?.toString() ?? '';
                  final kkId = data['kkId']?.toString() ?? '';
                  final code = data['code']?.toString() ?? '';
                  final noKK = data['noKK']?.toString() ?? '';
                  final familyId = data['familyId']?.toString() ?? '';
                  final id = data['id']?.toString() ?? '';

                  final hasScanned = (uniqueCode.isNotEmpty && scannedIds.contains(uniqueCode)) ||
                      (kkId.isNotEmpty && scannedIds.contains(kkId)) ||
                      (code.isNotEmpty && scannedIds.contains(code)) ||
                      (noKK.isNotEmpty && scannedIds.contains(noKK)) ||
                      (familyId.isNotEmpty && scannedIds.contains(familyId)) ||
                      (id.isNotEmpty && scannedIds.contains(id));

                  if (hasScanned) return false;

                      if (_searchQuery.isEmpty) return true;
                      final name =
                          (data['name'] as String? ?? '').toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();

                    // Sort by name
                    unscanned.sort((a, b) {
                      final aName = (a['name'] as String? ?? '');
                      final bName = (b['name'] as String? ?? '');
                      return aName.compareTo(bName);
                    });

                    final totalKK = kkUsers.length;
                    final unscannedCount = unscanned.length;
                    final scannedCount = totalKK - unscannedCount;

                    if (unscanned.isEmpty) {
                      return _buildAllDoneState(scannedCount, totalKK,
                          _searchQuery.isNotEmpty);
                    }

                    return Column(
                      children: [
                        // Stats bar
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              _statChip(
                                  label: 'Belum Scan',
                                  value: unscannedCount,
                                  color: Colors.orange),
                              const SizedBox(width: 12),
                              _statChip(
                                  label: 'Sudah Scan',
                                  value: scannedCount,
                                  color: Colors.green),
                              const SizedBox(width: 12),
                              _statChip(
                                  label: 'Total KK',
                                  value: totalKK,
                                  color: Colors.blue),
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: unscanned.length,
                            itemBuilder: (context, index) {
                              final data = unscanned[index];
                              final name =
                                  data['name'] as String? ?? '-';
                              final noKK = (data['noKK'] as String? ?? '')
                                  .isNotEmpty
                                  ? data['noKK'] as String
                                  : (data['code'] as String? ?? '-');
                              final address =
                                  data['address'] as String? ??
                                      data['rt'] as String? ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.orange.shade100),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                  leading: UserAvatar(
                                    userData: data,
                                    radius: 20,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (noKK.isNotEmpty && _canSeePrivateData)
                                        Text(
                                          'No. KK: $noKK',
                                          style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11),
                                        ),
                                      if (address.isNotEmpty)
                                        Text(
                                          address,
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  isThreeLine: address.isNotEmpty,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Belum',
                                      style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      {required String label, required int value, required Color color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAllDoneState(int scannedCount, int total, bool isFiltered) {
    if (isFiltered) {
      return const Center(
          child: Text('Tidak ada KK yang cocok dengan pencarian.'));
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle,
                color: Colors.green.shade400, size: 64),
          ),
          const SizedBox(height: 20),
          const Text(
            'Semua KK Sudah Scan!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            '$scannedCount dari $total KK sudah discan pada hari ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
