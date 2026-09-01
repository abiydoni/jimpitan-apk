import 'package:flutter/material.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/date_helper.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/pages/payment_instruction_page.dart';
import 'package:jimpitan/pages/plan_selection_page.dart';

class PaymentSuccessReceiptPage extends StatefulWidget {
  final String invoiceId;
  final num totalAmount;
  final Map<String, dynamic>? invoiceData;
  final String status;

  const PaymentSuccessReceiptPage({
    super.key,
    required this.invoiceId,
    required this.totalAmount,
    this.invoiceData,
    this.status = 'PENDING_VERIFICATION',
  });

  @override
  State<PaymentSuccessReceiptPage> createState() => _PaymentSuccessReceiptPageState();
}

class _PaymentSuccessReceiptPageState extends State<PaymentSuccessReceiptPage> {
  late String _currentStatus;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  num _parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  String _formatCurrency(dynamic amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_parseNum(amount));
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      final villageId = widget.invoiceData?['villageId']?.toString() ?? '';
      final latest = await ApiService.getLatestInvoice(villageId);
      if (mounted) {
        setState(() {
          _isChecking = false;
          if (latest != null && latest['status'] != null) {
            _currentStatus = latest['status'].toString();
          }
        });
        if (_currentStatus == 'PAID') {
          CustomToast.show(context, 'Selamat! Pembayaran Anda telah terverifikasi & Lunas!');
        } else if (_currentStatus == 'PENDING_VERIFICATION') {
          CustomToast.show(context, 'Status: Masih dalam proses verifikasi Admin Pusat.');
        } else {
          CustomToast.show(context, 'Status tagihan saat ini: $_currentStatus');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        CustomToast.show(context, 'Gagal mengecek status: $e', isError: true);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      ApiService.isSuspendedNotifier.value = false;
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal keluar: $e', isError: true);
      }
    }
  }

  Widget _buildNotaCard() {
    final data = widget.invoiceData;
    final planName = data?['planName']?.toString() ?? 'Paket Berlangganan';
    final durationMonths = _parseNum(data?['durationMonths'] ?? 1);
    final durationUnit = data?['durationUnit']?.toString() ?? 'MONTHLY';
    final baseAmount = _parseNum(data?['baseAmount'] ?? widget.totalAmount);
    final kkAmount = _parseNum(data?['kkAmount']);
    final kkCount = _parseNum(data?['kkCount']);
    final taxAmount = _parseNum(data?['taxAmount']);
    final taxPercentage = _parseNum(data?['taxPercentage'] ?? 10);
    final isFlat = kkAmount == 0 || (data?['planName']?.toString().toLowerCase().contains('flat') ?? false) || (data?['planType'] == 'FLAT');

    String label = '$durationMonths Bulan';
    if (durationUnit == 'YEARS' || durationUnit == 'YEARLY') {
      label = '${durationMonths ~/ 12} Tahun';
    }

    final isPaid = _currentStatus == 'PAID';
    final isUnpaid = _currentStatus == 'UNPAID';
    final badgeText = isPaid ? 'LUNAS / TERVERIFIKASI' : (isUnpaid ? 'MENUNGGU PEMBAYARAN' : 'MENUNGGU VALIDASI');
    final badgeColor = isPaid ? Colors.green : (isUnpaid ? Colors.orange.shade800 : Colors.blue);
    final badgeBgColor = isPaid ? Colors.green.shade100 : (isUnpaid ? Colors.orange.shade100 : Colors.blue.shade100);

    return Card(
      elevation: 6,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [badgeBgColor.withValues(alpha: 0.4), Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(isPaid ? Icons.verified : Icons.receipt_long, color: badgeColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'NOTA PEMBAYARAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('No. Invoice:', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  Text(
                    DateHelper.formatInvoiceCode(widget.invoiceId, data?['createdAt']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Item Pesanan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    planName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(label, style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1, color: Colors.black12),
            const SizedBox(height: 12),
            const Text('Rincian Perhitungan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            if (isFlat) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Biaya Paket Langganan ($label)', style: const TextStyle(fontSize: 14))),
                  Text(_formatCurrency(baseAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Biaya Dasar ($label)', style: const TextStyle(fontSize: 14))),
                  Text(_formatCurrency(baseAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Biaya Warga ($kkCount KK)', style: const TextStyle(fontSize: 14))),
                  Text(_formatCurrency(kkAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ],
            if (taxAmount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Pajak PPN (${taxPercentage == taxPercentage.toInt() ? taxPercentage.toInt() : taxPercentage}%)', style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
                  Text(_formatCurrency(taxAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final dashWidth = 6.0;
                final dashCount = (constraints.constrainWidth() / (2 * dashWidth)).floor();
                return Flex(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  direction: Axis.horizontal,
                  children: List.generate(dashCount, (_) {
                    return SizedBox(
                      width: dashWidth,
                      height: 1.5,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey.shade400)),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL DIBAYARKAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  _formatCurrency(widget.totalAmount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green.shade700 : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _currentStatus == 'PAID';
    final isUnpaid = _currentStatus == 'UNPAID';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPaid ? 'Nota Lunas' : (isUnpaid ? 'Menunggu Pembayaran' : 'Menunggu Validasi')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.shade50 : (isUnpaid ? Colors.orange.shade50 : Colors.blue.shade50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPaid ? Colors.green.shade200 : (isUnpaid ? Colors.orange.shade200 : Colors.blue.shade200)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isPaid ? Colors.green : (isUnpaid ? Colors.orange : Colors.blue)).withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle : (isUnpaid ? Icons.payment : Icons.verified_user_outlined),
                      size: 54,
                      color: isPaid ? Colors.green : (isUnpaid ? Colors.orange.shade800 : Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPaid ? 'Pembayaran Berhasil & Lunas!' : (isUnpaid ? 'Menunggu Pembayaran' : 'Bukti Pembayaran Diterima'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPaid ? Colors.green.shade900 : (isUnpaid ? Colors.orange.shade900 : Colors.blue.shade900),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPaid
                        ? 'Terima kasih! Pembayaran Anda telah dikonfirmasi. Layanan SaaS desa Anda sudah aktif seutuhnya.'
                        : (isUnpaid
                            ? 'Silakan lakukan pembayaran sesuai nota tagihan di bawah ini agar layanan desa Anda dapat segera aktif.'
                            : 'Bukti transfer Anda sedang dicek dan divalidasi oleh Admin Pusat (estimasi 5 - 15 menit). Simpan nota di bawah ini sebagai bukti resmi pembayaran Anda.'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isPaid ? Colors.green.shade800 : (isUnpaid ? Colors.orange.shade800 : Colors.blue.shade800),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildNotaCard(),
            const SizedBox(height: 32),
            if (isUnpaid) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentInstructionPage(
                        invoiceId: widget.invoiceId,
                        totalAmount: widget.totalAmount,
                        invoiceData: widget.invoiceData,
                      ),
                    ),
                  ).then((_) => _checkStatus());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payment),
                label: const Text('Bayar Tagihan Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanSelectionPage(villageId: widget.invoiceData?['villageId']?.toString() ?? ''),
                    ),
                  ).then((_) => _checkStatus());
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Ganti / Pilih Ulang Paket Langganan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkStatus,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isPaid ? Colors.green : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _isChecking ? 'Mengecek Status...' : 'Cek Status Pembayaran',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.home),
                label: const Text('Kembali ke Menu Utama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _logout,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.red.shade700,
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar / Kembali ke Halaman Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
