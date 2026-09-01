import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/app_theme.dart';

import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class HarianChecklistView extends StatefulWidget {
  final String villageId;
  final String kkId;
  final String? houseCode;
  final String kkName;
  final String tariffId;
  final String tariffName;
  final DateTime? tariffCreatedAt;
  final int amount;
  final List<dynamic> duesJournals;
  final List<dynamic> jimpitanDocs;
  final bool isAdmin;
  final NumberFormat format;
  final VoidCallback? onPaymentSuccess;

  const HarianChecklistView({
    super.key,
    required this.villageId,
    required this.kkId,
    this.houseCode,
    required this.kkName,
    required this.tariffId,
    required this.tariffName,
    required this.tariffCreatedAt,
    required this.amount,
    required this.duesJournals,
    required this.jimpitanDocs,
    required this.isAdmin,
    required this.format,
    this.onPaymentSuccess,
  });

  @override
  State<HarianChecklistView> createState() => _HarianChecklistViewState();
}

class _HarianChecklistViewState extends State<HarianChecklistView> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final Set<String> _selectedDates = {};
  Set<String> _globalPaidDates = {};
  List<DateTime> _monthDates = [];
  bool _needsAutoSelect = true;

  final Map<String, String> _jimpitanHistoryId = {};
  final Map<String, String> _manualPaymentJournalId = {};
  final Map<String, List<String>> _journalIdToDates = {};

  List<dynamic> _localJimpitanDocs = [];
  List<dynamic> _localDuesJournals = [];

  @override
  void initState() {
    super.initState();
    _needsAutoSelect = true;
    _localJimpitanDocs = List.from(widget.jimpitanDocs);
    _localDuesJournals = List.from(widget.duesJournals);
    _calculatePaymentStatus();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final futures = <Future>[];
      futures.add(ApiService.getJimpitanHistory(widget.villageId).then((data) {
        _localJimpitanDocs = data.where((item) {
          final k = item['kkId']?.toString() ?? '';
          return k == widget.kkId || (widget.houseCode != null && k == widget.houseCode);
        }).toList();
      }));

      futures.add(ApiService.getDuesJournals(widget.villageId).then((data) {
        _localDuesJournals = data.where((item) {
          final k = item['kkId']?.toString() ?? '';
          return item['tariffId'] == widget.tariffId && (k == widget.kkId || (widget.houseCode != null && k == widget.houseCode));
        }).toList();
      }));
      
      await Future.wait(futures);
      if (mounted) {
        _calculatePaymentStatus();
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  @override
  void didUpdateWidget(covariant HarianChecklistView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duesJournals.length != oldWidget.duesJournals.length ||
        widget.jimpitanDocs.length != oldWidget.jimpitanDocs.length) {
      _needsAutoSelect = true;
      _localJimpitanDocs = List.from(widget.jimpitanDocs);
      _localDuesJournals = List.from(widget.duesJournals);
    }
    _calculatePaymentStatus();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      _needsAutoSelect = true;
    });
    _calculatePaymentStatus();
  }

  void _calculatePaymentStatus() {
    if (widget.tariffCreatedAt == null || widget.amount <= 0) {
      setState(() {
        _globalPaidDates = {};
        _monthDates = [];
      });
      return;
    }

    final startDate = DateTime(widget.tariffCreatedAt!.year, widget.tariffCreatedAt!.month, widget.tariffCreatedAt!.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    List<DateTime> allDates = [];
    DateTime current = startDate;
    while (!current.isAfter(today)) {
      allDates.add(current);
      current = current.add(const Duration(days: 1));
    }

    Set<String> explicitPaidDates = {};
    int lumpSumAmount = 0;

    _jimpitanHistoryId.clear();
    _manualPaymentJournalId.clear();
    _journalIdToDates.clear();

    // 1. Process Jimpitan Scans
    for (var doc in _localJimpitanDocs) {
      final data = doc as Map<String, dynamic>;
      final id = data['id']?.toString();
      final type = data['type']?.toString();
      final amt = ((data['amount'] ?? 0) as num).toInt();
      
      String dateKey = '';
      if (type == 'TAGIHAN' || type == 'MANUAL') {
         if (data['date'] != null && data['date'].toString().isNotEmpty) {
            dateKey = data['date'];
         } else if (data['timestamp'] != null) {
            DateTime? dt = DateTime.tryParse(data['timestamp'].toString());
            if (dt != null) dateKey = DateFormat('yyyy-MM-dd').format(dt);
         }
      } else {
         if (data['timestamp'] != null) {
            DateTime? dt = DateTime.tryParse(data['timestamp'].toString());
            if (dt != null) dateKey = DateFormat('yyyy-MM-dd').format(dt);
         }
      }
      
      if (dateKey.isNotEmpty) {
         if (id != null) _jimpitanHistoryId[dateKey] = id;
         
         if (type != 'TAGIHAN') {
            if (!explicitPaidDates.contains(dateKey) && amt >= widget.amount) {
              explicitPaidDates.add(dateKey);
              if (amt > widget.amount) {
                lumpSumAmount += (amt - widget.amount);
              }
            } else {
              lumpSumAmount += amt;
            }
         }
         // Untuk type == 'TAGIHAN', amount dan date diserahkan ke DuesJournal agar tidak double hitung.
         // Kita hanya mencatat ID-nya di _jimpitanHistoryId untuk keperluan "Batalkan".
      } else if (type != 'TAGIHAN') {
         lumpSumAmount += amt;
      }
    }

    // 2. Process Dues Journals (Manual Payments)
    for (var doc in _localDuesJournals) {
      final data = doc as Map<String, dynamic>;
      final journalId = data['id']?.toString();
      final period = data['period'] as String? ?? '';
      final amt = ((data['amount'] ?? 0) as num).toInt();
      
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(period)) {
        explicitPaidDates.add(period);
        if (journalId != null) {
          _manualPaymentJournalId[period] = journalId;
          _journalIdToDates[journalId] = [period];
        }
      } else if (data['paidDates'] != null) {
        List dates = [];
        if (data['paidDates'] is List) {
          dates = data['paidDates'] as List;
        } else if (data['paidDates'] is String) {
          try {
            dates = jsonDecode(data['paidDates']);
          } catch (_) {}
        }
        
        List<String> dStrs = [];
        for (var d in dates) {
          final dStr = d.toString();
          explicitPaidDates.add(dStr);
          dStrs.add(dStr);
          if (journalId != null) _manualPaymentJournalId[dStr] = journalId;
        }
        if (journalId != null) _journalIdToDates[journalId] = dStrs;

        final expectedForDates = dates.length * widget.amount;
        if (amt > expectedForDates) {
          lumpSumAmount += (amt - expectedForDates);
        }
      } else {
        lumpSumAmount += amt;
      }
    }

    // 3. Determine Paid/Unpaid
    Set<String> finalPaidDates = {};
    // Masukkan semua tanggal yang sudah pasti dibayar (explicit) 
    // terlepas dari kapan tariff ini dibuat.
    finalPaidDates.addAll(explicitPaidDates);

    for (var date in allDates) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      if (finalPaidDates.contains(dateStr)) {
        continue;
      }
      
      if (lumpSumAmount >= widget.amount) {
        lumpSumAmount -= widget.amount;
        finalPaidDates.add(dateStr);
      }
    }
    
    List<DateTime> tempMonthDates = [];
    DateTime monthCursor = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    while (monthCursor.month == _selectedMonth.month) {
      tempMonthDates.add(monthCursor);
      monthCursor = monthCursor.add(const Duration(days: 1));
    }

    setState(() {
      _globalPaidDates = finalPaidDates;
      _monthDates = tempMonthDates;
      
      if (_needsAutoSelect) {
        _selectedDates.clear();
        _needsAutoSelect = false;
      }
    });
  }

  Future<void> _promptDeleteManualPayment(String journalId) async {
    final dates = _journalIdToDates[journalId] ?? [];
    if (dates.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pembayaran?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          dates.length > 1 
            ? 'Pembayaran ini dilakukan sekaligus untuk ${dates.length} hari. Membatalkannya akan menghapus status lunas untuk semua ${dates.length} hari tersebut. Lanjutkan?'
            : 'Apakah Anda yakin ingin membatalkan pembayaran manual untuk tanggal ini?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    EasyLoading.show(status: 'Membatalkan...');
    try {
      await ApiService.deleteDuesJournal(journalId);
      for (var d in dates) {
        final jId = _jimpitanHistoryId[d];
        if (jId != null) {
          await ApiService.deleteJimpitanHistory(jId);
        }
      }
      
      if (mounted) {
        CustomToast.show(context, 'Pembayaran berhasil dibatalkan');
        setState(() {
          _localDuesJournals.removeWhere((j) => j['id'].toString() == journalId);
          for (var d in dates) {
            final jId = _jimpitanHistoryId[d];
            if (jId != null) {
              _localJimpitanDocs.removeWhere((h) => h['id'].toString() == jId);
            }
          }
        });
        CustomToast.show(context, 'Pembayaran berhasil dibatalkan.');
        _fetchData();
        widget.onPaymentSuccess?.call();
      }
    } catch (e) {
       if (mounted) CustomToast.show(context, 'Error: $e');
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _processSelectedPayment() async {
    if (_selectedDates.isEmpty) return;
    
    final totalAmount = _selectedDates.length * widget.amount;
    final datesList = _selectedDates.toList();
    datesList.sort(); // sort chronological for database consistency
    
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin memproses pembayaran ini sebesar ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(totalAmount)} untuk ${_selectedDates.length} hari?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('Ya, Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    EasyLoading.show(status: 'Menyimpan...');
    try {
      final targetKkId = (widget.houseCode != null && widget.houseCode!.isNotEmpty) ? widget.houseCode! : widget.kkId;
      final scannerName = await ApiService.getCurrentCitizenName(widget.villageId);
      for (String dStr in datesList) {
        await ApiService.createJimpitanHistory({
          'kkId': targetKkId,
          'name': widget.kkName,
          'amount': widget.amount,
          'scannedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'scannedByName': scannerName,
          'timestamp': DateTime.now().toIso8601String(),
          'date': dStr,
          'type': 'TAGIHAN',
          'villageId': widget.villageId,
        });
      }

      await ApiService.createDuesJournal({
        'villageId': widget.villageId,
        'tariffId': widget.tariffId,
        'journalType': 'KHUSUS',
        'kkId': targetKkId,
        'amount': totalAmount,
        'period': 'MULTIPLE',
        'paidDates': datesList,
        'timestamp': DateTime.now().toIso8601String(),
        'recordedBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'type': widget.tariffName,
        'category': 'DUES_INCOME',
        'description': 'Pembayaran Hutang Jimpitan (${datesList.length} Hari)',
      });
      
      if (mounted) {
        setState(() => _selectedDates.clear());
        CustomToast.show(context, 'Pembayaran terpilih berhasil dicatat!');
        _fetchData();
        widget.onPaymentSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
         CustomToast.show(context, 'Error: $e');
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _toggleSelectAllUnpaid() {
    setState(() {
      int unpaidCount = 0;
      final startDate = widget.tariffCreatedAt != null ? DateTime(widget.tariffCreatedAt!.year, widget.tariffCreatedAt!.month, widget.tariffCreatedAt!.day) : DateTime(2000);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      
      for (var d in _monthDates) {
        final dStr = DateFormat('yyyy-MM-dd').format(d);
        if (!d.isBefore(startDate) && !d.isAfter(today) && !_globalPaidDates.contains(dStr)) {
          unpaidCount++;
        }
      }
      
      if (_selectedDates.length == unpaidCount && unpaidCount > 0) {
        _selectedDates.clear();
      } else {
        _selectedDates.clear();
        for (var d in _monthDates) {
          final dStr = DateFormat('yyyy-MM-dd').format(d);
          if (!d.isBefore(startDate) && !d.isAfter(today) && !_globalPaidDates.contains(dStr)) {
            _selectedDates.add(dStr);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedDates.isEmpty ? null : _processSelectedPayment,
                    icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    label: Text('Bayar (${_selectedDates.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.checklist, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Daftar Tanggal', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
              ),
              const Spacer(),
              if (widget.isAdmin)
                InkWell(
                  onTap: _toggleSelectAllUnpaid,
                  child: Text(
                    _selectedDates.isNotEmpty ? 'Batal Pilih' : 'Pilih Semua',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _monthDates.length,
            itemBuilder: (context, index) {
              final date = _monthDates[index];
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              
              final startDate = widget.tariffCreatedAt != null ? DateTime(widget.tariffCreatedAt!.year, widget.tariffCreatedAt!.month, widget.tariffCreatedAt!.day) : DateTime(2000);
              final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
              
              final isBeforeStart = date.isBefore(startDate);
              final isFuture = date.isAfter(today);
              
              if (isBeforeStart || isFuture) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                );
              }

              final isPaid = _globalPaidDates.contains(dateStr);
              final isSelected = _selectedDates.contains(dateStr);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (isPaid) {
                      if (widget.isAdmin) {
                        final journalId = _manualPaymentJournalId[dateStr];
                        if (journalId != null) {
                          _promptDeleteManualPayment(journalId);
                        } else {
                          CustomToast.show(context, 'Pembayaran dari scan QR tidak dapat dibatalkan.');
                        }
                      }
                      return;
                    }
                    if (!widget.isAdmin) return;

                    setState(() {
                      if (isSelected) {
                        _selectedDates.remove(dateStr);
                      } else {
                        _selectedDates.add(dateStr);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade50 : (isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPaid ? Colors.green.shade300 : (isSelected ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isPaid ? true : isSelected,
                          activeColor: isPaid ? Colors.green : AppTheme.primaryColor,
                          visualDensity: VisualDensity.compact,
                          onChanged: (_) {
                            // Handled by InkWell onTap
                          },
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontWeight: (isPaid || isSelected) ? FontWeight.bold : FontWeight.normal,
                              color: isPaid ? Colors.green.shade700 : (isSelected ? AppTheme.primaryColor : Colors.black87),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
