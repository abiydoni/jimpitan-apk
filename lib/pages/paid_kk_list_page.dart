import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'dues_payment_page.dart';
import 'package:jimpitan/widgets/user_avatar.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/utils/dues_status_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PaidKkListPage extends StatefulWidget {
  final String villageId;
  final String tariffId;
  final Map<String, dynamic> tariffData;
  final List<String> currentUserRoles;
  final Map<String, bool>? permissions;

  const PaidKkListPage({
    super.key,
    required this.villageId,
    required this.tariffId,
    required this.tariffData,
    required this.currentUserRoles,
    this.permissions,
  });

  @override
  State<PaidKkListPage> createState() => _PaidKkListPageState();
}

class _PaidKkListPageState extends State<PaidKkListPage> {
  late int _selectedMonth;
  late int _selectedYear;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late Future<List<dynamic>> _usersFuture;
  late Future<List<dynamic>> _journalsFuture;

  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  bool get _canSeePrivateData {
    final permissions = widget.permissions ?? {};
    final roles = widget.currentUserRoles;
    return permissions['edit'] == true ||
        permissions['add'] == true ||
        permissions['create'] == true ||
        roles.contains('SUPER_ADMIN') ||
        roles.contains('ADMIN_DESA');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _usersFuture = ApiService.getUsers(widget.villageId);
      _journalsFuture = ApiService.getDuesJournals(widget.villageId);
    });
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  Future<void> _pickMonthYear() async {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Pilih Periode Bulan & Tahun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tahun:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              setDialogState(() {
                                tempYear--;
                              });
                            },
                          ),
                          Text('$tempYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              setDialogState(() {
                                tempYear++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final m = index + 1;
                      final isSelected = m == tempMonth;
                      return ChoiceChip(
                        label: Text(_monthNames[index]),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              tempMonth = m;
                            });
                          }
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sharePdf(List<Map<String, dynamic>> paidKkList, int totalNominal) async {
    try {
      final pdf = pw.Document();
      final tariffName = widget.tariffData['name'] ?? 'Iuran';
      final tariffType = widget.tariffData['type'] ?? 'Bulanan';
      final periodLabel = '${_monthNames[_selectedMonth - 1]} $_selectedYear';
      final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DAFTAR KK YANG MEMBAYAR IURAN',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Jenis Iuran: $tariffName | Bulan Pembayaran: $periodLabel',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Semua transaksi pembayaran yang masuk pada bulan $periodLabel (termasuk pelunasan tagihan bulan lain)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Dicetak pada: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total KK Membayar: ${paidKkList.length} KK',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.Text(
                            'Total Uang Terkumpul: ${currencyFmt.format(totalNominal)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green800),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),
                  ],
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: (tariffType == 'Harian' || tariffType == 'Jimpitan')
                    ? ['No', 'Nama Kepala Keluarga', 'No. KK', 'Waktu Pembayaran', 'Tagihan', 'Nominal']
                    : ['No', 'Nama Kepala Keluarga', 'No. KK', 'Waktu Pembayaran', 'Tagihan', 'Nominal', 'Status'],
                data: List.generate(paidKkList.length, (index) {
                  final item = paidKkList[index];
                  final kkUser = item['kkUser'] as Map<String, dynamic>;
                  final name = kkUser['name'] ?? 'Tanpa Nama';
                  final noKk = (kkUser['noKK'] ?? kkUser['uniqueCode'] ?? '-').toString();
                  final dateStr = item['lastPaymentDate'] != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(item['lastPaymentDate'] as DateTime)
                      : '-';
                  final amountStr = currencyFmt.format(item['totalAmount'] ?? 0);

                  final List payments = item['payments'] as List;
                  final Set<String> targetPeriods = {};
                  for (var p in payments) {
                    final desc = p['description']?.toString() ?? '';
                    final prd = p['period']?.toString() ?? '';
                    if (desc.contains('-')) {
                      targetPeriods.add(desc.split('-').last.trim());
                    } else if (prd.isNotEmpty) {
                      targetPeriods.add(prd);
                    }
                  }
                  final periodInfo = targetPeriods.isNotEmpty ? targetPeriods.join(', ') : '-';

                  final kkJournals = (item['allJournalsForKk'] as List? ?? payments);
                  final status = DuesStatusHelper.getKkStatus(
                    tariffType: tariffType,
                    expectedAmount: (widget.tariffData['amount'] as num?)?.toInt() ?? 0,
                    year: _selectedYear,
                    kkJournals: kkJournals,
                  );

                  if (tariffType == 'Harian' || tariffType == 'Jimpitan') {
                    return [
                      (index + 1).toString(),
                      name,
                      _canSeePrivateData ? noKk : '****************',
                      dateStr,
                      periodInfo,
                      amountStr,
                    ];
                  }

                  return [
                    (index + 1).toString(),
                    name,
                    _canSeePrivateData ? noKk : '****************',
                    dateStr,
                    periodInfo,
                    amountStr,
                    status ?? '-',
                  ];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              ),
            ];
          },
        ),
      );

      final fileName = 'KK_Bayar_${tariffName.replaceAll(' ', '_')}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf';
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
      if (mounted) {
        CustomToast.show(context, 'PDF berhasil dibuat.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membagikan PDF: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final tariffName = widget.tariffData['name'] ?? 'Iuran';
    final tariffType = widget.tariffData['type'] ?? 'Bulanan';
    final monthLabel = '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CustomGradientAppBar(
        titleText: 'KK Bayar - $tariffName',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Muat Ulang',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector Bulan & Tahun
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: AppTheme.primaryColor),
                  onPressed: _prevMonth,
                  tooltip: 'Bulan Sebelumnya',
                ),
                InkWell(
                  onTap: _pickMonthYear,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          monthLabel,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                  onPressed: _nextMonth,
                  tooltip: 'Bulan Berikutnya',
                ),
              ],
            ),
          ),

          // Search Field
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama KK atau No. KK...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
            ),
          ),

          // Content Builder
          Expanded(
            child: FutureBuilder(
              future: Future.wait([_usersFuture, _journalsFuture]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.red),
                        const SizedBox(height: 8),
                        const Text('Gagal memuat data pembayaran.'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final List<dynamic> allUsers = snapshot.data?[0] ?? [];
                final List<dynamic> allJournals = snapshot.data?[1] ?? [];

                // Filter KK Users
                final kkUsers = allUsers.where((u) {
                  final roles = u['roles'];
                  if (roles is List && roles.contains('SUPER_ADMIN')) return false;
                  if (roles is String && roles.contains('SUPER_ADMIN')) return false;

                  final statusHubungan = u['statusHubungan']?.toString();
                  if (statusHubungan == null || statusHubungan.isEmpty) {
                    final familyId = u['familyId']?.toString();
                    final code = u['code']?.toString();
                    return familyId == null || familyId.isEmpty || familyId == code;
                  }
                  return statusHubungan == 'Kepala Keluarga';
                }).toList();

                // Map KK identifiers for fast lookup
                final Map<String, Map<String, dynamic>> idToKkMap = {};
                for (var u in kkUsers) {
                  final userMap = u as Map<String, dynamic>;
                  final uid = (userMap['uid'] ?? '').toString();
                  final familyId = (userMap['familyId'] ?? '').toString();
                  final noKK = (userMap['noKK'] ?? '').toString();
                  final uniqueCode = (userMap['uniqueCode'] ?? '').toString();
                  final code = (userMap['code'] ?? '').toString();

                  if (uid.isNotEmpty) idToKkMap[uid] = userMap;
                  if (familyId.isNotEmpty) idToKkMap[familyId] = userMap;
                  if (noKK.isNotEmpty) idToKkMap[noKK] = userMap;
                  if (uniqueCode.isNotEmpty) idToKkMap[uniqueCode] = userMap;
                  if (code.isNotEmpty) idToKkMap[code] = userMap;
                }

                // Petakan anggota keluarga ke Kepala Keluarganya jika transaksi memakai ID anggota
                for (var u in allUsers) {
                  final userMap = u as Map<String, dynamic>;
                  final familyId = (userMap['familyId'] ?? '').toString();
                  final uid = (userMap['uid'] ?? '').toString();
                  final code = (userMap['code'] ?? '').toString();
                  if (familyId.isNotEmpty && idToKkMap.containsKey(familyId)) {
                    final headKk = idToKkMap[familyId]!;
                    if (uid.isNotEmpty && !idToKkMap.containsKey(uid)) idToKkMap[uid] = headKk;
                    if (code.isNotEmpty && !idToKkMap.containsKey(code)) idToKkMap[code] = headKk;
                  }
                }

                // Grouping payments per KK: kkKey -> { kkUser, totalAmount, lastPaymentDate, payments }
                final Map<String, Map<String, dynamic>> paidKkAggregates = {};

                // Process dues_journals (Semua jenis iuran termasuk Jimpitan pembayaran manual dicatat di sini)
                for (var j in allJournals) {
                  if (j['tariffId'] != widget.tariffId) continue;
                  final category = (j['category'] ?? '').toString();
                  final journalType = (j['journalType'] ?? '').toString();
                  if (!category.contains('INCOME') && journalType != 'KHUSUS') continue;

                  final amount = (j['amount'] as num?)?.toInt() ?? 0;
                  if (amount <= 0) continue;

                  DateTime? ts;
                  if (j['timestamp'] is String && (j['timestamp'] as String).isNotEmpty) {
                    ts = DateTime.tryParse(j['timestamp'])?.toLocal();
                  }
                  if (ts == null && j['createdAt'] != null) {
                    ts = DateTime.tryParse(j['createdAt'].toString())?.toLocal();
                  }

                  // HANYA transaksi yang DIBAYAR / DILAKUKAN di bulan terpilih (bukan berdasarkan tagihan bulan apa)
                  if (ts == null || ts.year != _selectedYear || ts.month != _selectedMonth) {
                    continue;
                  }

                  final kkId = (j['kkId'] ?? '').toString();
                  // Abaikan jika kosong atau setoran pengurus
                  if (kkId.isEmpty || kkId.toUpperCase() == 'PENGURUS') continue;

                  final kkUser = idToKkMap[kkId] ?? (j['kkName'] != null || j['name'] != null ? {
                    'name': j['kkName'] ?? j['name'] ?? 'KK ($kkId)',
                    'noKK': kkId,
                    'familyId': kkId,
                  } : null);

                  if (kkUser == null) continue;

                  final groupKey = (kkUser['familyId'] ?? kkUser['noKK'] ?? kkUser['uid'] ?? kkId).toString();

                  if (!paidKkAggregates.containsKey(groupKey)) {
                    paidKkAggregates[groupKey] = {
                      'kkUser': kkUser,
                      'totalAmount': 0,
                      'lastPaymentDate': ts,
                      'payments': <Map<String, dynamic>>[],
                    };
                  }

                  paidKkAggregates[groupKey]!['totalAmount'] =
                      (paidKkAggregates[groupKey]!['totalAmount'] as int) + amount;
                  (paidKkAggregates[groupKey]!['payments'] as List).add(j);

                  final prevDate = paidKkAggregates[groupKey]!['lastPaymentDate'] as DateTime?;
                  if (prevDate == null || ts.isAfter(prevDate)) {
                    paidKkAggregates[groupKey]!['lastPaymentDate'] = ts;
                  }
                }

                var paidList = paidKkAggregates.values.toList();

                // Sort by name
                paidList.sort((a, b) {
                  final nameA = (a['kkUser']['name'] ?? '').toString().toLowerCase();
                  final nameB = (b['kkUser']['name'] ?? '').toString().toLowerCase();
                  return nameA.compareTo(nameB);
                });

                // Calculate summary totals
                final int totalNominal = paidList.fold<int>(
                  0,
                  (sum, item) => sum + ((item['totalAmount'] as int?) ?? 0),
                );

                // Filter by Search Query
                if (_searchQuery.isNotEmpty) {
                  paidList = paidList.where((item) {
                    final u = item['kkUser'] as Map<String, dynamic>;
                    final name = (u['name'] ?? '').toString().toLowerCase();
                    final noKK = (u['noKK'] ?? u['uniqueCode'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || noKK.contains(_searchQuery);
                  }).toList();
                }

                return Column(
                  children: [
                    // Ringkasan Kartu
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'KK Yang Membayar',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${paidKkAggregates.length} dari ${kkUsers.length} KK',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Uang Terkumpul',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currencyFmt.format(totalNominal),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (paidKkAggregates.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _sharePdf(paidList, totalNominal),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.share, size: 16, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Bagikan / Cetak PDF Daftar Ini',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // List KK
                    Expanded(
                      child: paidList.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 54,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Tidak ada KK yang cocok dengan pencarian.'
                                          : 'Belum ada KK yang membayar di $monthLabel.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 24),
                              itemCount: paidList.length,
                              itemBuilder: (context, index) {
                                final item = paidList[index];
                                final u = item['kkUser'] as Map<String, dynamic>;
                                final name = u['name'] ?? 'Tanpa Nama';
                                final noKkStr = (u['noKK'] ?? '').toString();
                                final oldCodeStr = (u['uniqueCode'] ?? u['code'] ?? '').toString();
                                final code = noKkStr.isNotEmpty
                                    ? noKkStr
                                    : (oldCodeStr.isNotEmpty ? oldCodeStr : '-');
                                final familyId = (u['familyId'] ?? u['uid'] ?? '').toString();
                                final lastDate = item['lastPaymentDate'] as DateTime?;
                                final totalPaid = item['totalAmount'] as int? ?? 0;
                                final paymentsCount = (item['payments'] as List).length;

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    leading: UserAvatar(userData: u, radius: 20),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          _canSeePrivateData
                                              ? 'No. KK: $code'
                                              : (oldCodeStr.isNotEmpty ? 'Kode: $oldCodeStr' : 'No. KK: ****************'),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        if (lastDate != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Waktu Bayar: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(lastDate)}${paymentsCount > 1 ? ' ($paymentsCount transaksi)' : ''}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                        Builder(
                                          builder: (context) {
                                            final List payments = item['payments'] as List;
                                            final Set<String> targetPeriods = {};
                                            for (var p in payments) {
                                              final desc = p['description']?.toString() ?? '';
                                              final prd = p['period']?.toString() ?? '';
                                              if (desc.contains('-')) {
                                                targetPeriods.add(desc.split('-').last.trim());
                                              } else if (prd.isNotEmpty) {
                                                targetPeriods.add(prd);
                                              }
                                            }
                                            if (targetPeriods.isEmpty) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Tagihan: ${targetPeriods.join(', ')}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            currencyFmt.format(totalPaid),
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final status = DuesStatusHelper.getKkStatus(
                                              tariffType: tariffType,
                                              expectedAmount: (widget.tariffData['amount'] as num?)?.toInt() ?? 0,
                                              year: _selectedYear,
                                              kkJournals: allJournals.where((j) {
                                                if (j['tariffId'] != widget.tariffId) return false;
                                                final cat = (j['category'] ?? '').toString();
                                                final jt = (j['journalType'] ?? '').toString();
                                                if (!cat.contains('INCOME') && jt != 'KHUSUS') return false;
                                                final k = (j['kkId'] ?? '').toString();
                                                return k == familyId || k == noKkStr || k == oldCodeStr || k == (u['uid'] ?? '').toString();
                                              }).toList(),
                                            );

                                            if (status == null) return const SizedBox.shrink();

                                            final isLunas = status == 'Lunas';
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isLunas ? Icons.check_circle : Icons.schedule,
                                                    size: 12,
                                                    color: isLunas ? Colors.green : Colors.orange.shade800,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    status,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isLunas ? Colors.green : Colors.orange.shade800,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      DateTime? parsedUserDate;
                                      final dynamic userRawTime = u['createdAt'];
                                      if (userRawTime is String) {
                                        parsedUserDate = DateTime.tryParse(userRawTime)?.toLocal();
                                      } else if (userRawTime is int) {
                                        parsedUserDate = DateTime.fromMillisecondsSinceEpoch(userRawTime);
                                      }

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
}
