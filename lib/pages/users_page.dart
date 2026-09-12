import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/widgets/user_avatar.dart';

import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart' as bcw;
import 'package:jimpitan/pages/user_form_page.dart';
import 'package:jimpitan/utils/resident_pdf_export.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class UsersPage extends StatefulWidget {
  final Map<String, bool> permissions;
  final String villageId;
  final List<String>? currentUserRoles;

  const UsersPage({
    super.key,
    required this.permissions,
    required this.villageId,
    this.currentUserRoles,
  });

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String get _currentVillageId => widget.villageId;
  final Map<String, dynamic> _selectedUsersForQR = {};
  String? _expandedDocId;
  String _searchQuery = '';

  Future<List<dynamic>>? _activeUsersFuture;
  Future<List<dynamic>>? _pendingUsersFuture;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupFCM();
  }

  bool get _canSeePrivateData {
    final permissions = widget.permissions;
    final roles = (widget.currentUserRoles ?? []).map((r) => r.toString()).toList();
    return permissions['edit'] == true ||
        permissions['add'] == true ||
        roles.contains('SUPER_ADMIN') ||
        roles.contains('ADMIN_DESA');
  }

  String _formatSensitiveData(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    if (_canSeePrivateData) return raw.trim();
    return '****************';
  }

  void _loadData() {
    ApiService.clearUsersCache();
    setState(() {
      _activeUsersFuture = ApiService.getUsers(_currentVillageId, 'ACTIVE');
      _pendingUsersFuture = ApiService.getUsers(_currentVillageId, 'PENDING');
    });
  }

  void _setupFCM() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (message.data['action'] == 'REFRESH_USERS') {
        _loadData();
      }
    });
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  void _showBatchPrintDialog() {
    if (_selectedUsersForQR.isEmpty) return;
    // Langsung eksekusi cetak QR Code tanpa menanyakan format lagi
    _executeBatchPrint();
  }

  Future<void> _executeBatchPrint() async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Wrap(
                spacing: 10,
                runSpacing: 16,
                alignment: pw.WrapAlignment.start,
                children: _selectedUsersForQR.entries.map((entry) {
                  final name = entry.value['name'];
                  final shortCode = entry.value['code'];

                  return pw.Container(
                    width: 95, // QR 5/baris
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: const PdfColor(0.8, 0.8, 0.8),
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          name,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          shortCode,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor(0.2, 0.2, 0.2),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 6),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: shortCode,
                          width: 75,
                          height: 75,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Batch_Kode_Warga.pdf',
      );

      setState(() {
        _selectedUsersForQR.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      EasyLoading.show(status: 'Mempersiapkan...');
      final village = await ApiService.getVillage(_currentVillageId);
      EasyLoading.dismiss();
      final String villageCode = village != null && village['uniqueCode'] != null
          ? village['uniqueCode'].toString()
          : '';

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes == null) {
          throw Exception("Gagal membaca file");
        }

        final csvString = utf8.decode(bytes);
        List<List<dynamic>> rowsAsListOfValues = Csv().decode(csvString);

        if (rowsAsListOfValues.isNotEmpty && rowsAsListOfValues[0].length == 1) {
          rowsAsListOfValues = Csv(fieldDelimiter: ';').decode(csvString);
        }

        if (rowsAsListOfValues.length <= 1) {
          throw Exception("File CSV kosong atau hanya berisi header");
        }

        List<dynamic> headerRow = rowsAsListOfValues[0];
        Map<String, int> headerMap = {};
        for (int i = 0; i < headerRow.length; i++) {
          headerMap[headerRow[i].toString().trim().toLowerCase()] = i;
        }

        String getCol(List<dynamic> row, String colName, int fallbackIndex, String defVal) {
          int? idx;
          String target = colName.replaceAll(' ', '').replaceAll('_', '').toLowerCase();
          for (var entry in headerMap.entries) {
            String key = entry.key.replaceAll(' ', '').replaceAll('_', '').toLowerCase();
            if (key == target ||
                (target == 'koderumah' && (key == 'uniquecode' || key == 'kode')) ||
                (target == 'namalengkap' && (key == 'nama' || key == 'name' || key == 'namawarga' || key == 'namalengkap')) ||
                (target == 'nokk' && (key == 'kk' || key == 'nomorkk' || key == 'nokk')) ||
                (target == 'statusperkawinan' && (key == 'statuskawin' || key == 'perkawinan' || key == 'pernikahan' || key == 'statusperkawinan')) ||
                (target == 'statushubungan' && (key == 'hubungan' || key == 'statushubungan' || key == 'hubkeluarga')) ||
                (target == 'jeniskelamin' && (key == 'jk' || key == 'kelamin' || key == 'gender' || key == 'jeniskelamin')) ||
                (target == 'statushidup' && (key == 'status' || key == 'hidup' || key == 'statushidup')) ||
                (target == 'nohp' && (key == 'phone' || key == 'phonenumber' || key == 'telepon' || key == 'hp' || key == 'nohp'))) {
              idx = entry.value;
              break;
            }
          }
          idx ??= fallbackIndex;
          if (idx < row.length) {
            String val = row[idx].toString().trim();
            return val.isNotEmpty ? val : defVal;
          }
          return defVal;
        }

        List<Map<String, dynamic>> parsedUsers = [];
        Map<String, String> kkToUniqueCode = {};

        for (int i = 1; i < rowsAsListOfValues.length; i++) {
          final row = rowsAsListOfValues[i];
          if (row.isEmpty) continue;

          String noKK = getCol(row, 'no kk', 0, '');
          String nik = getCol(row, 'nik', 1, '');
          String namaLengkap = getCol(row, 'nama lengkap', 2, '');

          if (namaLengkap.isEmpty || nik.isEmpty) continue; // Skip invalid row

          String statusHub = getCol(row, 'status hubungan', 3, 'Warga');
          String statusKawin = getCol(row, 'status perkawinan', 4, 'Belum Kawin');
          String jk = getCol(row, 'jenis kelamin', 5, 'Laki-Laki');
          String tmptLahir = getCol(row, 'tempat lahir', 6, '');
          String tglLahir = getCol(row, 'tanggal lahir', 7, '');
          String alamat = getCol(row, 'alamat', 8, '');
          String agama = getCol(row, 'agama', 9, 'Islam');
          String pekerjaan = getCol(row, 'pekerjaan', 10, 'Lainnya');
          String statusHidup = getCol(row, 'status hidup', 11, 'Hidup');
          String email = getCol(row, 'email', 12, '');
          if (email.isNotEmpty && !email.contains('@')) email = ''; // Sanitasi email
          String noHp = getCol(row, 'no hp', 13, '');
          String rolesStr = getCol(row, 'jabatan', 14, 'WARGA');
          String kodeRumahCsv = getCol(row, 'kode rumah', 15, '');

          List<String> roles = rolesStr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (roles.isEmpty) roles = ['WARGA'];

          if (kodeRumahCsv.isNotEmpty) {
            if (noKK.isNotEmpty && !kkToUniqueCode.containsKey(noKK)) {
              kkToUniqueCode[noKK] = kodeRumahCsv;
            }
          } else if (noKK.isNotEmpty && !kkToUniqueCode.containsKey(noKK)) {
            String randCode = (Random().nextInt(90000000) + 10000000).toString();
            kkToUniqueCode[noKK] = villageCode.isNotEmpty ? "$villageCode${(Random().nextInt(900) + 100)}" : randCode;
          }

          String kodeRumah = kodeRumahCsv.isNotEmpty 
              ? kodeRumahCsv 
              : (noKK.isNotEmpty ? kkToUniqueCode[noKK]! : (villageCode.isNotEmpty ? "$villageCode${(Random().nextInt(900) + 100)}" : (Random().nextInt(90000000) + 10000000).toString()));

          parsedUsers.add({
            'uniqueCode': kodeRumah,
            'noKK': noKK,
            'nik': nik,
            'name': namaLengkap,
            'namaLengkap': namaLengkap,
            'statusHubungan': statusHub,
            'statusPerkawinan': statusKawin,
            'jenisKelamin': jk,
            'tempatLahir': tmptLahir,
            'tanggalLahir': tglLahir,
            'alamat': alamat,
            'agama': agama,
            'pekerjaan': pekerjaan,
            'statusHidup': statusHidup,
            'email': email,
            'phoneNumber': noHp,
            'roles': roles,
            'villageId': _currentVillageId,
          });
        }

        if (parsedUsers.isEmpty) {
          throw Exception(
            "Tidak ada data warga valid yang ditemukan dalam file CSV",
          );
        }

        int totalUsersCount = parsedUsers.length;
        Set<String> uniqueKKs = parsedUsers
            .map((u) => u['noKK']?.toString() ?? '')
            .where((kk) => kk.isNotEmpty)
            .toSet();
        int totalKKCount = uniqueKKs.length;

        // Progress Notifiers
        final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
        final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
          'Mengimpor 0 dari $totalUsersCount data warga...',
        );

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) {
              return PopScope(
                canPop: false,
                child: Dialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_rounded,
                            color: AppTheme.primaryColor,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Mengimpor Data CSV',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<String>(
                          valueListenable: statusNotifier,
                          builder: (context, statusText, _) {
                            return Text(
                              statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (context, progressVal, _) {
                            return Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: progressVal,
                                    minHeight: 10,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(progressVal * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Send in batch chunks of 50
        const int chunkSize = 50;
        String? errorMsg;
        int importedCount = 0;

        for (int i = 0; i < parsedUsers.length; i += chunkSize) {
          int end = (i + chunkSize < parsedUsers.length)
              ? i + chunkSize
              : parsedUsers.length;
          List<Map<String, dynamic>> chunk = parsedUsers.sublist(i, end);

          try {
            errorMsg = await ApiService.bulkImportUsers(
              _currentVillageId,
              chunk,
            );
            if (errorMsg != null) break;
          } catch (e) {
            errorMsg = e.toString();
            break;
          }

          importedCount = end;
          progressNotifier.value = importedCount / totalUsersCount;
          statusNotifier.value =
              'Mengimpor $importedCount dari $totalUsersCount data warga...';
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Close progress dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (mounted) {
          if (errorMsg == null) {
            _loadData();
            // Show Success Notification Dialog
            showDialog(
              context: context,
              builder: (successCtx) => AppModalDialog(
                title: 'Impor Data Berhasil!',
                headerIcon: Icons.check_circle_outline,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Data Warga Berhasil Diimpor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seluruh data warga dari file CSV berhasil disinkronkan ke dalam sistem desa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$totalUsersCount',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Total Warga',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 36,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          Column(
                            children: [
                              Text(
                                '$totalKKCount',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const Text(
                                'Kepala Keluarga',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(successCtx),
                        child: const Text(
                          'Selesai',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            CustomToast.show(
              context,
              'Berhasil mengimpor $totalUsersCount data warga',
            );
          } else {
            CustomToast.show(context, 'Gagal: $errorMsg', isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // If loading dialog is open, close it
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengimpor CSV: $e')));
      }
    }
  }

  Future<void> _showUserFormDialog([String? docId, Map<String, dynamic>? user]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormPage(
          userId: docId,
          initialData: user,
          villageId: _currentVillageId,
          currentUserRoles: widget.currentUserRoles,
        ),
      ),
    );
    _loadData();
  }

  void _showDetailDialog(Map<String, dynamic> user) {
    final List<dynamic> family = user['familyMembers'] ?? [];
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.family_restroom,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Detail Kartu Keluarga',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => shareResidentPdfWrapper(user),
                            icon: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Share PDF',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailRow(
                                      Icons.credit_card,
                                      'Nomor KK',
                                      _formatSensitiveData(user['noKK']?.toString()),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDetailRow(
                                      Icons.phone,
                                      'No HP / WA',
                                      user['phone'] ?? '-',
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailRow(
                                      Icons.home,
                                      'Alamat',
                                      user['alamat'] ?? '-',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Anggota Keluarga',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (family.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Belum ada data keluarga',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        else
                          ...family.map(
                            (member) => _buildFamilyMemberCard(member, user),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.toString().isEmpty ? '-' : value.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMemberCard(Map<String, dynamic> member, Map<String, dynamic> parentUser) {
    final bool isDead = member['statusHidup'] == 'Meninggal';
    final bool isHead = member['statusHubungan'] == 'Kepala Keluarga';
    final List<String> roles = (member['roles'] is List)
        ? (member['roles'] as List)
              .where((r) => r != null)
              .map((r) => r.toString())
              .toList()
        : [];
    final String email = member['email']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDead ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDead ? Colors.red.shade100 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris atas: foto + nama + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userData: {
                  if (parentUser['email'] != null &&
                      parentUser['email'].toString().isNotEmpty &&
                      parentUser['email'] == member['email'])
                    ...parentUser,
                  ...member,
                },
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member['namaLengkap'] ?? '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDead
                                  ? Colors.red.shade700
                                  : const Color(0xFF1E293B),
                              decoration: isDead
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isHead)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Text(
                              'KK',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      member['statusHubungan'] ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // Grid detail informasi
          _buildInfoGrid([
            ['NIK', _formatSensitiveData(member['nik']?.toString()), Icons.badge],
            ['Jenis Kelamin', member['jenisKelamin'] ?? '-', Icons.wc],
            ['Tempat Lahir', member['tempatLahir'] ?? '-', Icons.location_city],
            ['Tanggal Lahir', member['tanggalLahir'] ?? '-', Icons.cake],
            ['Agama', member['agama'] ?? '-', Icons.star_outline],
            ['Pekerjaan', member['pekerjaan'] ?? '-', Icons.work_outline],
            [
              'Status Hidup',
              member['statusHidup'] ?? '-',
              Icons.favorite_border,
            ],
            ['Email Akun', email.isEmpty ? '-' : email, Icons.email_outlined],
          ]),
          if (roles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: roles
                  .map(
                    (r) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<List<dynamic>> items) {
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoCell(
                  items[i][2] as IconData,
                  items[i][0] as String,
                  items[i][1] as String,
                ),
              ),
              const SizedBox(width: 12),
              if (i + 1 < items.length)
                Expanded(
                  child: _buildInfoCell(
                    items[i + 1][2] as IconData,
                    items[i + 1][0] as String,
                    items[i + 1][1] as String,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildInfoCell(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Future<void> _exportAllResidentsPdf() async {
    try {
      final residents = (await ApiService.getUsers(
        _currentVillageId,
        'ACTIVE',
      )).cast<Map<String, dynamic>>();

      if (residents.isEmpty) {
        if (mounted) {
          CustomToast.show(context, 'Tidak ada data warga aktif untuk diekspor.');
        }
        return;
      }

      await shareAllResidentsPdf(
        residents: residents,
        fileName:
            'Daftar_Semua_Warga_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      if (mounted) {
        CustomToast.show(context, 'PDF daftar semua warga berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membuat PDF daftar warga: $e', isError: true);
      }
    }
  }

  Future<void> shareResidentPdfWrapper(Map<String, dynamic> user) async {
    try {
      final cleanName = (user['name'] ?? 'keluarga').toString().replaceAll(
        RegExp(r'[^a-zA-Z0-9]+'),
        '_',
      );
      await shareResidentPdf(
        userData: user,
        fileName: 'Data_Warga_$cleanName.pdf',
      );
      if (mounted) {
        CustomToast.show(context, 'PDF data warga berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
      }
    }
  }

  void _showCodeDialog(String docId, String name, String shortCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Kartu QR Warga',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            shortCode,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          bcw.BarcodeWidget(
                            barcode: bcw.Barcode.qrCode(),
                            data: shortCode,
                            width: 250,
                            height: 250,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final doc = pw.Document();
                            doc.addPage(
                              pw.Page(
                                pageFormat: PdfPageFormat.a4,
                                build: (pw.Context context) {
                                  return pw.Center(
                                    child: pw.Container(
                                      width: 95,
                                      padding: const pw.EdgeInsets.all(6),
                                      decoration: pw.BoxDecoration(
                                        border: pw.Border.all(
                                          color: const PdfColor(0.8, 0.8, 0.8),
                                        ),
                                        borderRadius: const pw.BorderRadius.all(
                                          pw.Radius.circular(8),
                                        ),
                                      ),
                                      child: pw.Column(
                                        mainAxisSize: pw.MainAxisSize.min,
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.center,
                                        children: [
                                          pw.Text(
                                            name,
                                            style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                            textAlign: pw.TextAlign.center,
                                            maxLines: 2,
                                          ),
                                          pw.SizedBox(height: 2),
                                          pw.Text(
                                            shortCode,
                                            style: pw.TextStyle(
                                              fontSize: 7,
                                              fontWeight: pw.FontWeight.bold,
                                              color: const PdfColor(
                                                0.2,
                                                0.2,
                                                0.2,
                                              ),
                                            ),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                          pw.SizedBox(height: 6),
                                          pw.BarcodeWidget(
                                            barcode: pw.Barcode.qrCode(),
                                            data: shortCode,
                                            width: 75,
                                            height: 75,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );

                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async =>
                                  doc.save(),
                              name: 'Kode_$name.pdf',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              CustomToast.show(context, 'Gagal membuat PDF: $e', isError: true);
                            }
                          }
                        },
                        icon: Icon(Icons.print),
                        label: Text(
                          'Download / Cetak PDF',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteUser(String docId, {bool isPending = false, String? noKK}) async {
    showDialog(
      context: context,
      builder: (context) => AppModalDialog(
        title: isPending ? 'Hapus Pendaftar' : 'Hapus Warga',
        headerIcon: Icons.delete,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPending ? 'Yakin ingin menghapus pendaftar ini?' : 'Yakin ingin menghapus seluruh data keluarga ini?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      EasyLoading.show(status: 'Menghapus...');
                      try {
                        if (isPending) {
                          await ApiService.saveUserFamily({
                            'familyId': '',
                            'uniqueCode': '',
                            'villageId': _currentVillageId,
                            'familyMembers': [],
                            'deletedDocIds': [docId],
                          });
                        } else {
                          await ApiService.deleteUser(
                            docId,
                            noKK: noKK,
                            villageId: _currentVillageId,
                          );
                        }
                        _loadData();
                      } catch (e) {
                        EasyLoading.showError('Gagal menghapus');
                      } finally {
                        EasyLoading.dismiss();
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Hapus',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkUserDialog(Map<String, dynamic> pendingUser) async {
    final activeDocs = await _activeUsersFuture;
    if (activeDocs == null || activeDocs.isEmpty) {
      if (mounted) {
        CustomToast.show(context, 'Belum ada data warga aktif.');
      }
      return;
    }

    // Flatten to a list of individual members for searching
    List<Map<String, dynamic>> allActiveMembers = [];
    for (var doc in activeDocs) {
      final data = doc as Map<String, dynamic>;
      if (data.containsKey('familyMembers') && data['familyMembers'] is List) {
        for (var member in data['familyMembers']) {
          final m = Map<String, dynamic>.from(member);
          m['docId'] = m['_docId'] ?? m['docId'] ?? m['uid'] ?? m['id'];
          m['name'] = m['name'] ?? m['namaLengkap'];
          m['familyId'] = data['uid'] ?? data['id'];
          m['uniqueCode'] = data['uniqueCode'];
          m['villageId'] = data['villageId'];
          allActiveMembers.add(m);
        }
      } else {
        final m = Map<String, dynamic>.from(data);
        m['docId'] = m['docId'] ?? m['uid'] ?? m['id'] ?? m['_docId'];
        m['familyId'] = data['familyId'] ?? data['uid'] ?? data['id'];
        allActiveMembers.add(m);
      }
    }

    if (!mounted) return;

    final TextEditingController searchCtrl = TextEditingController(
      text: pendingUser['name']?.toString() ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            String searchQuery = searchCtrl.text.toLowerCase();
            final filtered =
                allActiveMembers.where((m) {
                  return (m['name']?.toString().toLowerCase() ?? '').contains(
                    searchQuery,
                  );
                }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Kaitkan Data Pendaftar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari nama warga lama...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      onChanged: (val) {
                        setStateModal(() {}); // Just rebuild, value is from controller
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const Center(
                              child: Text('Tidak ada warga yang cocok.'),
                            )
                            : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final m = filtered[index];
                                return ListTile(
                                  leading: UserAvatar(userData: m),
                                  title: Text(
                                    m['name'] ?? 'Tanpa Nama',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('KK: ${m['noKK'] ?? '-'}'),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text('Kaitkan Data?'),
                                              content: Text(
                                                'Apakah Anda yakin ingin mengaitkan email pendaftar ke ${m['name']}?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Batal'),
                                                ),
                                                ElevatedButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Ya, Kaitkan',
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (confirm == true) {
                                        if (!context.mounted) return;
                                        Navigator.pop(context); // Close bottom sheet
                                        EasyLoading.show(
                                          status: 'Mengaitkan data...',
                                        );
                                        try {
                                           dynamic pendingUid;
                                           if (pendingUser['familyMembers'] != null && (pendingUser['familyMembers'] as List).isNotEmpty) {
                                             final firstM = pendingUser['familyMembers'][0];
                                             pendingUid = firstM['_docId'] ?? firstM['docId'] ?? firstM['uid'] ?? firstM['id'];
                                           }
                                           pendingUid ??= pendingUser['docId'] ?? pendingUser['uid'] ?? pendingUser['id'] ?? pendingUser['_docId'];
                                           final targetUid = m['docId'] ?? m['_docId'] ?? m['uid'] ?? m['id'];
                                           final villageId = m['villageId'] ?? pendingUser['villageId'];

                                          final success =
                                              await ApiService.linkUserAccount({
                                            'pendingUid': pendingUid,
                                            'targetUid': targetUid,
                                            'villageId': villageId,
                                          });
                                          if (success) {
                                            _loadData();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Data berhasil dikaitkan!',
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Gagal mengaitkan data',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Error'),
                                                content: SingleChildScrollView(
                                                  child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Tutup'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        } finally {
                                          EasyLoading.dismiss();
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Pilih'),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _approveUser(String uid) async {
    EasyLoading.show(status: 'Menyetujui...');
    try {
      await ApiService.updateUserStatus(uid, {'status': 'ACTIVE'});
      _loadData();
      if (mounted) {
        CustomToast.show(context, 'Warga berhasil disetujui!');
      }
    } catch (e) {
      EasyLoading.showError('Gagal menyetujui: ${e.toString()}');
    } finally {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomGradientAppBar(
          titleText: 'Manajemen Warga',
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Warga Aktif'),
              Tab(text: 'Pendaftar Baru'),
            ],
          ),
          actions: [
            if (_selectedUsersForQR.isNotEmpty &&
                (widget.currentUserRoles?.contains('SUPER_ADMIN') == true ||
                    widget.currentUserRoles?.contains('ADMIN_DESA') == true))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _showBatchPrintDialog,
                  icon: const Icon(Icons.print, size: 18),
                  label: Text('Cetak (${_selectedUsersForQR.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Muat Ulang Data',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportAllResidentsPdf,
              tooltip: 'Export Semua Warga PDF',
            ),
            if (widget.permissions['create'] == true || widget.currentUserRoles?.contains('SUPER_ADMIN') == true)
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: _importCsv,
                tooltip: 'Import Data Warga (CSV)',
              ),
            if (widget.permissions['create'] == true || widget.currentUserRoles?.contains('SUPER_ADMIN') == true)
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => _showUserFormDialog(),
                tooltip: 'Tambah Data Warga',
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari KK, NIK, atau Nama Anggota...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserList(_activeUsersFuture, true),
                  _buildUserList(_pendingUsersFuture, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(Future<List<dynamic>>? future, bool isActiveTab) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              _loadData();
              await _activeUsersFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 100),
                Center(child: Text("Belum ada data warga di desa ini.")),
              ],
            ),
          );
        }

        var allDocs = snapshot.data!;

        // Group by familyId
        Map<String, Map<String, dynamic>> groupedFamilies = {};

        for (var doc in allDocs) {
          final data = doc as Map<String, dynamic>;
          final docId = data['uid'] ?? data['id'] ?? '';

          // Jika dokumen ini menggunakan format LAMA (punya array familyMembers)
          if (data.containsKey('familyMembers') &&
              data['familyMembers'] is List) {
            groupedFamilies[docId] = {
              'docId': docId,
              'noKK': data['noKK'],
              'name': data['name'] ?? '',
              'phone': data['phone'] ?? data['phoneNumber'],
              'email': data['email'],
              'alamat': data['alamat'] ?? data['address'],
              'villageId': data['villageId'],
              'uniqueCode': data['uniqueCode'],
              'roles': data['roles'] ?? [],
              'foto': data['foto'],
              'photoUrl': data['photoUrl'],
              'createdAt': data['createdAt'],
              'familyMembers': List<Map<String, dynamic>>.from(
                data['familyMembers'],
              ),
            };
          } else {
            // Dokumen dengan format BARU (terpisah per individu)
            final rawNoKK = data['noKK']?.toString().trim();
            final rawFamId = data['familyId']?.toString().trim();
            final bool hasValidKK = rawNoKK != null &&
                rawNoKK.isNotEmpty &&
                rawNoKK != '-' &&
                rawNoKK != '0' &&
                rawNoKK.toLowerCase() != 'null' &&
                rawNoKK.length >= 4;

            final String familyId = hasValidKK
                ? 'KK_$rawNoKK'
                : ((rawFamId != null && rawFamId.isNotEmpty)
                    ? rawFamId
                    : docId);

            if (!groupedFamilies.containsKey(familyId)) {
              groupedFamilies[familyId] = {
                'docId': (rawFamId != null && rawFamId.isNotEmpty) ? rawFamId : docId,
                'familyId': (rawFamId != null && rawFamId.isNotEmpty) ? rawFamId : docId,
                'noKK': data['noKK'],
                'name': '',
                'phone': data['phone'] ?? data['phoneNumber'],
                'email': data['email'],
                'alamat': data['alamat'] ?? data['address'],
                'villageId': data['villageId'],
                'uniqueCode': data['uniqueCode'],
                'createdAt': data['createdAt'],
                'foto': data['foto'],
                'photoUrl': data['photoUrl'],
                'roles': [],
                'familyMembers': <Map<String, dynamic>>[],
              };
            }

            // Tambahkan individu ke familyMembers
            Map<String, dynamic> memberData = {
              '_docId': docId,
              'docId': docId,
              'uid': docId,
              'nik': data['nik'],
              'namaLengkap': data['name'],
              'name': data['name'],
              'statusHubungan': data['statusHubungan'],
              'statusPerkawinan': data['statusPerkawinan'] ?? 'Belum Kawin',
              'jenisKelamin': data['jenisKelamin'],
              'tempatLahir': data['tempatLahir'],
              'tanggalLahir': data['tanggalLahir'],
              'agama': data['agama'],
              'pekerjaan': data['pekerjaan'],
              'statusHidup': data['statusHidup'],
              'foto': data['foto'] ?? data['photoUrl'],
              'photoUrl': data['photoUrl'] ?? data['foto'],
              'email': data['email'],
              'noKK': data['noKK'],
              'alamat': data['alamat'] ?? data['address'],
              'phone': data['phone'] ?? data['phoneNumber'],
              'createdAt': data['createdAt'],
              'roles': data['roles'] ?? ['WARGA'],
            };

            groupedFamilies[familyId]!['familyMembers'].add(memberData);

            if (data['statusHubungan'] == 'Kepala Keluarga' ||
                groupedFamilies[familyId]!['name'] == '') {
              groupedFamilies[familyId]!['name'] = data['name'];
              groupedFamilies[familyId]!['roles'] = data['roles'];
              if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
                groupedFamilies[familyId]!['phone'] = data['phone'];
              }
              if (data['alamat'] != null && data['alamat'].toString().isNotEmpty) {
                groupedFamilies[familyId]!['alamat'] = data['alamat'];
              }
              if (rawFamId != null && rawFamId.isNotEmpty) {
                groupedFamilies[familyId]!['docId'] = rawFamId;
                groupedFamilies[familyId]!['familyId'] = rawFamId;
              }
            }
          }
        }

        var users = groupedFamilies.values.toList();

        // Sembunyikan SUPER_ADMIN dari daftar warga
        users = users.where((data) {
          final roles = data['roles'];
          if (roles is List) return !roles.contains('SUPER_ADMIN');
          if (roles is String) return !roles.contains('SUPER_ADMIN');
          return true;
        }).toList();

        // Kalkulasi Statistik
        int totalWarga = 0;
        int totalLakiLaki = 0;
        int totalPerempuan = 0;
        for (var data in users) {
          final family = data['familyMembers'] as List<dynamic>? ?? [];
          totalWarga += family.length;
          for (var member in family) {
             final gender = (member['jenisKelamin'] ?? '').toString().toLowerCase();
             if (gender == 'laki-laki' || gender == 'l' || gender == 'pria' || gender == 'laki - laki') {
                totalLakiLaki++;
             } else if (gender == 'perempuan' || gender == 'p' || gender == 'wanita') {
                totalPerempuan++;
             }
          }
        }
        int totalKK = users.length;

        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          users = users.where((data) {
            final headName = (data['name'] ?? '').toString().toLowerCase();
            final noKK = (data['noKK'] ?? '').toString().toLowerCase();

            if (headName.contains(query)) return true;
            if (_canSeePrivateData && noKK.contains(query)) return true;

            final family = data['familyMembers'] as List<dynamic>? ?? [];
            for (var member in family) {
              final mName = (member['namaLengkap'] ?? '')
                  .toString()
                  .toLowerCase();
              final mNik = (member['nik'] ?? '').toString().toLowerCase();
              if (mName.contains(query)) return true;
              if (_canSeePrivateData && mNik.contains(query)) return true;
            }
            return false;
          }).toList();
        }

        final canPrintQR =
            widget.currentUserRoles?.contains('SUPER_ADMIN') == true ||
            widget.currentUserRoles?.contains('ADMIN_DESA') == true;

        return RefreshIndicator(
          onRefresh: () async {
            _loadData();
            await _activeUsersFuture;
          },
          child: Column(
            children: [
              if (isActiveTab && _searchQuery.isEmpty)
                _buildStatisticsCard(totalWarga, totalKK, totalLakiLaki, totalPerempuan),
              if (canPrintQR)
                CheckboxListTile(
                  title: const Text(
                    'Pilih Semua Warga',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value:
                      _selectedUsersForQR.length == users.length &&
                      users.isNotEmpty,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        for (var data in users) {
                          _selectedUsersForQR[data['docId']] = {
                            'name': data['name'] ?? 'Tanpa Nama',
                            'code': data['uniqueCode'] ?? 'Loading...',
                          };
                        }
                      } else {
                        _selectedUsersForQR.clear();
                      }
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              Expanded(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final docId = user['docId'];
                    final List<Map<String, dynamic>> family =
                        List<Map<String, dynamic>>.from(
                          user['familyMembers'] ?? [],
                        );
                    Map<String, dynamic>? head;
                    if (family.isNotEmpty) {
                      head = family.firstWhere(
                        (m) =>
                            m['statusHubungan'] == 'Kepala Keluarga' &&
                            (m['statusHidup'] == 'Hidup' ||
                                m['statusHidup'] == 'Aktif' ||
                                m['statusHidup'] == null),
                        orElse: () => family.first,
                      );
                    }

                    final List<String> userRoles = (user['roles'] is List)
                        ? (user['roles'] as List)
                              .where((r) => r != null)
                              .map((r) => r.toString())
                              .toList()
                        : [];

                    final String name = user['name'] ?? 'Tanpa Nama';
                    final String phone =
                        (user['phone'] ?? user['phoneNumber'] ?? '').toString();

                    Widget roleBadges = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: userRoles
                          .where((r) => r.isNotEmpty)
                          .map(
                            (r) => Container(
                              margin: const EdgeInsets.only(bottom: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: r == 'SUPER_ADMIN'
                                    ? Colors.purple.shade50
                                    : r == 'ADMIN_DESA'
                                    ? Colors.orange.shade50
                                    : AppTheme.primaryColor.withValues(
                                        alpha: 0.07,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: r == 'SUPER_ADMIN'
                                      ? Colors.purple.shade200
                                      : r == 'ADMIN_DESA'
                                      ? Colors.orange.shade200
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                ),
                              ),
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: r == 'SUPER_ADMIN'
                                      ? Colors.purple.shade700
                                      : r == 'ADMIN_DESA'
                                      ? Colors.orange.shade700
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );

                    return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        children: [
                          ListTile(
                            onTap: () {
                              setState(() {
                                if (_expandedDocId == docId) {
                                  _expandedDocId = null;
                                } else {
                                  _expandedDocId = docId;
                                }
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canPrintQR)
                                  Checkbox(
                                    value: _selectedUsersForQR.containsKey(
                                      docId,
                                    ),
                                    activeColor: AppTheme.primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedUsersForQR[docId] = {
                                            'name': name,
                                            'code':
                                                user['uniqueCode'] ??
                                                'Loading...',
                                          };
                                        } else {
                                          _selectedUsersForQR.remove(docId);
                                        }
                                      });
                                    },
                                  ),
                                UserAvatar(
                                  userData: head != null
                                      ? {
                                          if (user['email'] != null &&
                                              user['email'].toString().isNotEmpty &&
                                              user['email'] == head['email'])
                                            ...user,
                                          ...head,
                                        }
                                      : user,
                                  radius: 24,
                                ),
                              ],
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                if ((user['noKK'] ?? '').toString().isNotEmpty && _canSeePrivateData)
                                  Text(
                                    'KK: ${user['noKK']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                Text(
                                  '${family.length} Anggota  •  ${phone.isNotEmpty ? phone : 'Tanpa No. HP'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [roleBadges],
                            ),
                            isThreeLine: true,
                          ),
                          if (_expandedDocId == docId)
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (isActiveTab)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.contact_page,
                                          color: Colors.purple,
                                        ),
                                        onPressed: () =>
                                            _showDetailDialog(user),
                                      ),
                                      const Text(
                                        'Detail',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isActiveTab)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.share_rounded),
                                        onPressed: () =>
                                            shareResidentPdfWrapper(user),
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              Colors.indigo.shade50,
                                          foregroundColor:
                                              Colors.indigo.shade700,
                                          padding: const EdgeInsets.all(12),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Share PDF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (widget.permissions['edit'] == true)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.qr_code_2,
                                            color: Colors.green,
                                          ),
                                          onPressed: () => _showCodeDialog(
                                            docId,
                                            name,
                                            user['uniqueCode'] ?? 'Loading...',
                                          ),
                                        ),
                                        const Text(
                                          'Kode',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),

                                  if (widget.permissions['edit'] == true)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            color: AppTheme.primaryColor,
                                          ),
                                          onPressed: () =>
                                              _showUserFormDialog(docId, user),
                                        ),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (widget.permissions['delete'] == true)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteUser(
                                            docId,
                                            isPending: !isActiveTab,
                                            noKK: user['noKK']?.toString(),
                                          ),
                                        ),
                                        const Text(
                                          'Hapus',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!isActiveTab &&
                                      widget.permissions['edit'] == true)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.link,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () => _showLinkUserDialog(user),
                                        ),
                                        const Text(
                                          'Kaitkan',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (!isActiveTab &&
                                      widget.permissions['edit'] == true)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check_circle,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _approveUser(docId),
                                        ),
                                        const Text(
                                          'Setujui',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildStatisticsCard(int warga, int kk, int laki, int perempuan) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statistik Warga Aktif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.groups, 'Warga', warga.toString(), Colors.blue),
              _buildStatItem(Icons.maps_home_work, 'KK', kk.toString(), Colors.green),
              _buildStatItem(Icons.male, 'Laki-laki', laki.toString(), Colors.orange),
              _buildStatItem(Icons.female, 'Perempuan', perempuan.toString(), Colors.pink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

