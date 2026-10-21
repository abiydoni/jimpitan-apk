import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_gradient_app_bar.dart';

import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/main.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class VillageRegistrationPage extends StatefulWidget {
  const VillageRegistrationPage({super.key});

  @override
  State<VillageRegistrationPage> createState() => _VillageRegistrationPageState();
}

class _VillageRegistrationPageState extends State<VillageRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _villageNameController = TextEditingController();
  final _rtRwController = TextEditingController();
  final _addressController = TextEditingController();
  final _noKKController = TextEditingController();
  final _nikController = TextEditingController();
  final _phoneController = TextEditingController();

  Future<void> _handleCancel() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _villageNameController.dispose();
    _rtRwController.dispose();
    _addressController.dispose();
    _noKKController.dispose();
    _nikController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerVillage() async {
    if (!_formKey.currentState!.validate()) {
      CustomToast.show(
        context,
        'Mohon lengkapi semua data wajib yang disediakan.',
        isError: true,
      );
      return;
    }

    final villageName = _villageNameController.text.trim();
    final address = _addressController.text.trim();
    final rtRw = _rtRwController.text.trim();
    final noKK = _noKKController.text.trim();
    final nik = _nikController.text.trim();
    final phone = _phoneController.text.trim();

    if (villageName.isEmpty ||
        address.isEmpty ||
        rtRw.isEmpty ||
        noKK.isEmpty ||
        nik.isEmpty ||
        phone.isEmpty) {
      CustomToast.show(
        context,
        'Seluruh data wajib diisi, tidak boleh ada yang kosong.',
        isError: true,
      );
      return;
    }

    if (noKK.length < 16) {
      CustomToast.show(
        context,
        'Nomor Kartu Keluarga (KK) harus 16 digit angka.',
        isError: true,
      );
      return;
    }

    if (nik.length < 16) {
      CustomToast.show(
        context,
        'NIK Admin harus 16 digit angka.',
        isError: true,
      );
      return;
    }

    if (phone.length < 10) {
      CustomToast.show(
        context,
        'Nomor WhatsApp minimal 10 digit.',
        isError: true,
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    EasyLoading.show(status: 'Mendaftarkan Desa...');

    try {
      final data = {
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'noKK': noKK,
        'nik': nik,
        'phone': phone,
        'villageName': villageName,
        'address': address,
        'rtRw': rtRw,
      };

      final success = await ApiService.registerVillage(data);

      if (!success) {
        throw Exception('Gagal mendaftarkan desa. Pastikan semua data terisi dengan benar.');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AuthWrapper(user: FirebaseAuth.instance.currentUser!),
          ),
          (route) => false,
        ); 
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Terjadi kesalahan: ${e.toString()}', isError: true);
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: CustomGradientAppBar(
          titleText: 'Pendaftaran Desa / RT Baru',
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: _handleCancel,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Trial Info
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.secondaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Uji Coba Gratis 1 Bulan (Trial)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const Text(
                                'Akses seluruh fitur premium tanpa biaya',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildInfoBullet('Akun Anda otomatis menjadi Admin Desa / Pengurus.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('Kode unik desa (5 angka) akan dibuat otomatis oleh sistem.'),
                    const SizedBox(height: 6),
                    _buildInfoBullet('No KK, NIK, dan seluruh data bertanda (Wajib) harus diisi dengan benar.'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // BAGIAN 1: DATA ADMIN / KETUA RT PENDAFTAR
              // ==========================================
              Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '1. Data Admin / Ketua Pendaftar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info Akun Google Pendaftar
              if (currentUser != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: currentUser.photoURL != null ? NetworkImage(currentUser.photoURL!) : null,
                        child: currentUser.photoURL == null
                            ? Icon(Icons.person, color: AppTheme.primaryColor)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.displayName ?? 'Nama Admin',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              currentUser.email ?? '',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'Calon Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Input No KK Admin
              TextFormField(
                controller: _noKKController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nomor Kartu Keluarga (No KK) wajib diisi';
                  if (v.trim().length < 16) return 'Nomor KK harus 16 digit angka';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Nomor Kartu Keluarga Admin (Wajib)',
                  hintText: 'Contoh: 3270xxxxxxxxxxxx',
                  helperText: 'Nomor KK ketua/pengurus yang mendaftarkan desa.',
                  prefixIcon: Icon(Icons.credit_card_rounded, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Input NIK Admin
              TextFormField(
                controller: _nikController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'NIK Admin / Ketua wajib diisi';
                  if (v.trim().length < 16) return 'NIK harus 16 digit angka';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'NIK Admin / Ketua (Wajib)',
                  hintText: 'Contoh: 3270xxxxxxxxxxxx',
                  helperText: 'Nomor Induk Kependudukan admin pendaftar.',
                  prefixIcon: Icon(Icons.badge_rounded, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // Input No HP / WhatsApp
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nomor HP/WhatsApp wajib diisi';
                  if (v.trim().length < 10) return 'Nomor WhatsApp minimal 10 digit';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Nomor HP / WhatsApp (Wajib)',
                  hintText: 'Contoh: 081234567890',
                  helperText: 'Untuk komunikasi dan notifikasi sistem.',
                  prefixIcon: Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),

              const SizedBox(height: 28),

              // ==========================================
              // BAGIAN 2: DATA LINGKUNGAN / DESA / RT
              // ==========================================
              Row(
                children: [
                  Icon(Icons.location_city_rounded, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '2. Data Wilayah / Lingkungan / RT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Nama Desa / Lingkungan
              TextFormField(
                controller: _villageNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama Desa/Lingkungan wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'Nama Desa / Lingkungan (Wajib)',
                  hintText: 'Contoh: Perumahan Griya Indah / Desa Sukamaju',
                  helperText: 'Isikan nama perumahan, paguyuban, atau nama desa Anda.',
                  prefixIcon: Icon(Icons.maps_home_work_rounded, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Cakupan RT / RW
              TextFormField(
                controller: _rtRwController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'RT/RW wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'Cakupan RT / RW (Wajib)',
                  hintText: 'Contoh: RT 01 / RW 05 atau RT 03',
                  helperText: 'Isikan nomor RT dan RW yang dinaungi.',
                  prefixIcon: Icon(Icons.holiday_village_rounded, color: AppTheme.primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Alamat Lengkap
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat lengkap wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap Lingkungan (Wajib)',
                  hintText: 'Contoh: Jl. Mawar Blok A No. 1, Kel. Mekarjaya, Kec. Sukmajaya, Kota Depok',
                  helperText: 'Isikan alamat sekretariat RT atau lokasi lengkap desa.',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 45),
                    child: Icon(Icons.map_rounded, color: AppTheme.primaryColor),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
                ),
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _registerVillage,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Daftarkan Desa & Mulai Trial 1 Bulan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _handleCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 20, color: Color(0xFF64748B)),
                  label: const Text(
                    'Batal / Keluar Aplikasi',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildInfoBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
          ),
        ),
      ],
    );
  }
}
