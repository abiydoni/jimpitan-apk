import 'package:flutter_test/flutter_test.dart';
import 'package:jimpitan/utils/resident_pdf_export.dart';

void main() {
  group('buildResidentPdfExportData', () {
    test('extracts family head and member details correctly', () {
      final data = buildResidentPdfExportData({
        'name': 'Budi Santoso',
        'noKK': '3201010000000001',
        'alamat': 'Jl. Merdeka No. 10',
        'phone': '081234567890',
        'email': 'budi@example.com',
        'familyMembers': [
          {
            'namaLengkap': 'Budi Santoso',
            'statusHubungan': 'Kepala Keluarga',
            'nik': '3201010101010001',
            'jenisKelamin': 'Laki-laki',
            'tempatLahir': 'Bandung',
            'tanggalLahir': '1990-01-01',
            'agama': 'Islam',
            'pekerjaan': 'Petani',
            'statusHidup': 'Hidup',
            'email': 'budi@example.com',
            'roles': ['WARGA'],
          },
          {
            'namaLengkap': 'Sari Santoso',
            'statusHubungan': 'Istri',
            'nik': '3201010101010002',
            'jenisKelamin': 'Perempuan',
            'tempatLahir': 'Bogor',
            'tanggalLahir': '1992-02-02',
            'agama': 'Islam',
            'pekerjaan': 'IRT',
            'statusHidup': 'Hidup',
            'email': '',
            'roles': ['WARGA'],
          },
        ],
      });

      expect(data.headName, 'Budi Santoso');
      expect(data.noKK, '3201010000000001');
      expect(data.members, hasLength(2));
      expect(data.members.first.name, 'Budi Santoso');
      expect(data.members.last.relation, 'Istri');
      expect(data.members.last.email, '-');
    });
  });
}
