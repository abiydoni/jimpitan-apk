import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/resident_pdf_export.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/main.dart'; // import routeObserver
import 'package:jimpitan/utils/custom_toast.dart';

class FinancialJournalsPage extends StatefulWidget {
  final String villageId;
  final List<String> currentUserRoles;

  final Map<String, bool>? permissions;

  const FinancialJournalsPage({
    super.key,
    required this.villageId,
    required this.currentUserRoles,
    this.permissions,
  });

  @override
  State<FinancialJournalsPage> createState() => _FinancialJournalsPageState();
}

class _FinancialJournalsPageState extends State<FinancialJournalsPage> with RouteAware {
  bool get _canCreate => widget.permissions != null
      ? (widget.permissions!['create'] == true)
      : (widget.currentUserRoles.contains('SUPER_ADMIN') || widget.currentUserRoles.contains('ADMIN_DESA'));

  String _filterType = 'ALL'; // ALL, INCOME, EXPENSE
  late Future<List<dynamic>> _journalsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _loadData() {
    setState(() {
      _journalsFuture = ApiService.getDuesJournals(widget.villageId).then((data) {
        return data.where((item) => item['journalType'] == 'UMUM').toList();
      });
    });
  }

  Future<void> _shareBukuKasUmumPdf() async {
    try {
      final allJournals = await ApiService.getDuesJournals(widget.villageId);
      final docs = allJournals.where((item) => item['journalType'] == 'UMUM').toList();

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

      for (final doc in docs) {
        final data = doc as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final category = data['category'] ?? 'MANUAL_INCOME';
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
          'Buku_Kas_Umum_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf';
      await shareFinancialJournalPdf(
        title: 'Buku Kas Umum',
        subtitle: 'Ringkasan transaksi buku kas umum desa',
        fileName: fileName,
        transactions: transactions,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );

      if (mounted) {
        CustomToast.show(context, 'PDF buku kas umum berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membuat PDF buku kas umum: $e', isError: true);
      }
    }
  }

  Future<void> _showAddManualJournalDialog() async {
    if (!_canCreate) return;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'MANUAL_INCOME'; // MANUAL_INCOME, MANUAL_EXPENSE

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppModalDialog(
              title: 'Jurnal Manual Umum',
              headerIcon: Icons.account_balance_wallet,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => type = 'MANUAL_INCOME'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                      hintText: type == 'MANUAL_INCOME'
                          ? 'Cth: Pemasukan dari sumbangan'
                          : 'Cth: Pembelian perlengkapan',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal (Rp)',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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
            );
          },
        );
      },
    );

    if (result == true) {
      final amount = int.tryParse(amountController.text) ?? 0;
      final currentUser = FirebaseAuth.instance.currentUser;

      EasyLoading.show(status: 'Menyimpan...');
      try {
        await ApiService.createDuesJournal({
          'villageId': widget.villageId,
          'amount': type == 'MANUAL_EXPENSE' ? -amount : amount,
          'category': type, // MANUAL_INCOME, MANUAL_EXPENSE
          'description': titleController.text,
          'timestamp': DateTime.now().toIso8601String(),
          'recordedBy': currentUser?.uid ?? 'unknown',
          'journalType': 'UMUM',
          'tariffId': 'NONE',
          'kkId': '',
          'period': 'MANUAL',
          'type': 'Umum',
        });
        if (mounted) {
          CustomToast.show(context, 'Jurnal manual berhasil ditambahkan.');
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan jurnal: $e')));
        }
      } finally {
        EasyLoading.dismiss();
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Buku Kas Umum'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_rounded,
              size: 24,
              color: Color(0xFF1E293B),
            ),
            onPressed: _shareBukuKasUmumPdf,
            tooltip: 'Bagikan PDF Buku Kas Umum',
          ),
          if (_canCreate)
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                size: 28,
                color: Color(0xFF1E293B),
              ),
              onPressed: _showAddManualJournalDialog,
              tooltip: 'Tambah Jurnal',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
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
                  return const Center(
                    child: Text('Terjadi kesalahan memuat data.'),
                  );
                }

                var docs = snapshot.data ?? [];

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

                // Filter & Hitung Saldo
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

                return Column(
                  children: [
                    // Saldo Card
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
                                'Belum ada catatan jurnal umum.',
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
                                final doc = filteredDocs[index];
                                final data = doc as Map<String, dynamic>;

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

                                final desc = data['description'] ?? 'Pemasukan';

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
                );
              },
            ),
          ),
        ],
      ),
    );
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
}
