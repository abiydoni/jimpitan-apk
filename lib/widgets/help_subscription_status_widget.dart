import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/pages/payment_instruction_page.dart';
import 'package:jimpitan/pages/payment_success_receipt_page.dart';
import 'package:jimpitan/pages/plan_selection_page.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/date_helper.dart';

class HelpSubscriptionStatusWidget extends StatefulWidget {
  final String villageId;

  const HelpSubscriptionStatusWidget({super.key, required this.villageId});

  @override
  State<HelpSubscriptionStatusWidget> createState() => _HelpSubscriptionStatusWidgetState();
}

class _HelpSubscriptionStatusWidgetState extends State<HelpSubscriptionStatusWidget> {
  bool _isLoading = true;
  Map<String, dynamic>? _invoiceData;
  Map<String, dynamic>? _subscriptionData;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    try {
      final invoice = await ApiService.getLatestInvoice(widget.villageId);
      final sub = await ApiService.getVillageSubscription(widget.villageId);
      if (mounted) {
        setState(() {
          _invoiceData = invoice;
          _subscriptionData = sub;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  num _parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  String _formatCurrency(dynamic amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_parseNum(amount));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoiceData != null) {
      final invoice = _invoiceData!;
      final status = invoice['status']?.toString() ?? 'UNPAID';
      final planName = invoice['planName']?.toString() ?? 'Paket Berlangganan';
      final durationMonths = _parseNum(invoice['durationMonths'] ?? 1);
      final totalAmount = _parseNum(invoice['totalAmount']);
      final invoiceId = invoice['id']?.toString() ?? '';
      final dueDateStr = invoice['dueDate']?.toString() ?? '';
      final invoiceCode = DateHelper.formatInvoiceCode(invoiceId, invoice['createdAt']);

      // 1. Jika sudah pilih paket tapi belum bayar -> GANTIKAN DENGAN INVOICE
      if (status == 'UNPAID') {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.shade400, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'INVOICE TAGIHAN - MENUNGGU PEMBAYARAN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text(
                      '#$invoiceCode',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Durasi Langganan:', style: TextStyle(color: Colors.black87, fontSize: 13)),
                        Text('$durationMonths Bulan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Tagihan:', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        Text(
                          _formatCurrency(totalAmount),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                    if (dueDateStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Batas Pembayaran:', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          Text(
                            DateHelper.formatJakartaDateText(dueDateStr),
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentInstructionPage(
                              invoiceId: invoiceId,
                              totalAmount: totalAmount,
                              invoiceData: invoice,
                            ),
                          ),
                        ).then((_) => _fetchStatus());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Bayar Tagihan Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlanSelectionPage(villageId: widget.villageId),
                          ),
                        ).then((_) => _fetchStatus());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Ganti / Pilih Ulang Paket Langganan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // 2. Jika sudah bayar dan menunggu verifikasi -> GANTI DENGAN VERIFIKASI PEMBAYARAN
      else if (status == 'PENDING_VERIFICATION') {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blue.shade400, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'VERIFIKASI PEMBAYARAN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text(
                      '#$invoiceCode',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Dibayarkan:', style: TextStyle(color: Colors.black87, fontSize: 13)),
                        Text(
                          _formatCurrency(totalAmount),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bukti pembayaran Anda telah diterima dan sedang diverifikasi oleh tim admin (5-15 menit).',
                              style: TextStyle(fontSize: 12.5, color: Colors.blue.shade900, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentSuccessReceiptPage(
                              invoiceId: invoiceId,
                              totalAmount: totalAmount,
                              invoiceData: invoice,
                              status: 'PENDING_VERIFICATION',
                            ),
                          ),
                        ).then((_) => _fetchStatus());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Lihat Nota & Cek Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: _fetchStatus,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh Status Sekarang', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // 3. Jika sudah diverifikasi & Lunas
      else if (status == 'PAID') {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade300, width: 1.5),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tagihan $planName Lunas',
                        style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Layanan desa aktif seutuhnya.',
                        style: TextStyle(color: Colors.green.shade800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentSuccessReceiptPage(
                          invoiceId: invoiceId,
                          totalAmount: totalAmount,
                          invoiceData: invoice,
                          status: 'PAID',
                        ),
                      ),
                    );
                  },
                  child: const Text('Lihat Nota', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 4. Apabila BELUM MELAKUKAN APA APA (belum ada invoice aktif / belum pilih paket)
    if (_subscriptionData != null) {
      final sub = _subscriptionData!;
      final endDateStr = sub['endDate']?.toString();
      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null) {
          final daysLeft = DateHelper.getJakartaDaysDifference(endDate);
          final isExpired = daysLeft < 0;
          final dateStr = DateHelper.formatJakartaDateText(endDateStr);

          // HANYA TAMPILKAN JIKA SISA WAKTU <= 7 HARI ATAU SUDAH EXPIRED
          if (daysLeft > 7) {
            return const SizedBox.shrink();
          }

          String notifTitle;
          if (daysLeft == 0) {
            notifTitle = '⚠️ Masa aktif layanan desa berakhir hari ini ($dateStr).';
          } else if (isExpired) {
            notifTitle = '⚠️ Masa aktif layanan desa telah berakhir sejak $dateStr.';
          } else {
            notifTitle = '⚠️ Masa aktif layanan desa berakhir dalam $daysLeft hari ($dateStr).';
          }

          final textColor = isExpired ? Colors.red.shade900 : Colors.orange.shade900;
          final iconColor = isExpired ? Colors.red.shade700 : Colors.orange.shade800;
          final bgColor = isExpired ? Colors.red.shade50 : Colors.orange.shade50;
          final borderColor = isExpired ? Colors.red.shade300 : Colors.orange.shade300;

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isExpired ? Icons.error_outline : Icons.warning_amber_rounded, color: iconColor, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notifTitle,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Silakan segera melakukan pembayaran sebelum $dateStr agar layanan desa tidak terputus.',
                    style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlanSelectionPage(villageId: widget.villageId),
                        ),
                      ).then((_) => _fetchStatus());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired ? Colors.red.shade600 : Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Pilih Paket Langganan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    return const SizedBox.shrink();
  }
}
