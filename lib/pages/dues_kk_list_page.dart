import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/resident_pdf_export.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/main.dart'; // import routeObserver
import 'dues_payment_page.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/widgets/user_avatar.dart';

class DuesKkListPage extends StatefulWidget {
  final String villageId;
  final String tariffId;
  final Map<String, dynamic> tariffData;
  final List<String> currentUserRoles;
  final Map<String, bool>? permissions;

  const DuesKkListPage({
    super.key,
    required this.villageId,
    required this.tariffId,
    required this.tariffData,
    required this.currentUserRoles,
    this.permissions,
  });

  @override
  State<DuesKkListPage> createState() => _DuesKkListPageState();
}

class _DuesKkListPageState extends State<DuesKkListPage>
    with SingleTickerProviderStateMixin, RouteAware {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  bool get _canCreate => widget.permissions != null
      ? (widget.permissions!['create'] == true)
      : (widget.currentUserRoles.contains('SUPER_ADMIN') || widget.currentUserRoles.contains('ADMIN_DESA'));

  bool get _canSeePrivateData {
    final permissions = widget.permissions ?? {};
    final roles = widget.currentUserRoles;
    return permissions['edit'] == true ||
        permissions['add'] == true ||
        permissions['create'] == true ||
        roles.contains('SUPER_ADMIN') ||
        roles.contains('ADMIN_DESA');
  }

  String _filterType = 'ALL';

  late Future<List<dynamic>> _usersFuture;
  late Future<List<dynamic>> _journalsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _usersFuture = ApiService.getUsers(widget.villageId);
      _journalsFuture = ApiService.getDuesJournals(widget.villageId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadData();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<Set<String>> _fetchExemptedKkIds() async {
    try {
      final now = DateTime.now();
      final exemptions = await ApiService.getExemptions(widget.villageId);
      final Set<String> exempted = {};
      
      for (final data in exemptions) {
        if (data['tariffId'] != widget.tariffId) continue;
        
        DateTime? startTs;
        if (data['startDate'] is String) startTs = DateTime.tryParse(data['startDate'])?.toLocal();
        
        DateTime? endTs;
        if (data['endDate'] is String) endTs = DateTime.tryParse(data['endDate'])?.toLocal();

        if (startTs == null) continue;
        if (startTs.compareTo(now) > 0) continue;
        if (endTs != null && endTs.compareTo(now) < 0) continue;
        
        exempted.add(data['kkId'] as String);
      }
      return exempted;
    } catch (_) {
      return {};
    }
  }

  Future<void> _shareBukuKasKhususPdf() async {
    try {
      final journals = await ApiService.getDuesJournals(widget.villageId);
      final docs = journals.where((data) => 
        data['tariffId'] == widget.tariffId && data['journalType'] == 'KHUSUS'
      ).toList();

      docs.sort((a, b) {
        DateTime? aTime;
        if (a['timestamp'] is String) aTime = DateTime.tryParse(a['timestamp'])?.toLocal();
        
        DateTime? bTime;
        if (b['timestamp'] is String) bTime = DateTime.tryParse(b['timestamp'])?.toLocal();

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      final transactions = <Map<String, dynamic>>[];
      int totalIncome = 0;
      int totalExpense = 0;

      for (final data in docs) {
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final category = data['category'] ?? 'DUES_INCOME';
        final isIncome = category.toString().contains('INCOME');
        
        DateTime? ts;
        if (data['timestamp'] is String) ts = DateTime.tryParse(data['timestamp'])?.toLocal();
        
        final dateText = ts != null
            ? DateFormat('dd MMM yyyy HH:mm').format(ts)
            : '-';
        if (isIncome) {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
        transactions.add({
          'description': data['description'] ?? 'Transaksi',
          'dateText': dateText,
          'typeLabel': isIncome ? 'Pemasukan' : 'Pengeluaran',
          'amount': amount,
          'isIncome': isIncome,
        });
      }

      final fileName =
          'Buku_Kas_Khusus_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf';
      await shareFinancialJournalPdf(
        title: widget.tariffData['name'] ?? 'Buku Kas Khusus',
        subtitle: 'Ringkasan transaksi buku kas khusus',
        fileName: fileName,
        transactions: transactions,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );

      if (mounted) {
        CustomToast.show(context, 'PDF buku kas khusus berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membuat PDF buku kas khusus: $e', isError: true);
      }
    }
  }

  Future<void> _showAddManualJournalDialog() async {
    if (!_canCreate) return;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'MANUAL_INCOME';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppModalDialog(
              title: 'Jurnal Manual Khusus',
              headerIcon: Icons.account_balance_wallet,
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setDialogState(() => type = 'MANUAL_INCOME'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: type == 'MANUAL_INCOME'
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: type == 'MANUAL_INCOME'
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Pemasukan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type == 'MANUAL_INCOME'
                                        ? Colors.green.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setDialogState(() => type = 'MANUAL_EXPENSE'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: type == 'MANUAL_EXPENSE'
                                      ? Colors.red.shade100
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: type == 'MANUAL_EXPENSE'
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Pengeluaran',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type == 'MANUAL_EXPENSE'
                                        ? Colors.red.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Keterangan',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal (Rp)',
                          prefixIcon: const Icon(Icons.payments),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.isEmpty ||
                                amountController.text.isEmpty) {
                              CustomToast.show(context, 'Keterangan dan Nominal tidak boleh kosong!',);
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == 'MANUAL_INCOME'
                                ? Colors.green
                                : Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Simpan Jurnal',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      final amount = int.tryParse(amountController.text) ?? 0;
      final currentUser = FirebaseAuth.instance.currentUser;

      try {
        final bool success = await ApiService.createDuesJournal({
          'villageId': widget.villageId,
          'tariffId': widget.tariffId,
          'journalType': 'KHUSUS',
          'amount': type == 'MANUAL_EXPENSE' ? -amount : amount,
          'category': type,
          'description': titleController.text,
          'timestamp': DateTime.now().toIso8601String(),
          'recordedBy': currentUser?.uid ?? 'unknown',
          'kkId': '',
          'period': 'MANUAL',
          'type': widget.tariffData['type'] ?? 'Manual',
        });
        
        if (success && mounted) {
          CustomToast.show(context, 'Jurnal khusus berhasil ditambahkan.');
          _loadData(); // reload
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan jurnal: $e')));
        }
      }
    }
  }



  Widget _buildFilterChip(String type, String label) {
    final isSelected = _filterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => _filterType = type);
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.tariffData['name'] ?? 'Detail Iuran'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_rounded,
              size: 24,
              color: Color(0xFF1E293B),
            ),
            onPressed: _shareBukuKasKhususPdf,
            tooltip: 'Bagikan PDF Buku Kas Khusus',
          ),
          if (_canCreate)
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                size: 28,
                color: Color(0xFF1E293B),
              ),
              onPressed: _showAddManualJournalDialog,
              tooltip: 'Tambah Jurnal Khusus',
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Tagihan Warga', icon: Icon(Icons.people)),
            Tab(
              text: 'Buku Kas Khusus',
              icon: Icon(Icons.account_balance_wallet),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWargaTab(), _buildBukuKasTab()],
      ),
    );
  }

  Widget _buildWargaTab() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama atau No. KK...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),

        // List of Warga
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Terjadi kesalahan memuat data warga.'),
                );
              }

              var users = snapshot.data ?? [];

              // Sembunyikan SUPER_ADMIN
              users = users.where((data) {
                final roles = data['roles'];
                if (roles is List) return !roles.contains('SUPER_ADMIN');
                if (roles is String) return !roles.contains('SUPER_ADMIN');
                return true;
              }).toList();

              // Filter to get only Head of Family (KK)
              var kkUsers = users.where((data) {
                final statusHubungan = data['statusHubungan']?.toString();
                // Jika data lama tidak memiliki statusHubungan, anggap dia KK jika familyId sama dengan code
                if (statusHubungan == null || statusHubungan.isEmpty) {
                  final familyId = data['familyId']?.toString();
                  final code = data['code']?.toString();
                  return familyId == null ||
                      familyId.isEmpty ||
                      familyId == code;
                }
                return statusHubungan == 'Kepala Keluarga';
              }).toList();

              // Sort alphabetically
              kkUsers.sort((a, b) {
                final nameA = a['name']?.toString().toLowerCase() ?? '';
                final nameB = b['name']?.toString().toLowerCase() ?? '';
                return nameA.compareTo(nameB);
              });

              // Apply Search Filter
              if (_searchQuery.isNotEmpty) {
                kkUsers = kkUsers.where((data) {
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final code = data['code']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQuery) ||
                      code.contains(_searchQuery);
                }).toList();
              }

              if (kkUsers.isEmpty) {
                return const Center(
                  child: Text(
                    'Tidak ada warga / KK ditemukan.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return FutureBuilder<Set<String>>(
                future: _fetchExemptedKkIds(),
                builder: (context, exemptSnap) {
                  final exemptedKkIds = exemptSnap.data ?? {};

                  // Tampilkan semua user, tapi tandai yang dibebaskan
                  final displayUsers = kkUsers.toList();

                  if (displayUsers.isEmpty) {
                    return const Center(
                      child: Text(
                        'Tidak ada warga (atau semua dibebaskan).',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: displayUsers.length,
                    itemBuilder: (context, index) {
                      final data = displayUsers[index] as Map<String, dynamic>;
                      final name = data['name'] ?? 'Tanpa Nama';
                      final noKkStr = (data['noKK'] ?? '').toString();
                      final oldCodeStr = (data['uniqueCode'] ?? data['code'] ?? '').toString();
                      final code = noKkStr.isNotEmpty
                          ? noKkStr
                          : (oldCodeStr.isNotEmpty ? oldCodeStr : '-');
                      final uidStr = (data['uid'] ?? '').toString();
                      final familyId = (data['familyId'] ?? data['uid'] ?? '').toString();
                      
                      final isExempted = (familyId.isNotEmpty && exemptedKkIds.contains(familyId)) ||
                                         (noKkStr.isNotEmpty && exemptedKkIds.contains(noKkStr)) ||
                                         (oldCodeStr.isNotEmpty && exemptedKkIds.contains(oldCodeStr)) ||
                                         (uidStr.isNotEmpty && exemptedKkIds.contains(uidStr));

                      DateTime? parsedUserDate;
                      final dynamic userRawTime = data['createdAt'];
                      if (userRawTime is String) {
                        parsedUserDate = DateTime.tryParse(userRawTime)?.toLocal();
                      } else if (userRawTime is int) {
                        parsedUserDate = DateTime.fromMillisecondsSinceEpoch(
                          userRawTime,
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: UserAvatar(
                            userData: data,
                            radius: 20,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isExempted ? Colors.grey : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isExempted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'DIBEBASKAN',
                                    style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            _canSeePrivateData
                                ? 'No. KK: $code'
                                : (oldCodeStr.isNotEmpty ? 'Kode: $oldCodeStr' : 'No. KK: ****************'),
                            style: TextStyle(
                              color: isExempted ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          trailing: isExempted
                              ? null
                              : const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                          onTap: isExempted
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DuesPaymentPage(
                                        villageId: widget.villageId,
                                        tariffId: widget.tariffId,
                                        tariffData: widget.tariffData,
                                        kkId: familyId,
                                        kkName: name,
                                        kkNumber: code,
                                        houseCode: oldCodeStr,
                                        currentUserRoles: widget.currentUserRoles,
                                        permissions: widget.permissions,
                                        userCreatedAt: parsedUserDate,
                                      ),
                                    ),
                                  );
                                  _loadData();
                                },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBukuKasTab() {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua Transaksi'),
                const SizedBox(width: 8),
                _buildFilterChip('INCOME', 'Pemasukan'),
                const SizedBox(width: 8),
                _buildFilterChip('EXPENSE', 'Pengeluaran'),
              ],
            ),
          ),
        ),

        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _journalsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error memuat buku kas: ${snapshot.error}'),
                );
              }

              final allJournals = snapshot.data ?? [];
              var docs = allJournals.where((data) => 
                data['tariffId'] == widget.tariffId && 
                data['journalType'] == 'KHUSUS'
              ).toList();

              // Sort locally
              docs.sort((a, b) {
                final aData = a as Map<String, dynamic>;
                final bData = b as Map<String, dynamic>;
                
                DateTime? aTime;
                if (aData['timestamp'] != null) {
                  aTime = DateTime.tryParse(aData['timestamp'].toString())?.toLocal();
                } else if (aData['createdAt'] != null) {
                  aTime = DateTime.tryParse(aData['createdAt'].toString())?.toLocal();
                }
                
                DateTime? bTime;
                if (bData['timestamp'] != null) {
                  bTime = DateTime.tryParse(bData['timestamp'].toString())?.toLocal();
                } else if (bData['createdAt'] != null) {
                  bTime = DateTime.tryParse(bData['createdAt'].toString())?.toLocal();
                }

                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // descending
              });

              int totalIncome = 0;
              int totalExpense = 0;

              final filteredDocs = docs.where((doc) {
                final data = doc as Map<String, dynamic>;
                final amount = (data['amount'] as num?)?.toInt() ?? 0;
                final isIncome = amount >= 0;

                if (isIncome) {
                  totalIncome += amount;
                } else {
                  totalExpense += amount.abs();
                }

                if (_filterType == 'INCOME' && !isIncome) return false;
                if (_filterType == 'EXPENSE' && isIncome) return false;
                return true;
              }).toList();

              return Stack(
                children: [
                  Column(
                    children: [
                      if (_filterType == 'ALL')
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pemasukan',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      format.format(totalIncome),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pengeluaran',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      format.format(totalExpense),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Saldo Akhir',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      format.format(totalIncome - totalExpense),
                                      style: TextStyle(
                                        color: (totalIncome - totalExpense) >= 0
                                            ? AppTheme.primaryColor
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: filteredDocs.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada transaksi di kas ini.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 80,
                                ),
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  final data = filteredDocs[index] as Map<String, dynamic>;

                                  final amount =
                                      (data['amount'] as num?)?.toInt() ?? 0;
                                  
                                  DateTime? ts;
                                  if (data['timestamp'] != null) {
                                    ts = DateTime.tryParse(data['timestamp'].toString())?.toLocal();
                                  } else if (data['createdAt'] != null) {
                                    ts = DateTime.tryParse(data['createdAt'].toString())?.toLocal();
                                  }
                                  
                                  final dateStr = ts != null
                                      ? DateFormat(
                                          'dd MMM yyyy HH:mm',
                                        ).format(ts)
                                      : '-';
                                  final isIncome = amount >= 0;

                                  final desc =
                                      data['description'] ?? 'Setoran Warga';

                                  final absAmount = amount.abs();

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isIncome
                                            ? Colors.green.shade200
                                            : Colors.red.shade200,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isIncome
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        child: Icon(
                                          isIncome
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: isIncome
                                              ? Colors.green.shade800
                                              : Colors.red.shade800,
                                        ),
                                      ),
                                      title: Text(
                                        desc,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        dateStr,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isIncome ? '+' : '-'} ${format.format(absAmount)}',
                                            style: TextStyle(
                                              color: isIncome
                                                  ? Colors.green.shade800
                                                  : Colors.red.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),

                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
