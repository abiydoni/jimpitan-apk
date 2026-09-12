import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/main.dart'; // import routeObserver
import 'package:jimpitan/utils/custom_toast.dart';

class SetorJimpitanPage extends StatefulWidget {
  final String villageId;
  const SetorJimpitanPage({super.key, required this.villageId});

  @override
  State<SetorJimpitanPage> createState() => _SetorJimpitanPageState();
}

class _SetorJimpitanPageState extends State<SetorJimpitanPage> with RouteAware {
  bool _isLoading = true;
  final Map<String, int> _dailyTotals = {}; // date -> total amount
  final Set<String> _depositedDates = {};
  String _jimpitanTariffId = 'SETORAN_KHUSUS';

  @override
  void initState() {
    super.initState();
    _fetchData();
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
    _fetchData(showLoading: false);
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final futures = await Future.wait([
        ApiService.getJimpitanHistory(widget.villageId),
        ApiService.getDuesJournals(widget.villageId),
        ApiService.getTariffs(widget.villageId),
      ]);

      final jimpitanHistory = futures[0];
      final duesJournals = futures[1];
      final tariffs = futures[2];

      _dailyTotals.clear();
      _depositedDates.clear();

      // Cari tariffId jimpitan
      for (var t in tariffs) {
        final tMap = t as Map<String, dynamic>;
        final type = tMap['type']?.toString();
        if (tMap['isActive'] == true && (type == 'Harian' || type == 'Jimpitan')) {
          _jimpitanTariffId = tMap['id']?.toString() ?? 'SETORAN_KHUSUS';
          break;
        }
      }

      // 1. Hitung total harian dari Scan QR dan Manual
      for (var doc in jimpitanHistory) {
        final data = doc as Map<String, dynamic>;
        final type = data['type']?.toString();
        // Hanya hitung hasil scan lapangan (QR dan MANUAL). 
        // TAGIHAN tidak dihitung karena saat dicentang sudah otomatis masuk jurnal.
        if (type == 'TAGIHAN') continue;

        final dateStr = data['date']?.toString(); // Format: YYYY-MM-DD
        final amount = (data['amount'] as num?)?.toInt() ?? 0;

        if (dateStr != null && dateStr.isNotEmpty && amount > 0) {
          _dailyTotals[dateStr] = (_dailyTotals[dateStr] ?? 0) + amount;
        }
      }

      // 2. Cari tanggal yang sudah disetor di DuesJournals
      for (var doc in duesJournals) {
        final data = doc as Map<String, dynamic>;
        
        // Cek description atau paidDates
        final desc = data['description']?.toString() ?? '';
        final paidDates = data['paidDates'];
        
        if (desc.startsWith('Setor fisik hasil scan jimpitan')) {
          if (paidDates is List && paidDates.isNotEmpty) {
            _depositedDates.add(paidDates[0].toString());
          } else {
            // fallback ambil date
            final date = data['date']?.toString();
            if (date != null) _depositedDates.add(date);
          }
        }
      }

    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Error memuat data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setor(String date, int amount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Setoran'),
        content: Text('Setor pendapatan jimpitan tanggal $date sebesar ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount)} ke kas pengurus?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Ya, Setor'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    EasyLoading.show(status: 'Memproses setoran...');
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final success = await ApiService.createDuesJournal({
        'villageId': widget.villageId,
        'tariffId': _jimpitanTariffId,
        'journalType': 'KHUSUS',
        'kkId': 'PENGURUS',
        'amount': amount,
        'period': 'HARIAN',
        'timestamp': DateTime.now().toIso8601String(),
        'recordedBy': currentUser?.uid ?? 'unknown',
        'type': 'Jimpitan',
        'description': 'Setor fisik hasil scan jimpitan tanggal $date',
        'date': date,
        'paidDates': [date],
      });

      if (success) {
        if (mounted) {
          CustomToast.show(context, 'Setoran berhasil dicatat!');
          setState(() {
            _depositedDates.add(date);
          });
        }
        _fetchData(); // Refresh data
      } else {
        if (mounted) CustomToast.show(context, 'Gagal mencatat setoran.', isError: true);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, 'Error: $e');
    } finally {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter tanggal yang belum disetor dan urutkan dari yang terbaru
    final pendingDates = _dailyTotals.keys
        .where((date) => !_depositedDates.contains(date))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: CustomGradientAppBar(
        titleText: 'Setor Jimpitan',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(showLoading: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingDates.isEmpty
              ? _buildEmptyState()
              : _buildList(pendingDates),
    );
  }

  Widget _buildEmptyState() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding + 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 16),
            const Text(
              'Semua Jimpitan Sudah Disetor!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tidak ada hasil scan harian yang menunggu untuk disetorkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<String> pendingDates) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        80 + (bottomPadding > 0 ? bottomPadding : 16),
      ),
      itemCount: pendingDates.length,
      itemBuilder: (context, index) {
        final date = pendingDates[index];
        final amount = _dailyTotals[date] ?? 0;

        DateTime? dt;
        try {
          dt = DateFormat('yyyy-MM-dd').parse(date);
        } catch (_) {}
        final displayDate = dt != null ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dt) : date;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setor(date, amount),
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text('Setor', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
