import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/pages/payment_instruction_page.dart';

class PlanSelectionPage extends StatefulWidget {
  final String villageId;

  const PlanSelectionPage({super.key, required this.villageId});

  @override
  State<PlanSelectionPage> createState() => _PlanSelectionPageState();
}

class _PlanSelectionPageState extends State<PlanSelectionPage> {
  bool _isLoading = true;
  List<dynamic> _plans = [];
  int? _selectedPlanId;
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoading = true);
    final plans = await ApiService.getPlans();
    if (mounted) {
      setState(() {
        final filtered = plans.where((p) => p['isActive'] != false && !(p['name']?.toString().toLowerCase().contains('trial') ?? false)).toList();
        // Urutkan dari masa paket terendah
        filtered.sort((a, b) {
          int getMonths(dynamic p) {
            int m = int.tryParse(p['durationMonths']?.toString() ?? '1') ?? 1;
            final u = p['durationUnit']?.toString().toUpperCase() ?? '';
            if (u.contains('YEAR') || u.contains('TAHUN')) return m * 12;
            if (u.contains('WEEK') || u.contains('MINGGU')) return (m * 0.25).round();
            return m;
          }
          return getMonths(a).compareTo(getMonths(b));
        });
        _plans = filtered;
        _isLoading = false;
      });
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

  Map<String, dynamic> _getDurationTheme(dynamic monthsVal, dynamic unitVal) {
    int months = 1;
    if (monthsVal != null) {
      months = int.tryParse(monthsVal.toString()) ?? 1;
    } else if (unitVal != null) {
      final unitStr = unitVal.toString().toUpperCase();
      if (unitStr.contains('YEAR') || unitStr == 'TAHUNAN') months = 12;
    }

    if (months >= 24) {
      return {
        'label': '2 Tahun (24 Bln)',
        'badge': 'VIP SPECIAL',
        'color': const Color(0xFFE11D48),
        'bgColor': const Color(0xFFFFE4E6),
        'icon': Icons.workspace_premium,
        'periodText': '/ 2 Tahun',
      };
    } else if (months >= 12) {
      return {
        'label': '1 Tahun (12 Bln)',
        'badge': 'BEST VALUE',
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF3E8FF),
        'icon': Icons.emoji_events,
        'periodText': '/ 1 Tahun',
      };
    } else if (months >= 6) {
      return {
        'label': '6 Bulan',
        'badge': 'POPULER',
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFEF3C7),
        'icon': Icons.bolt,
        'periodText': '/ 6 Bulan',
      };
    } else if (months >= 3) {
      return {
        'label': '3 Bulan',
        'badge': 'HEMAT',
        'color': const Color(0xFF0D9488),
        'bgColor': const Color(0xFFCCFBF1),
        'icon': Icons.local_offer,
        'periodText': '/ 3 Bulan',
      };
    } else {
      return {
        'label': '1 Bulan',
        'badge': 'REGULER',
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFDBEAFE),
        'icon': Icons.calendar_today,
        'periodText': '/ Bulan',
      };
    }
  }

  Future<void> _handleOrder() async {
    if (_selectedPlanId == null) {
      CustomToast.show(context, 'Silakan pilih paket terlebih dahulu.');
      return;
    }

    setState(() => _isOrdering = true);
    try {
      final invoice = await ApiService.orderPlan(widget.villageId, _selectedPlanId!);
      setState(() => _isOrdering = false);

      if (invoice != null && mounted) {
        CustomToast.show(context, 'Berhasil memesan paket!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentInstructionPage(
              invoiceId: invoice['id']?.toString() ?? '',
              totalAmount: _parseNum(invoice['totalAmount']),
              invoiceData: invoice,
            ),
          ),
        );
      } else if (mounted) {
        CustomToast.show(context, 'Gagal memesan paket. Silakan coba lagi.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOrdering = false);
        final errMsg = e.toString().replaceAll('Exception: ', '');
        CustomToast.show(context, 'Gagal: $errMsg', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomGradientAppBar(
        titleText: 'Pilih Paket Langganan',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('Tidak ada paket yang tersedia saat ini.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final isSelected = _selectedPlanId == plan['id'];
                          final theme = _getDurationTheme(plan['durationMonths'], plan['durationUnit']);
                          final color = theme['color'] as Color;
                          final bgColor = theme['bgColor'] as Color;
                          final icon = theme['icon'] as IconData;
                          final badge = theme['badge'] as String;
                          final label = theme['label'] as String;
                          final periodText = theme['periodText'] as String;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPlanId = plan['id'];
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? color : Colors.grey.shade300,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isSelected ? color : bgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                plan['name'] ?? 'Paket Berlangganan',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isSelected ? color : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                badge,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (plan['description'] != null && plan['description'].toString().isNotEmpty) ...[
                                          Text(
                                            plan['description'].toString(),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                        ],
                                        Text(
                                          'Maks. ${plan['maxKk'] ?? plan['maxUsers'] ?? 'Tidak Terbatas'} KK • $label',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _formatCurrency(plan['basePrice'] ?? plan['baseFee'] ?? plan['price'] ?? 0),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: isSelected ? color : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        periodText,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 6),
                                      Icon(
                                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                        color: isSelected ? color : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          )
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '* Tagihan akhir akan ditambah pajak (PPN 10% atau sesuai tarif yang diatur Super Admin)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _isOrdering ? null : _handleOrder,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: _isOrdering
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Lanjutkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
    );
  }
}
