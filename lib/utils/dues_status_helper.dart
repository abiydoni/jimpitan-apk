/// Helper untuk menghitung status pembayaran KK per jenis iuran
class DuesStatusHelper {
  /// Mengembalikan status 'Lunas', 'Belum Lunas', 'Dicicil', atau null (untuk Harian/Jimpitan)
  static String? getKkStatus({
    required String tariffType,
    required int expectedAmount,
    required int year,
    required List<dynamic> kkJournals,
    bool isExempted = false,
  }) {
    if (isExempted) return 'Dibebaskan';
    // Harian seperti jimpitan tidak usah ada status
    if (tariffType == 'Harian' || tariffType == 'Jimpitan') return null;

    if (tariffType == 'Bulanan') {
      // Status LUNAS jika selama setahun sudah dibayarkan (12 bulan)
      int paidMonthsCount = 0;
      int totalYearPaid = 0;

      for (int m = 1; m <= 12; m++) {
        final periodStr = '$year-${m.toString().padLeft(2, '0')}';
        final monthDocs = kkJournals.where((doc) {
          final map = doc as Map<String, dynamic>;
          final p = map['period']?.toString();
          final desc = map['description']?.toString() ?? '';
          return p == periodStr || (p == null && desc.contains(periodStr));
        }).toList();

        final mPaid = monthDocs.fold<int>(
          0,
          (sum, d) => sum + (((d as Map)['amount'] ?? 0) as num).toInt(),
        );

        totalYearPaid += mPaid;
        if (expectedAmount > 0 && mPaid >= expectedAmount) {
          paidMonthsCount++;
        }
      }

      final isAllMonthsPaid = paidMonthsCount >= 12 ||
          (expectedAmount > 0 && totalYearPaid >= 12 * expectedAmount);

      return isAllMonthsPaid ? 'Lunas' : 'Belum Lunas';
    } else if (tariffType == 'Tahunan') {
      // Status LUNAS jika tahunan sudah terbayar
      final periodStr = year.toString();
      final yearDocs = kkJournals.where((doc) {
        final map = doc as Map<String, dynamic>;
        final p = map['period']?.toString();
        final desc = map['description']?.toString() ?? '';
        return p == periodStr || (p == null && desc.contains('Tahun $year'));
      }).toList();

      final totalPaid = yearDocs.fold<int>(
        0,
        (sum, d) => sum + (((d as Map)['amount'] ?? 0) as num).toInt(),
      );

      if (expectedAmount > 0 && totalPaid >= expectedAmount) {
        return 'Lunas';
      } else if (totalPaid > 0) {
        return 'Dicicil';
      }
      return 'Belum Lunas';
    } else {
      // Sekali Bayar: Status LUNAS apabila semua sudah terbayar
      final totalPaid = kkJournals.fold<int>(
        0,
        (sum, d) => sum + (((d as Map)['amount'] ?? 0) as num).toInt(),
      );

      if (expectedAmount > 0 && totalPaid >= expectedAmount) {
        return 'Lunas';
      } else if (totalPaid > 0) {
        return 'Dicicil';
      }
      return 'Belum Lunas';
    }
  }
}

