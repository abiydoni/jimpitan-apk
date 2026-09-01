import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ResidentPdfExportData {
  final String headName;
  final String noKK;
  final String address;
  final String phone;
  final String email;
  final List<ResidentPdfMember> members;

  ResidentPdfExportData({
    required this.headName,
    required this.noKK,
    required this.address,
    required this.phone,
    required this.email,
    required this.members,
  });
}

class ResidentPdfMember {
  final String name;
  final String relation;
  final String nik;
  final String gender;
  final String birthPlace;
  final String birthDate;
  final String religion;
  final String occupation;
  final String status;
  final String email;
  final String roles;

  ResidentPdfMember({
    required this.name,
    required this.relation,
    required this.nik,
    required this.gender,
    required this.birthPlace,
    required this.birthDate,
    required this.religion,
    required this.occupation,
    required this.status,
    required this.email,
    required this.roles,
  });
}

ResidentPdfExportData buildResidentPdfExportData(
  Map<String, dynamic> userData,
) {
  final family = List<Map<String, dynamic>>.from(
    userData['familyMembers'] ?? [],
  );
  final head = family.isNotEmpty
      ? family.firstWhere(
          (member) => member['statusHubungan'] == 'Kepala Keluarga',
          orElse: () => family.first,
        )
      : <String, dynamic>{};

  final members = family.map((member) {
    final rawRoles = member['roles'] ?? [];
    final roles = rawRoles is List
        ? rawRoles.whereType<String>().join(', ')
        : rawRoles.toString();

    return ResidentPdfMember(
      name: (member['namaLengkap'] ?? '').toString(),
      relation: (member['statusHubungan'] ?? '-').toString(),
      nik: (member['nik'] ?? '').toString(),
      gender: (member['jenisKelamin'] ?? '').toString(),
      birthPlace: (member['tempatLahir'] ?? '').toString(),
      birthDate: (member['tanggalLahir'] ?? '').toString(),
      religion: (member['agama'] ?? '').toString(),
      occupation: (member['pekerjaan'] ?? '').toString(),
      status: (member['statusHidup'] ?? '').toString(),
      email: (member['email'] ?? '').toString().isEmpty
          ? '-'
          : (member['email'] ?? '').toString(),
      roles: roles.isEmpty ? '-' : roles,
    );
  }).toList();

  // Menggunakan null-aware operator untuk kode yang lebih bersih
  return ResidentPdfExportData(
    headName: (head['namaLengkap'] ?? userData['name'] ?? '').toString(),
    noKK: (userData['noKK'] ?? '').toString(),
    address: (userData['alamat'] ?? '').toString(),
    phone: (userData['phone'] ?? userData['phoneNumber'] ?? '').toString(),
    email: (userData['email'] ?? '').toString(),
    members: members,
  );
}

/// Fungsi bantuan untuk menampilkan '-' jika string kosong.
String _displayValue(String value) => value.isEmpty ? '-' : value;

/// Widget terpusat untuk membangun tampilan laporan data warga.
pw.Widget _buildResidentReport(ResidentPdfExportData exportData) {
  final now = DateTime.now();
  final docNo =
      'RES-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

  final memberRows = <List<String>>[];
  for (var i = 0; i < exportData.members.length; i++) {
    final member = exportData.members[i];
    memberRows.add([
      '${i + 1}',
      _displayValue(member.name),
      _displayValue(member.nik),
      _displayValue(member.relation),
      _displayValue(member.gender),
      '${_displayValue(member.birthPlace)}, ${_displayValue(member.birthDate)}',
      _displayValue(member.religion),
      _displayValue(member.occupation),
      _displayValue(member.status),
      _displayValue(member.email),
      _displayValue(member.roles),
    ]);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey900,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LAPORAN DATA WARGA',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Ringkasan resmi data warga dan anggota keluarga',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'No. Dok: $docNo',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Tanggal: ${now.day}/${now.month}/${now.year}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Ringkasan Data Keluarga',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'No. KK',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_displayValue(exportData.noKK)),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Kepala Keluarga',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_displayValue(exportData.headName)),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Alamat',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_displayValue(exportData.address)),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  'Kontak',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  '${_displayValue(exportData.phone)} / ${_displayValue(exportData.email)}',
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        'Daftar Anggota Keluarga',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: [
          'No',
          'Nama',
          'NIK',
          'Hubungan',
          'Gender',
          'TTL',
          'Agama',
          'Pekerjaan',
          'Status',
          'Email',
          'Role',
        ],
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          fontSize: 9,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellHeight: 24,
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.center,
          3: pw.Alignment.center,
          4: pw.Alignment.center,
          5: pw.Alignment.centerLeft,
          6: pw.Alignment.center,
          7: pw.Alignment.centerLeft,
          8: pw.Alignment.center,
          9: pw.Alignment.centerLeft,
          10: pw.Alignment.center,
        },
        data: memberRows,
      ),
      pw.Spacer(),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF1F5F9),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Text(
          'Dokumen ini dibuat otomatis dari aplikasi Jimpitan.',
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ),
    ],
  );
}

