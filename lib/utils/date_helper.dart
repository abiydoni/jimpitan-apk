class DateHelper {
  /// Mengonversi DateTime apa pun ke zona waktu standar Asia/Jakarta (WIB = UTC+7)
  static DateTime toJakartaTime(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(const Duration(hours: 7));
  }

  /// Membandingkan selisih hari kalender di Asia/Jakarta (WIB)
  static int getJakartaDaysDifference(DateTime targetDate) {
    final nowJkt = toJakartaTime(DateTime.now());
    final targetJkt = toJakartaTime(targetDate);

    final today = DateTime.utc(nowJkt.year, nowJkt.month, nowJkt.day);
    final target = DateTime.utc(targetJkt.year, targetJkt.month, targetJkt.day);

    return target.difference(today).inDays;
  }

  /// Memformat tanggal ke string dd/MM/yyyy (Asia/Jakarta)
  static String formatJakartaDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateString);
      final jkt = toJakartaTime(dt);
      final day = jkt.day.toString().padLeft(2, '0');
      final month = jkt.month.toString().padLeft(2, '0');
      final year = jkt.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return dateString;
    }
  }

  /// Memformat tanggal ke format teks seperti "dd MMM yyyy" di Asia/Jakarta
  static String formatJakartaDateText(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateString);
      final jkt = toJakartaTime(dt);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final day = jkt.day.toString().padLeft(2, '0');
      final month = months[jkt.month - 1];
      final year = jkt.year.toString();
      return '$day $month $year';
    } catch (_) {
      return dateString;
    }
  }

  /// Memformat ID tagihan menjadi nomor invoice resmi (misal: INV/JMP/2026/0004)
  static String formatInvoiceCode(dynamic id, [dynamic dateVal]) {
    if (id == null || id.toString().isEmpty) return 'INV/JMP/0000';
    String idStr = id.toString();
    // Jika sudah memiliki format INV atau /, kembalikan langsung
    if (idStr.toUpperCase().contains('INV') || idStr.contains('/')) return idStr;
    
    final numPadded = idStr.padLeft(4, '0');
    String yearStr = DateTime.now().year.toString();
    if (dateVal != null && dateVal.toString().isNotEmpty) {
      final dt = DateTime.tryParse(dateVal.toString());
      if (dt != null) {
        yearStr = dt.year.toString();
      }
    }
    return 'INV/JMP/$yearStr/$numPadded';
  }
}
