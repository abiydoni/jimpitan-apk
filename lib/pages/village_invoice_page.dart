import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/pages/plan_selection_page.dart';
import 'package:jimpitan/pages/payment_success_receipt_page.dart';

class VillageInvoicePage extends StatefulWidget {
  final String villageId;
  const VillageInvoicePage({super.key, required this.villageId});

  @override
  State<VillageInvoicePage> createState() => _VillageInvoicePageState();
}

class _VillageInvoicePageState extends State<VillageInvoicePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _invoiceData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchInvoice();
  }

  Future<void> _fetchInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data = await ApiService.getLatestInvoice(widget.villageId);
      if (data != null) {
        setState(() {
          _invoiceData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _invoiceData = null;
          _errorMessage = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat tagihan: $e';
        _isLoading = false;
      });
    }
  }

  num _parseNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _errorMessage.isEmpty && _invoiceData != null) {
      final status = _invoiceData!['status']?.toString() ?? 'UNPAID';
      return PaymentSuccessReceiptPage(
        invoiceId: _invoiceData!['id']?.toString() ?? '',
        totalAmount: _parseNum(_invoiceData!['totalAmount']),
        invoiceData: _invoiceData,
        status: status,
      );
    }

    return Scaffold(
      appBar: const CustomGradientAppBar(
        titleText: 'Info Berlangganan & Tagihan',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 64, color: Colors.blue),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchInvoice,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.card_membership, size: 64, color: Colors.blue),
                        const SizedBox(height: 16),
                        const Text(
                          'Desa Anda belum memiliki riwayat tagihan aktif. Silakan pilih paket langganan untuk mulai menggunakan Jimpitan Digital secara penuh.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PlanSelectionPage(villageId: widget.villageId)),
                            ).then((_) => _fetchInvoice());
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          ),
                          icon: const Icon(Icons.card_membership),
                          label: const Text('Pilih Paket Langganan'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Kembali'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