Future<void> shareResidentPdf({
  required Map<String, dynamic> userData,
  required String fileName,
}) async {
  final exportData = buildResidentPdfExportData(userData);
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        return _buildResidentReport(exportData);
      },
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

List<pw.Widget> _buildAllResidentsTable({
  required List<Map<String, dynamic>> residents,
}) {
  final now = DateTime.now();
  final allMembers = <List<String>>[];
  int counter = 1;

  // Urutkan warga berdasarkan nama kepala keluarga
  residents.sort((a, b) {
    final nameA = (a['name'] ?? '').toString();
    final nameB = (b['name'] ?? '').toString();
    return nameA.compareTo(nameB);
  });

  for (final user in residents) {
    final name = user['name']?.toString() ?? '';
    final nik = user['nik']?.toString() ?? '';
    final noKK = user['noKK']?.toString() ?? '';
    final relation = user['statusHubungan']?.toString() ?? 'Anggota';
    final gender = user['jenisKelamin']?.toString() ?? '';
    final address = user['alamat']?.toString() ?? '';

    allMembers.add([
      (counter++).toString(),
      _displayValue(name),
      _displayValue(nik),
      _displayValue(noKK),
      _displayValue(relation),
      _displayValue(gender),
      _displayValue(address),
    ]);
  }

  return [
    pw.Text(
      'Laporan Data Seluruh Warga',
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    pw.Text(
      'Dokumen dibuat pada: ${DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(now)}',
    ),
    pw.SizedBox(height: 20),
    pw.TableHelper.fromTextArray(
      headers: [
        'No',
        'Nama Lengkap',
        'NIK',
        'No. KK',
        'Hubungan',
        'Gender',
        'Alamat',
      ],
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 24,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
        6: pw.Alignment.centerLeft,
      },
      data: allMembers,
    ),
  ];
}

