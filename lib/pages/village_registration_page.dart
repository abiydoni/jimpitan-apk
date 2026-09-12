import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';

import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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

  @override
  void dispose() {
    _villageNameController.dispose();
    _rtRwController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _registerVillage() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    EasyLoading.show(status: 'Mendaftarkan Desa...');

    try {
      final data = {
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'villageName': _villageNameController.text.trim(),
        'address': _addressController.text.trim(),
        'rtRw': _rtRwController.text.trim(),
      };

      final success = await ApiService.registerVillage(data);

      if (!success) {
        throw Exception('Gagal mendaftarkan desa');
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
    return Scaffold(
      appBar: CustomGradientAppBar(
        titleText: 'Daftar Desa/RT Baru',
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mulai Uji Coba Gratis 14 Hari',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan isi detail lingkungan/desa Anda untuk mulai menggunakan aplikasi Jimpitan.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _villageNameController,
                validator: (v) => v == null || v.isEmpty ? 'Nama Desa/Lingkungan wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'Nama Desa / Lingkungan',
                  hintText: 'Cth: Perumahan Asri',
                  prefixIcon: const Icon(Icons.home),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _rtRwController,
                validator: (v) => v == null || v.isEmpty ? 'RT/RW wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'RT / RW',
                  hintText: 'Cth: RT 01 / RW 05',
                  prefixIcon: const Icon(Icons.location_city),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Alamat lengkap wajib diisi' : null,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.map),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _registerVillage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Daftarkan Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
