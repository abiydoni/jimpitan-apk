import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/resident_pdf_export.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'harian_checklist_view.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class DuesPaymentPage extends StatefulWidget {
  final String villageId;
  final String tariffId;
  final Map<String, dynamic> tariffData;
  final String kkId;
  final String kkName;
  final String kkNumber;
  final List<String> currentUserRoles;
  final DateTime? userCreatedAt;
  final String? houseCode;
  final Map<String, bool>? permissions;

  const DuesPaymentPage({
    super.key,
    required this.villageId,
    required this.tariffId,
    required this.tariffData,
    required this.kkId,
    required this.kkName,
    required this.kkNumber,
    required this.currentUserRoles,
    this.userCreatedAt,
    this.houseCode,
    this.permissions,
  });

  @override
  State<DuesPaymentPage> createState() => _DuesPaymentPageState();
}

class _DuesPaymentPageState extends State<DuesPaymentPage> {
  bool get _canSeePrivateData {
    final permissions = widget.permissions ?? {};
    final roles = widget.currentUserRoles;
    return permissions['edit'] == true ||
        permissions['add'] == true ||
        permissions['create'] == true ||
        roles.contains('SUPER_ADMIN') ||
        roles.contains('ADMIN_DESA');
  }
  int _selectedYear = DateTime.now().year;
  late int _startYear;

  late Future<List<dynamic>> _journalsFuture;
  late Future<List<dynamic>> _jimpitanFuture;
  List<dynamic>? _lastJournals;
  List<dynamic>? _lastJimpitan;
  DateTime? _tariffCreatedAt;
  String _effectiveDateSource = '';

  bool get _isGodMode =>
      widget.currentUserRoles.contains('SUPER_ADMIN') ||
      widget.currentUserRoles.contains('ADMIN_DESA');

  bool get _canCreate =>
      _isGodMode ||
      widget.currentUserRoles.contains('PENGURUS') ||
      widget.currentUserRoles.contains('BENDAHARA') ||
      widget.currentUserRoles.contains('PENGURUS_IURAN') ||
      (widget.permissions != null && widget.permissions!['create'] == true);

  bool get _canEdit =>
      _isGodMode ||
      widget.currentUserRoles.contains('PENGURUS') ||
      widget.currentUserRoles.contains('BENDAHARA') ||
      widget.currentUserRoles.contains('PENGURUS_IURAN') ||
      (widget.permissions != null && widget.permissions!['edit'] == true);

  bool get _canDelete =>
      _isGodMode ||
      (widget.permissions != null && widget.permissions!['delete'] == true);

  bool get _canManagePayment => _canCreate || _canEdit;

  @override
  void initState() {
    super.initState();

    DateTime? tempDate;
    final dynamic createdAtRaw = widget.tariffData['createdAt'];
    if (createdAtRaw is String) {
      tempDate = DateTime.tryParse(createdAtRaw)?.toLocal();
    } else if (createdAtRaw is int) {
      tempDate = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    }

    _tariffCreatedAt = tempDate;
    _effectiveDateSource = 'Aturan Tarif';

    if (widget.userCreatedAt != null) {
      if (_tariffCreatedAt == null ||
          widget.userCreatedAt!.isAfter(_tariffCreatedAt!)) {
        _tariffCreatedAt = widget.userCreatedAt;
        _effectiveDateSource = 'Registrasi Warga';
      }
    }


    final creationYear = _tariffCreatedAt != null
        ? _tariffCreatedAt!.year
        : DateTime.now().year;
    // Allow going back at least 3 years or to the creation year, whichever is older
    final minYear = DateTime.now().year - 3;
    _startYear = creationYear < minYear ? creationYear : minYear;

    if (_selectedYear < _startYear) {
      _selectedYear = _startYear;
    }

    _loadData();
    _loadVillageStartDate();
  }

