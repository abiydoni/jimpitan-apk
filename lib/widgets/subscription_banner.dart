import 'package:flutter/material.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/date_helper.dart';

class SubscriptionBanner extends StatelessWidget {
  final Future<Map<String, dynamic>?>? future;
  final String? villageId;
  final bool showButton;

  const SubscriptionBanner({
    super.key,
    this.future,
    this.villageId,
    this.showButton = false,
  });

  @override
  Widget build(BuildContext context) {
    if (future == null && villageId == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: future ?? ApiService.getVillageSubscription(villageId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final sub = snapshot.data!;
        final endDateStr = sub['endDate'];
        if (endDateStr == null) return const SizedBox.shrink();

        final endDate = DateTime.tryParse(endDateStr.toString());
        if (endDate == null) return const SizedBox.shrink();

        final daysLeft = DateHelper.getJakartaDaysDifference(endDate);

        // Di Dashboard Halaman Utama, hanya tampilkan jika sisa waktu <= 7 hari atau sudah habis
        if (daysLeft > 7) return const SizedBox.shrink();

        final isExpired = daysLeft < 0;
        final dateStr = DateHelper.formatJakartaDate(endDateStr.toString());

        String message;
        if (daysLeft == 0) {
          message = 'Masa aktif layanan desa berakhir hari ini ($dateStr).';
        } else if (isExpired) {
          message = 'Masa aktif layanan desa telah berakhir sejak $dateStr.';
        } else {
          message = 'Masa aktif layanan desa berakhir dalam $daysLeft hari ($dateStr).';
        }

        final textColor = isExpired ? Colors.red.shade900 : Colors.orange.shade900;
        final iconColor = isExpired ? Colors.red.shade700 : Colors.orange.shade800;
        final bgColor = isExpired ? Colors.red.shade50 : Colors.orange.shade50;
        final borderColor = isExpired ? Colors.red.shade200 : Colors.orange.shade200;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isExpired ? Icons.error_outline : Icons.warning_amber_rounded,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