Future<void> shareAllResidentsPdf({
  required List<Map<String, dynamic>> residents,
  required String fileName,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        return _buildAllResidentsTable(residents: residents);
      },
      footer: (pw.Context context) {
        return pw.Center(
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        );
      },
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

Future<void> shareFinancialJournalPdf({
  required String title,
  required String subtitle,
  required String fileName,
  required List<Map<String, dynamic>> transactions,
  required int totalIncome,
  required int totalExpense,
}) async {
  final doc = pw.Document();

  String formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  final now = DateTime.now();
  final docNo =
      'JRN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  final tableRows = <List<String>>[];
  for (var i = 0; i < transactions.length; i++) {
    final item = transactions[i];
    tableRows.add([
      '${i + 1}',
      item['description']?.toString() ?? '-',
      item['dateText']?.toString() ?? '-',
      item['typeLabel']?.toString() ?? '-',
      formatCurrency((item['amount'] as num?)?.toInt() ?? 0),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        final incomeColor = PdfColor.fromInt(0xFF15803D);
        final expenseColor = PdfColor.fromInt(0xFFB91C1C);
        return [
          pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'LAPORAN KEUANGAN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'No: $docNo',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Tanggal: ${now.day}/${now.month}/${now.year}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFECFDF3),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pemasukan',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(totalIncome),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: incomeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFEF2F2),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Pengeluaran',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(totalExpense),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: expenseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Detail Transaksi',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Keterangan', 'Tanggal', 'Tipe', 'Jumlah'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 24,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              data: tableRows,
            ),
        ];
      },
      footer: (pw.Context context) {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'Dokumen ini dibuat otomatis dari aplikasi Jimpitan.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

Future<void> shareSchedulePdf({
  required String title,
  required String subtitle,
  required String fileName,
  required Map<String, List<String>> groupedSchedules,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();

  pw.Widget buildDaysTable(List<String> days) {
    int maxLen = 0;
    for (String day in days) {
      if ((groupedSchedules[day]?.length ?? 0) > maxLen) {
        maxLen = groupedSchedules[day]!.length;
      }
    }

    final tableRows = <pw.TableRow>[];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: days.map((day) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: pw.Text(
              day.isEmpty ? '' : day.toUpperCase(),
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              textAlign: pw.TextAlign.center,
            ),
          );
        }).toList(),
      )
    );

    // Data Rows
    for (int i = 0; i < maxLen; i++) {
      tableRows.add(
        pw.TableRow(
          children: days.map((day) {
            if (day.isEmpty) return pw.Container();
            final list = groupedSchedules[day] ?? [];
            final name = i < list.length ? '${i + 1}. ${list[i]}' : '';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              child: pw.Text(
                name,
                style: const pw.TextStyle(fontSize: 8),
              ),
            );
          }).toList(),
        )
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        for (int i = 0; i < days.length; i++) i: const pw.FlexColumnWidth(),
      },
      children: tableRows,
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (pw.Context context) {
        return [
          pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        subtitle,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'JADWAL JAGA',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Tanggal: ${now.day}/${now.month}/${now.year}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: pw.Text(
                'Daftar pembagian jadwal jaga warga secara resmi.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            buildDaysTable(['Senin', 'Selasa', 'Rabu', 'Kamis']),
            pw.SizedBox(height: 8),
            buildDaysTable(['Jumat', 'Sabtu', 'Minggu', '']),
        ];
      },
      footer: (pw.Context context) {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'Dokumen ini dibuat otomatis dari aplikasi Jimpitan.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    ),
  );
  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

Future<void> sharePaymentDetailPdf({
  required String residentName,
  required String kkNumber,
  required String tariffName,
  required String tariffType,
  required int amount,
  required int paidTotal,
  required int remainingTotal,
  required List<Map<String, dynamic>> payments,
  required String fileName,
}) async {
  final doc = pw.Document();

  String formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  final now = DateTime.now();
  final tableRows = <List<String>>[];
  for (var i = 0; i < payments.length; i++) {
    final payment = payments[i];
    tableRows.add([
      '${i + 1}',
      payment['label']?.toString() ?? '-',
      payment['dateText']?.toString() ?? '-',
      formatCurrency((payment['amount'] as num?)?.toInt() ?? 0),
    ]);
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        final headerColor = PdfColor.fromInt(0xFF2563EB);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DETAIL PEMBAYARAN',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$residentName • $kkNumber',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        '$tariffName • $tariffType',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Tanggal: ${now.day}/${now.month}/${now.year}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Nominal',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(amount),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: headerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Terbayar',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(paidTotal),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Sisa',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(remainingTotal),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Riwayat Pembayaran',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Keterangan', 'Tanggal', 'Jumlah'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 24,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
              data: tableRows,
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'Dokumen ini dibuat otomatis dari aplikasi Jimpitan.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}

Future<void> shareBillDetailPdf({
  required String residentName,
  required String fileName,
  required List<Map<String, dynamic>> tariffs,
  required int overallExpected,
  required int overallPaid,
  required int overallTotal,
}) async {
  final doc = pw.Document();

  String formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  final now = DateTime.now();
  final tableRows = <List<String>>[];
  for (var i = 0; i < tariffs.length; i++) {
    final tariff = tariffs[i];
    tableRows.add([
      '${i + 1}',
      tariff['name']?.toString() ?? '-',
      tariff['type']?.toString() ?? '-',
      formatCurrency((tariff['paid'] as num?)?.toInt() ?? 0),
      formatCurrency((tariff['arrears'] as num?)?.toInt() ?? 0),
    ]);
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        final headerColor = PdfColor.fromInt(0xFF2563EB);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DETAIL TAGIHAN',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        residentName,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'NOTA TAGIHAN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Tanggal: ${now.day}/${now.month}/${now.year}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Diwajibkan',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(overallExpected),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: headerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Terbayar',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(overallPaid),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(10),
                      ),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Sisa Tagihan',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(overallTotal),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Daftar Tarif',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Tarif', 'Jenis', 'Dibayar', 'Sisa'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 24,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              data: tableRows,
            ),
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Text(
                'Dokumen ini dibuat otomatis dari aplikasi Jimpitan.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
}