  Future<void> _loadData() async {
    final futures = <Future>[];
    setState(() {
      _journalsFuture = ApiService.getDuesJournals(widget.villageId).then((data) {
        final res = data.where((item) {
          final k = item['kkId']?.toString() ?? '';
          return item['tariffId'] == widget.tariffId && 
            (k == widget.kkId || k == widget.kkNumber || (widget.houseCode != null && k == widget.houseCode));
        }).toList();
        _lastJournals = res;
        return res;
      });
      futures.add(_journalsFuture);

      _jimpitanFuture = ApiService.getJimpitanHistory(widget.villageId).then((data) {
        final res = data.where((item) {
          final k = item['kkId']?.toString() ?? '';
          return k == widget.kkId || k == widget.kkNumber || (widget.houseCode != null && k == widget.houseCode);
        }).toList();
        _lastJimpitan = res;
        return res;
      });
      futures.add(_jimpitanFuture);
    });
    await Future.wait(futures);
  }

  Future<void> _loadVillageStartDate() async {
    try {
      final villageData = await ApiService.getVillage(widget.villageId);
      if (villageData != null) {
        final config = villageData['config'] as Map<String, dynamic>? ?? {};
        DateTime? villageStartDate;
        if (config['startDate'] is String) {
          villageStartDate = DateTime.tryParse(config['startDate'])?.toLocal();
        }
        
        if (villageStartDate != null) {
          if (mounted) {
            setState(() {
              // Compare with village start date
              if (_tariffCreatedAt == null ||
                  villageStartDate!.isAfter(_tariffCreatedAt!)) {
                _tariffCreatedAt = villageStartDate;
                _effectiveDateSource = 'Registrasi Desa';
              }

              if (_tariffCreatedAt != null) {
                // Update startYear if necessary
                if (_tariffCreatedAt!.year < _startYear) {
                  _startYear = _tariffCreatedAt!.year;
                }
                if (_selectedYear < _startYear) {
                  _selectedYear = _startYear;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading village start date: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _processPayment(
    String period,
    int defaultAmount,
    String label,
  ) async {
    if (!_canManagePayment) {
      CustomToast.show(context, 'Anda tidak memiliki otorisasi untuk memproses pembayaran.');
      return;
    }

    final amountController = TextEditingController(
      text: defaultAmount.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AppModalDialog(
          title: 'Input Pembayaran\n$label',
          headerIcon: Icons.payments,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixIcon: const Icon(Icons.payments),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Anda dapat mengganti nominal ini jika warga mencicil pembayaran.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = int.tryParse(amountController.text) ?? 0;
                        if (amount > 0) {
                          Navigator.pop(context, amount);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

    if (result != null && result > 0) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Konfirmasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin memproses pembayaran ini sebesar ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(result)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text(
                  'Ya, Simpan',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      EasyLoading.show(status: 'Menyimpan...');
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final bool success = await ApiService.createDuesJournal({
          'villageId': widget.villageId,
          'tariffId': widget.tariffId,
          'journalType': 'KHUSUS',
          'kkId': (widget.houseCode != null && widget.houseCode!.isNotEmpty) ? widget.houseCode! : widget.kkId,
          'amount': result,
          'period': period,
          'timestamp': DateTime.now().toIso8601String(),
          'recordedBy': currentUser?.uid ?? 'unknown',
          'type': widget.tariffData['type'] ?? 'Bulanan',
          'category': 'DUES_INCOME',
          'description':
              'Pembayaran ${widget.tariffData['name'] ?? ''} - $label',
        });
        
        if (success) {
          final tType = widget.tariffData['type']?.toString();
          if (tType == 'Harian' || tType == 'Jimpitan') {
            try {
              final scannerName = await ApiService.getCurrentCitizenName(widget.villageId);
              await ApiService.createJimpitanHistory({
                'kkId': (widget.houseCode != null && widget.houseCode!.isNotEmpty) ? widget.houseCode! : widget.kkId,
                'name': widget.kkName,
                'amount': result,
                'scannedBy': currentUser?.uid ?? 'unknown',
                'scannedByName': scannerName,
                'timestamp': DateTime.now().toIso8601String(),
                'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'type': 'TAGIHAN',
                'villageId': widget.villageId,
              });
            } catch (e) {
              debugPrint('Error creating JimpitanHistory for Harian tagihan: $e');
            }
          }

          if (mounted) {
            CustomToast.show(context, 'Pembayaran berhasil dicatat.');
            await _loadData();
          }
        } else {
          if (mounted) {
            CustomToast.show(context, 'Gagal mencatat pembayaran.', isError: true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
        }
      } finally {
        EasyLoading.dismiss();
      }
    }
  }

  Future<void> _sharePaymentDetailPdf() async {
    try {
      final allJournals = await ApiService.getDuesJournals(widget.villageId);
      final journals = allJournals.where((item) => 
        item['tariffId'] == widget.tariffId && 
        item['kkId'] == widget.kkId
      ).toList();

      final payments = journals.map((data) {
        DateTime? ts;
        if (data['timestamp'] is String) ts = DateTime.tryParse(data['timestamp'])?.toLocal();

        final dateText = ts != null
            ? DateFormat('dd MMM yyyy HH:mm').format(ts)
            : '-';
        return {
          'label': data['description'] ?? 'Pembayaran',
          'dateText': dateText,
          'amount': (data['amount'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      final paidTotal = payments.fold<int>(
        0,
        (total, item) => total + ((item['amount'] as num?)?.toInt() ?? 0),
      );
      final amount = (widget.tariffData['amount'] as num?)?.toInt() ?? 0;
      final remainingTotal = (amount - paidTotal).clamp(0, 999999999999);

      final fileName =
          'Detail_Pembayaran_${widget.kkName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.pdf';
      await sharePaymentDetailPdf(
        residentName: widget.kkName,
        kkNumber: widget.kkNumber,
        tariffName: widget.tariffData['name'] ?? 'Tagihan',
        tariffType: widget.tariffData['type'] ?? 'Bulanan',
        amount: amount,
        paidTotal: paidTotal,
        remainingTotal: remainingTotal,
        payments: payments,
        fileName: fileName,
      );

      if (mounted) {
        CustomToast.show(context, 'PDF detail pembayaran berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membuat PDF detail pembayaran: $e', isError: true);
      }
    }
  }

  Future<bool> _deletePayment(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Batalkan Pembayaran?',
        headerIcon: Icons.warning,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Apakah Anda yakin ingin membatalkan pembayaran ini? Jurnal terkait juga akan dihapus.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Batalkan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return false;

    EasyLoading.show(status: 'Menghapus...');
    try {
      bool success = await ApiService.deleteDuesJournal(docId);
      if (success && mounted) {
        CustomToast.show(context, 'Pembayaran berhasil dibatalkan.');
        await _loadData();
        return true;
      }
        if (mounted) CustomToast.show(context, 'Data berhasil dihapus');
    } catch (e) {
      // ignore
    } finally {
      EasyLoading.dismiss();
    }
    return false;
  }

  void _showHistoryBottomSheet(
    String period,
    String label,
    List<dynamic> periodDocs,
  ) {
    List<dynamic> localDocs = List.from(periodDocs);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final format = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Cicilan\n$label',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (localDocs.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'Belum ada pembayaran',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...localDocs.map((data) {
                        DateTime? ts;
                        if (data['timestamp'] != null) {
                          ts = DateTime.tryParse(data['timestamp'].toString())?.toLocal();
                        }
                        
                        final dateStr = ts != null
                            ? DateFormat('dd MMM yyyy HH:mm').format(ts)
                            : '-';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    format.format(data['amount'] ?? 0),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (_canDelete)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    bool success = await _deletePayment(data['id'].toString());
                                    if (success) {
                                      setModalState(() {
                                        localDocs.removeWhere((d) => d['id'].toString() == data['id'].toString());
                                      });
                                      if (!context.mounted) return;
                                      if (localDocs.isEmpty && Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                  tooltip: 'Batalkan pembayaran',
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    int expectedTotal,
    int actualTotal,
    NumberFormat format,
  ) {
    final sisa = expectedTotal - actualTotal;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Sudah Dibayar',
                  format.format(actualTotal),
                  Colors.green,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _buildSummaryItem(
                  'Sisa Tagihan',
                  sisa > 0 ? format.format(sisa) : 'Rp 0',
                  sisa > 0 ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: expectedTotal > 0
                  ? (actualTotal / expectedTotal).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: Colors.grey.shade100,
              color: AppTheme.primaryColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tariffType = widget.tariffData['type'] ?? 'Bulanan';
    final dynamic rawAmount = widget.tariffData['amount'] ?? 0;
    final int amount = rawAmount is num
        ? rawAmount.toInt()
        : int.tryParse(rawAmount.toString()) ?? 0;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _sharePaymentDetailPdf,
            tooltip: 'Bagikan PDF Detail Pembayaran',
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _journalsFuture,
        initialData: _lastJournals,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final journals = snapshot.data ?? [];

          if (tariffType == 'Harian' || tariffType == 'Jimpitan') {
            return FutureBuilder<List<dynamic>>(
              future: _jimpitanFuture,
              initialData: _lastJimpitan,
              builder: (context, jimpitanSnap) {
                if (jimpitanSnap.connectionState == ConnectionState.waiting && !jimpitanSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final jimpitanDocs = jimpitanSnap.data ?? [];
                return _buildMainContent(
                  journals,
                  jimpitanDocs,
                  tariffType,
                  amount,
                  currencyFormat,
                );
              },
            );
          }

          return _buildMainContent(
            journals,
            [],
            tariffType,
            amount,
            currencyFormat,
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    List<dynamic> journals,
    List<dynamic> jimpitanDocs,
    String tariffType,
    int amount,
    NumberFormat currencyFormat,
  ) {
    return Column(
      children: [
        // Hero Header section
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Dekorasi lingkaran atas kanan
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Dekorasi lingkaran bawah kiri
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Konten Utama
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: 40,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.kkName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _canSeePrivateData
                                  ? 'No. KK: ${widget.kkNumber}'
                                  : (widget.houseCode != null && widget.houseCode!.isNotEmpty
                                      ? 'Kode Rumah: ${widget.houseCode}'
                                      : 'No. KK: ****************'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${widget.tariffData['name']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$tariffType - ${currencyFormat.format(amount)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Summary Card overlaps header using Transform
        Transform.translate(
          offset: const Offset(0, -25),
          child: Builder(
            builder: (context) {
              int expected = 0;
              int paid = 0;

              if (tariffType == 'Bulanan') {
                int totalExpected = 0;
                int totalPaid = 0;
                
                const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

                // 1. Tahun yang dipilih (12 bulan)
                for (int monthNum = 1; monthNum <= 12; monthNum++) {
                  bool isBeforeCreation = false;
                  if (_tariffCreatedAt != null) {
                    if (_selectedYear < _tariffCreatedAt!.year) {
                      isBeforeCreation = true;
                    } else if (_selectedYear == _tariffCreatedAt!.year && monthNum < _tariffCreatedAt!.month) {
                      isBeforeCreation = true;
                    }
                  }

                  if (!isBeforeCreation) {
                    totalExpected += amount;
                  }

                  final periodStr = '$_selectedYear-${monthNum.toString().padLeft(2, '0')}';
                  final label = '${months[monthNum - 1]} $_selectedYear';
                  final periodDocs = journals.where((doc) {
                    final map = doc as Map<String, dynamic>;
                    return map['period'] == periodStr || (map['period'] == null && map['description'] != null && map['description'].toString().contains(label));
                  });
                  final p = periodDocs.fold<int>(0, (t, d) => t + (((d as Map)['amount'] ?? 0) as num).toInt());

                  totalPaid += p;
                }

                // 2. Tunggakan tahun sebelumnya
                for (int y = _selectedYear - 1; y >= _startYear; y--) {
                  for (int monthNum = 12; monthNum >= 1; monthNum--) {
                    final periodStr = '$y-${monthNum.toString().padLeft(2, '0')}';
                    final label = '${months[monthNum - 1]} $y';
                    final periodDocs = journals.where((doc) {
                      final map = doc as Map<String, dynamic>;
                      return map['period'] == periodStr || (map['period'] == null && map['description'] != null && map['description'].toString().contains(label));
                    });
                    final p = periodDocs.fold<int>(0, (t, d) => t + (((d as Map)['amount'] ?? 0) as num).toInt());

                    bool isBeforeCreation = false;
                    if (_tariffCreatedAt != null) {
                      if (y < _tariffCreatedAt!.year) {
                        isBeforeCreation = true;
                      } else if (y == _tariffCreatedAt!.year && monthNum < _tariffCreatedAt!.month) {
                        isBeforeCreation = true;
                      }
                    }

                    if (p < amount && !isBeforeCreation) {
                      totalExpected += amount;
                      totalPaid += p;
                    }
                  }
                }
                
                expected = totalExpected;
                paid = totalPaid;
              } else if (tariffType == 'Tahunan') {
                int totalExpected = 0;
                int totalPaid = 0;
                final currentYear = DateTime.now().year;
                
                for (int y = currentYear; y >= _startYear; y--) {
                  bool isBeforeCreation = false;
                  if (_tariffCreatedAt != null && y < _tariffCreatedAt!.year) {
                    isBeforeCreation = true;
                  }
                  
                  if (!isBeforeCreation) {
                    totalExpected += amount;
                  }
                  
                  final periodStr = y.toString();
                  final label = 'Tahun $y';
                  final periodDocs = journals.where((doc) {
                    final map = doc as Map<String, dynamic>;
                    return map['period'] == periodStr || (map['period'] == null && map['description'] != null && map['description'].toString().contains(label));
                  });
                  final p = periodDocs.fold<int>(0, (t, d) => t + (((d as Map)['amount'] ?? 0) as num).toInt());
                  totalPaid += p;
                }
                
                expected = totalExpected;
                paid = totalPaid;
              } else if (tariffType == 'Harian' || tariffType == 'Jimpitan') {
                if (_tariffCreatedAt != null) {
                  final start = DateTime(
                    _tariffCreatedAt!.year,
                    _tariffCreatedAt!.month,
                    _tariffCreatedAt!.day,
                  );
                  final today = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  );
                  final days =
                      today.difference(start).inDays + 1; // +1 to include today
                  expected = (days > 0 ? days : 0) * amount;
                }
                int jimpitanPaid = jimpitanDocs.fold<int>(
                  0,
                  (total, doc) =>
                      total +
                      (((doc as Map)['amount'] ?? 0) as num).toInt(),
                );
                paid = jimpitanPaid; // DuesJournal untuk harian adalah duplikat dari JimpitanHistory (tipe TAGIHAN)
              } else {
                expected = amount;
                paid = journals.fold<int>(
                  0,
                  (total, doc) =>
                      total +
                      (((doc as Map)['amount'] ?? 0) as num).toInt(),
                );
              }

              return _buildSummaryCard(expected, paid, currencyFormat);
            },
          ),
        ),

        // Effective Date Info Banner
        if (_tariffCreatedAt != null)
          Transform.translate(
            offset: const Offset(0, -15),
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mulai dihitung: ${DateFormat('dd MMMM yyyy', 'id_ID').format(_tariffCreatedAt!)} ($_effectiveDateSource)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        Transform.translate(
          offset: const Offset(0, -15),
          child: Builder(
            builder: (context) {
              if (tariffType == 'Bulanan') {
                return _buildYearFilter();
              }
              return const SizedBox.shrink();
            },
          ),
        ),

        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -15),
            child: Builder(
              builder: (context) {
                if (tariffType == 'Bulanan') {
                  return _buildBulananView(journals, amount, currencyFormat);
                } else if (tariffType == 'Tahunan') {
                  return _buildTahunanView(journals, amount, currencyFormat);
                } else if (tariffType == 'Harian' || tariffType == 'Jimpitan') {
                  return HarianChecklistView(
                    villageId: widget.villageId,
                    kkId: widget.kkId,
                    houseCode: widget.houseCode,
                    kkName: widget.kkName,
                    tariffId: widget.tariffId,
                    tariffName: widget.tariffData['name'] ?? '',
                    tariffCreatedAt: _tariffCreatedAt,
                    amount: amount,
                    duesJournals: journals,
                    jimpitanDocs: jimpitanDocs,
                    isAdmin: _canManagePayment || _canDelete,
                    format: currencyFormat,
                    onPaymentSuccess: _loadData,
                  );
                } else {
                  return _buildSekaliBayarView(
                    journals,
                    amount,
                    currencyFormat,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearFilter() {
    List<int> years = [];
    int endYear = DateTime.now().year;
    if (_startYear > endYear) endYear = _startYear;
    if (_selectedYear > endYear) endYear = _selectedYear;

    for (int y = _startYear; y <= endYear; y++) {
      years.add(y);
    }

    if (!years.contains(_selectedYear)) {
      years.add(_selectedYear);
      years.sort();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          icon: Icon(
            Icons.calendar_today,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          isExpanded: true,
          items: years.map((year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text(
                'Tahun Tagihan: $year',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedYear = val;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildBulananView(
    List<dynamic> journals,
    int expectedAmount,
    NumberFormat format,
  ) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    List<Map<String, dynamic>> itemsToDisplay = [];

    // 1. Tampilkan 12 bulan untuk tahun yang dipilih
    for (int monthNum = 1; monthNum <= 12; monthNum++) {
       itemsToDisplay.add({'year': _selectedYear, 'month': monthNum, 'isArrears': false});
    }

    // 2. Tambahkan tunggakan dari tahun-tahun sebelumnya
    for (int y = _selectedYear - 1; y >= _startYear; y--) {
      for (int monthNum = 12; monthNum >= 1; monthNum--) {
        final periodStr = '$y-${monthNum.toString().padLeft(2, '0')}';
        final label = '${months[monthNum - 1]} $y';

        final periodDocs = journals.where((doc) {
          final map = doc as Map<String, dynamic>;
          return map['period'] == periodStr ||
              (map['period'] == null &&
                  map['description'] != null &&
                  map['description'].toString().contains(label));
        }).toList();

        final totalPaid = periodDocs.fold<int>(
          0,
          (total, doc) => total + (((doc as Map)['amount'] ?? 0) as num).toInt(),
        );

        bool isBeforeCreation = false;
        if (_tariffCreatedAt != null) {
          if (y < _tariffCreatedAt!.year) {
            isBeforeCreation = true;
          } else if (y == _tariffCreatedAt!.year && monthNum < _tariffCreatedAt!.month) {
            isBeforeCreation = true;
          }
        }

        if (totalPaid < expectedAmount && !isBeforeCreation) {
          itemsToDisplay.add({'year': y, 'month': monthNum, 'isArrears': true});
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      itemCount: itemsToDisplay.length,
      itemBuilder: (context, index) {
        final item = itemsToDisplay[index];
        final year = item['year'] as int;
        final monthNum = item['month'] as int;
        final isArrears = item['isArrears'] as bool;
        
        final periodStr = '$year-${monthNum.toString().padLeft(2, '0')}';
        final label = '${months[monthNum - 1]} $year';

        final periodDocs = journals.where((doc) {
          final map = doc as Map<String, dynamic>;
          return map['period'] == periodStr ||
              (map['period'] == null &&
                  map['description'] != null &&
                  map['description'].toString().contains(label));
        }).toList();
        
        final totalPaid = periodDocs.fold<int>(
          0,
          (total, doc) => total + (((doc as Map)['amount'] ?? 0) as num).toInt(),
        );

        bool isBeforeCreation = false;
        if (_tariffCreatedAt != null) {
          if (year < _tariffCreatedAt!.year) {
            isBeforeCreation = true;
          } else if (year == _tariffCreatedAt!.year && monthNum < _tariffCreatedAt!.month) {
            isBeforeCreation = true;
          }
        }

        return _buildPeriodCard(
          periodStr: periodStr,
          label: label,
          expectedAmount: expectedAmount,
          totalPaid: totalPaid,
          periodDocs: periodDocs,
          format: format,
          isArrears: isArrears,
          isBeforeCreation: isBeforeCreation,
        );
      },
    );
  }

  Widget _buildTahunanView(
    List<dynamic> journals,
    int expectedAmount,
    NumberFormat format,
  ) {
    List<int> requiredYears = [];
    final currentYear = DateTime.now().year;
    for (int y = currentYear; y >= _startYear; y--) {
      requiredYears.add(y);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      itemCount: requiredYears.length,
      itemBuilder: (context, index) {
        final year = requiredYears[index];
        final periodStr = year.toString();
        final label = 'Tahun $year';

        final periodDocs = journals
            .where(
              (doc) {
                final map = doc as Map<String, dynamic>;
                return map['period'] == periodStr ||
                    (map['period'] == null &&
                        map['description'] != null &&
                        map['description'].toString().contains(label));
              },
            )
            .toList();
        final totalPaid = periodDocs.fold<int>(
          0,
          (total, doc) =>
              total + (((doc as Map)['amount'] ?? 0) as num).toInt(),
        );

        bool isBeforeCreation = false;
        if (_tariffCreatedAt != null) {
          if (year < _tariffCreatedAt!.year) {
            isBeforeCreation = true;
          }
        }

        return _buildPeriodCard(
          periodStr: periodStr,
          label: label,
          expectedAmount: expectedAmount,
          totalPaid: totalPaid,
          periodDocs: periodDocs,
          format: format,
          isArrears: year < currentYear,
          isBeforeCreation: isBeforeCreation,
        );
      },
    );
  }

  Widget _buildPeriodCard({
    required String periodStr,
    required String label,
    required int expectedAmount,
    required int totalPaid,
    required List<dynamic> periodDocs,
    required NumberFormat format,
    required bool isArrears,
    bool isBeforeCreation = false,
  }) {
    final isFullyPaid = totalPaid >= expectedAmount;
    final isPartial = totalPaid > 0 && !isFullyPaid;

    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.schedule;
    String statusText = 'Belum Bayar';

    if (isBeforeCreation && totalPaid == 0) {
      statusColor = Colors.blueGrey;
      statusIcon = Icons.block;
      statusText = 'Tidak Berlaku';
    } else if (isFullyPaid) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Lunas';
    } else if (isArrears) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
      statusText = isPartial ? 'Tunggakan Dicicil' : 'Tunggakan';
    } else if (isPartial) {
      statusColor = Colors.orange;
      statusIcon = Icons.timelapse;
      statusText = 'Dicicil';
    }

    final bool isReadonly = isBeforeCreation && totalPaid == 0;

    return InkWell(
      onTap: isReadonly
          ? null
          : () => _showHistoryBottomSheet(periodStr, label, periodDocs),
      child: Opacity(
        opacity: isReadonly ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isReadonly ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isReadonly
                  ? statusColor.withValues(alpha: 0.5)
                  : (isArrears && !isFullyPaid
                        ? Colors.red.withValues(alpha: 0.8)
                        : Colors.grey.shade200),
              width: isReadonly ? 1.0 : 1.0,
            ),
            boxShadow: isReadonly
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isReadonly
                      ? statusColor.withValues(alpha: 0.1)
                      : statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isReadonly ? statusColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatusBadge(statusText, statusColor),
                        if (isPartial || isFullyPaid) ...[
                          const SizedBox(width: 8),
                          Text(
                            format.format(totalPaid),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_canManagePayment && !isFullyPaid && !isBeforeCreation)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _processPayment(
                      periodStr,
                      expectedAmount - totalPaid,
                      label,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      isPartial ? 'Lunasi' : 'Bayar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (isFullyPaid)
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSekaliBayarView(
    List<dynamic> journals,
    int expectedAmount,
    NumberFormat format, {
    String label = 'Sekali Bayar',
    String periodStr = 'Onetime',
  }) {
    final totalPaid = journals.fold<int>(
      0,
      (total, doc) =>
          total + (((doc as Map)['amount'] ?? 0) as num).toInt(),
    );
    final isFullyPaid = totalPaid > 0 && (expectedAmount <= 0 || totalPaid >= expectedAmount);
    final remaining = (expectedAmount - totalPaid) > 0 ? (expectedAmount - totalPaid) : 0;
    final buttonText = remaining > 0
        ? 'Bayar (${format.format(remaining)})'
        : 'Bayar';

    return Column(
      children: [
        if (_canManagePayment && !isFullyPaid)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                _processPayment(periodStr, remaining, label);
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          )
        else if (isFullyPaid)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tagihan Sudah Lunas',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Terbayar: ${format.format(totalPaid)}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 8,
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),

        if (journals.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat pembayaran',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              itemCount: journals.length,
              itemBuilder: (context, index) {
                final data = journals[index] as Map<String, dynamic>;
                
                DateTime? ts;
                if (data['timestamp'] != null) {
                  ts = DateTime.tryParse(data['timestamp'].toString())?.toLocal();
                }
                
                final dateStr = ts != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(ts)
                    : '-';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.payments,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              format.format(data['amount']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canDelete)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deletePayment(data['id'].toString()),
                          tooltip: 'Hapus pembayaran',
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
