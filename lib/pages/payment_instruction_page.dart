import 'package:flutter/material.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimpitan/utils/image_compressor.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/date_helper.dart';
import 'package:jimpitan/pages/payment_success_receipt_page.dart';

class PaymentInstructionPage extends StatefulWidget {
  final String invoiceId;
  final num totalAmount;
  final Map<String, dynamic>? invoiceData;

  const PaymentInstructionPage({
    super.key,
    required this.invoiceId,
    required this.totalAmount,
    this.invoiceData,
  });

  @override
  State<PaymentInstructionPage> createState() => _PaymentInstructionPageState();
}

class _PaymentInstructionPageState extends State<PaymentInstructionPage> {
  bool _isLoading = true;
  String? _bankAccountInfo;
  String? _base64Proof;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchBankAccount();
  }

  Future<void> _fetchBankAccount() async {
    final info = await ApiService.getSaasBankAccount();
    if (mounted) {
      setState(() {
        _bankAccountInfo = info ?? 'Silakan hubungi Admin Pusat untuk informasi rekening pembayaran.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = await ImageCompressor.compressImage(bytes);
        if (base64String != null) {
          setState(() {
            _base64Proof = base64String;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal memilih gambar: $e');
      }
    }
  }

  Future<void> _submitProof() async {
    if (_base64Proof == null) {
      CustomToast.show(context, 'Silakan unggah bukti pembayaran terlebih dahulu.');
      return;
    }
    
    setState(() => _isUploading = true);
    final success = await ApiService.uploadPaymentProof(widget.invoiceId, _base64Proof!);
    setState(() => _isUploading = false);

    if (success && mounted) {
      CustomToast.show(context, 'Bukti pembayaran berhasil diunggah!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessReceiptPage(
            invoiceId: widget.invoiceId,
            totalAmount: widget.totalAmount,
            invoiceData: widget.invoiceData,
            status: 'PENDING_VERIFICATION',
          ),
        ),
      );
    } else if (mounted) {
      CustomToast.show(context, 'Gagal mengunggah bukti pembayaran.');
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

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withValues(alpha: 0.4), Colors.white],
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
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'NOTA TAGIHAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'BELUM DIBAYAR',
                    style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11),
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
                  Text('Biaya Paket Langganan ($label)', style: const TextStyle(fontSize: 14)),
                  Text(_formatCurrency(baseAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Biaya Dasar ($label)', style: const TextStyle(fontSize: 14)),
                  Text(_formatCurrency(baseAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Biaya Warga ($kkCount KK)', style: const TextStyle(fontSize: 14)),
                  Text(_formatCurrency(kkAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ],
            if (taxAmount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pajak PPN (${taxPercentage == taxPercentage.toInt() ? taxPercentage.toInt() : taxPercentage}%)', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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
                const Text('TOTAL TAGIHAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  _formatCurrency(widget.totalAmount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Tagihan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNotaCard(),
                  const SizedBox(height: 24),
                  const Text('1. Transfer ke Rekening Berikut:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _bankAccountInfo ?? '',
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('2. Unggah Bukti Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_base64Proof != null)
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(_base64Proof!)),
                          fit: BoxFit.contain,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _base64Proof = null),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: (_isUploading || _base64Proof == null) ? null : _submitProof,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Kirim Bukti Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
