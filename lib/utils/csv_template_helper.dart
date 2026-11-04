import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class CsvTemplateHelper {
  static const String csvHeader =
      "No KK,NIK,Nama Lengkap,Status Hubungan,Status Perkawinan,Jenis Kelamin,Tempat Lahir,Tanggal Lahir,Alamat,Agama,Pekerjaan,Status Hidup,Email,No HP,Jabatan,Kode Rumah\n";

  static const String sampleData =
      "3270123456789012,3270000000000001,Budi Santoso,Kepala Keluarga,Kawin,Laki-laki,Jakarta,1980-01-01,Jl. Merdeka No 1,Islam,Karyawan Swasta,Aktif,budi@email.com,08123456789,WARGA,\n"
      "3270123456789012,3270000000000002,Siti Aminah,Istri,Kawin,Perempuan,Bandung,1982-02-02,Jl. Merdeka No 1,Islam,Mengurus Rumah Tangga,Aktif,siti@email.com,08129876543,WARGA,\n";

  /// Mengunduh file template CSV warga massal secara standar
  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      final String csvContent = csvHeader + sampleData;
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
}

