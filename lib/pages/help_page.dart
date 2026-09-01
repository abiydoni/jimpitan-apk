import 'package:flutter/material.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:file_saver/file_saver.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/widgets/help_subscription_status_widget.dart';

class HelpPage extends StatelessWidget {
  final String? villageId;
  const HelpPage({super.key, this.villageId});

  void _downloadCsvTemplate(BuildContext context) async {
    try {
      final String csvHeader = "No KK,NIK,Nama Lengkap,Status Hubungan,Status Perkawinan,Jenis Kelamin,Tempat Lahir,Tanggal Lahir,Alamat,Agama,Pekerjaan,Status Hidup,Email,No HP,Jabatan\n";
      final String sampleData = "3270123456789012,3270000000000001,Budi Santoso,Kepala Keluarga,Kawin,Laki-Laki,Jakarta,01-01-1980,Jl. Merdeka No 1,Islam,Swasta,Hidup,budi@email.com,08123456789,WARGA\n"
          "3270123456789012,3270000000000002,Siti Aminah,Istri,Kawin,Perempuan,Bandung,02-02-1982,Jl. Merdeka No 1,Islam,Ibu Rumah Tangga,Hidup,siti@email.com,08129876543,WARGA\n";

      final String csvContent = csvHeader + sampleData;
      // Convert to Uint8List for file_saver
      final List<int> utf8Bytes = utf8.encode(csvContent);
      final Uint8List bytes = Uint8List.fromList(utf8Bytes);

      await FileSaver.instance.saveFile(
        name: 'template_import_warga',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (!context.mounted) return;
      CustomToast.show(context, 'Template CSV sedang diunduh/dibuka...');
    } catch (e) {
      if (!context.mounted) return;
      CustomToast.show(context, 'Gagal mengunduh template: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        children: [
          if (villageId != null)
            HelpSubscriptionStatusWidget(villageId: villageId!),
          _buildVillageInfoCard(),
          _buildHelpCard(
            title: 'Import Data Warga Massal (CSV)',
            icon: Icons.file_download,
            description:
                'Gunakan fitur ini untuk mengunduh format template CSV yang dibutuhkan saat Anda ingin menambahkan banyak warga sekaligus ke dalam sistem.',
            buttonText: 'Unduh Template CSV',
            onPressed: () => _downloadCsvTemplate(context),
          ),
          const SizedBox(height: 16),
          _buildHelpCard(
            title: 'Panduan Pengisian CSV',
            icon: Icons.info_outline,
            description:
                '1. Kolom "Kode Rumah" digunakan untuk mengelompokkan keluarga. Baris dengan Kode Rumah yang sama akan masuk ke dalam 1 Kartu Keluarga yang sama.\n'
                '2. Kolom "Tanggal Lahir" harus berformat YYYY-MM-DD (contoh: 1990-12-31).\n'
                '3. Kolom "Jabatan" dapat diisi lebih dari satu dengan dipisahkan koma (contoh: WARGA,PENGURUS_RT).',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard({
    required String title,
    required IconData icon,
    required String description,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.download),
                  label: Text(buttonText),
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
          ],
        ),
      ),
    );
  }

  Widget _buildVillageInfoCard() {
    if (villageId == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getVillage(villageId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final villageData = snapshot.data!;
        final String villageName = villageData['name'] ?? 'Desa';
        final String uniqueCode = villageData['uniqueCode'] ?? '-';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi & Bergabung',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            villageName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code Section (Ticket Style)
                    const Text(
                      'Kode Undangan Desa / RT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              uniqueCode,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Builder(
                            builder: (ctx) => ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: uniqueCode));
                                CustomToast.show(ctx, 'Kode berhasil disalin!');
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Salin', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 20),
                    
                    // Instructions Section
                    const Text(
                      'Bagaimana cara warga bergabung?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStepRow(
                      icon: Icons.download_rounded,
                      step: '1',
                      title: 'Unduh Aplikasi',
                      desc: 'Warga mengunduh aplikasi Jimpitan Warga dari Play Store atau App Store.',
                      extraAction: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.appsbeem.jimpitan');
                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                              // CustomToast.show is not available easily without context if we are in builder, wait we have context from builder!
                              debugPrint('Could not launch play store');
                            }
                          },
                          icon: const Icon(Icons.shop, size: 16),
                          label: const Text('Buka Play Store', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                    _buildStepRow(
                      icon: Icons.person_add_alt_1_rounded,
                      step: '2',
                      title: 'Buat Akun Baru',
                      desc: 'Warga mendaftar atau masuk dengan instan menggunakan akun Google.',
                    ),
                    _buildStepRow(
                      icon: Icons.login_rounded,
                      step: '3',
                      title: 'Masukkan Kode',
                      desc: 'Warga memilih menu "Bergabung dengan Desa" dan memasukkan kode di atas.',
                    ),
                    _buildStepRow(
                      icon: Icons.verified_user_rounded,
                      step: '4',
                      title: 'Tunggu Persetujuan',
                      desc: 'Admin (Anda) menyetujui permintaan warga yang masuk melalui aplikasi.',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String step,
    required String title,
    required String desc,
    bool isLast = false,
    Widget? extraAction,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Langkah $step: $title',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                ?extraAction,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
