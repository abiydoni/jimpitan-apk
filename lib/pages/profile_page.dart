import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jimpitan/utils/image_compressor.dart';
import '../widgets/user_avatar.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/pages/about_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  
  // Controllers for editing profile
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _agamaController = TextEditingController();
  final TextEditingController _pekerjaanController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _tempatLahirController = TextEditingController();
  final TextEditingController _tanggalLahirController = TextEditingController();
  String? _selectedJenisKelamin;
  String? _selectedStatusHubungan;
  


  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final data = await ApiService.getUser(user.uid);
      if (data != null) {
        if (mounted) {
          setState(() {
            _userData = data;
            _phoneController.text = _userData!['phoneNumber'] ?? '';
            _agamaController.text = _userData!['agama'] ?? '';
            _pekerjaanController.text = _userData!['pekerjaan'] ?? '';
            _alamatController.text = _userData!['alamat'] ?? '';
            _tempatLahirController.text = _userData!['tempatLahir'] ?? '';
            _tanggalLahirController.text = _userData!['tanggalLahir'] ?? '';
            _selectedJenisKelamin = _userData!['jenisKelamin'];
            _selectedStatusHubungan = _userData!['statusHubungan'];
          });
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      EasyLoading.show(status: 'Memproses gambar...');
      // Beri waktu sejenak agar UI sempat me-render loading overlay
      await Future.delayed(const Duration(milliseconds: 50));
      
      try {
        final bytes = await image.readAsBytes();
        final base64String = await ImageCompressor.compressImage(bytes, width: 300, quality: 30);
        
        if (base64String != null) {
          if (_userData != null && _userData!['uid'] != null) {
            EasyLoading.show(status: 'Mengunggah foto...');
            try {
              await ApiService.updateProfile(_userData!['uid'], {
                'foto': base64String,
              });
              await _loadProfile();
            } finally {
              EasyLoading.dismiss();
            }
          } else {
            EasyLoading.dismiss();
          }
        } else {
          EasyLoading.dismiss();
        }
      } catch (e) {
        EasyLoading.dismiss();
        debugPrint('Error compressing image: $e');
        if (mounted) {
          CustomToast.show(context, 'Gagal memproses gambar profil.', isError: true);
        }
      }
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AppModalDialog(
              title: 'Edit Profil',
          headerIcon: Icons.person,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text('Catatan: Nama, NIK, dan data primer lainnya hanya dapat diubah oleh Admin RT.', style: TextStyle(fontSize: 12, color: Colors.blueGrey))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      prefixIcon: const Icon(Icons.phone, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _agamaController,
                    decoration: InputDecoration(
                      labelText: 'Agama',
                      prefixIcon: const Icon(Icons.mosque, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pekerjaanController,
                    decoration: InputDecoration(
                      labelText: 'Pekerjaan',
                      prefixIcon: const Icon(Icons.work, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  TextField(
                    controller: _alamatController,
                    decoration: InputDecoration(
                      labelText: 'Alamat',
                      prefixIcon: const Icon(Icons.home, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tempatLahirController,
                          decoration: InputDecoration(
                            labelText: 'Tempat Lahir',
                            prefixIcon: const Icon(Icons.location_city, color: Colors.black45),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _tanggalLahirController,
                          decoration: InputDecoration(
                            labelText: 'Tgl Lahir (YYYY-MM-DD)',
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.black45),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedJenisKelamin,
                    decoration: InputDecoration(
                      labelText: 'Jenis Kelamin',
                      prefixIcon: const Icon(Icons.wc, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-Laki')),
                      DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        _selectedJenisKelamin = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatusHubungan,
                    decoration: InputDecoration(
                      labelText: 'Status Hubungan',
                      prefixIcon: const Icon(Icons.family_restroom, color: Colors.black45),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Kepala Keluarga', child: Text('Kepala Keluarga')),
                      DropdownMenuItem(value: 'Istri', child: Text('Istri')),
                      DropdownMenuItem(value: 'Anak', child: Text('Anak')),
                      DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        _selectedStatusHubungan = value;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_userData != null && _userData!['uid'] != null) {
                              EasyLoading.show(status: 'Menyimpan...');
                              try {
                                bool success = await ApiService.updateProfile(_userData!['uid'], {
                                  'phoneNumber': _phoneController.text,
                                  'agama': _agamaController.text,
                                  'pekerjaan': _pekerjaanController.text,
                                  'alamat': _alamatController.text,
                                  'tempatLahir': _tempatLahirController.text,
                                  'tanggalLahir': _tanggalLahirController.text,
                                  'jenisKelamin': _selectedJenisKelamin,
                                  'statusHubungan': _selectedStatusHubungan,
                                });
                                
                                if (success) {
                                  await _loadProfile();
                                  if (context.mounted) {
                                    CustomToast.show(context, 'Profil berhasil diperbarui');
                                    Navigator.pop(context);
                                  }
                                } else {
                                  if (context.mounted) {
                                    CustomToast.show(context, 'Gagal memperbarui profil', isError: true);
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  CustomToast.show(context, 'Terjadi kesalahan: $e', isError: true);
                                }
                              } finally {
                                EasyLoading.dismiss();
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userData == null) {
      return const Scaffold(
        appBar: CustomGradientAppBar(titleText: 'Profil Saya'),
        body: Center(child: Text('Data profil tidak ditemukan di database.')),
      );
    }

    return Scaffold(
      appBar: const CustomGradientAppBar(
        titleText: 'Profil Saya',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    userData: _userData,
                    radius: 50,
                    iconSize: 50,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _changePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _userData!['name'] ?? 'Pengguna',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              _userData!['email'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
            
            const SizedBox(height: 32),
            
            _buildProfileItem(Icons.credit_card, 'NIK', _userData!['nik']?.toString() ?? '-'),
            _buildProfileItem(Icons.wc, 'Jenis Kelamin', _userData!['jenisKelamin'] ?? '-'),
            _buildProfileItem(Icons.cake, 'Tempat, Tgl Lahir', '${_userData!['tempatLahir'] ?? '-'}, ${_userData!['tanggalLahir'] ?? '-'}'),
            _buildProfileItem(Icons.mosque, 'Agama', _userData!['agama'] ?? '-'),
            _buildProfileItem(Icons.work, 'Pekerjaan', _userData!['pekerjaan'] ?? '-'),
            _buildProfileItem(Icons.family_restroom, 'Status Hubungan', _userData!['statusHubungan'] ?? '-'),
            _buildProfileItem(Icons.phone, 'Nomor WhatsApp', _userData!['phoneNumber'] ?? '-'),
            _buildProfileItem(Icons.badge, 'Jabatan (Role)', (_userData!['roles'] as List<dynamic>?)?.join(', ') ?? 'WARGA'),
            _buildProfileItem(Icons.home, 'ID Desa', _userData!['villageId'] ?? '-'),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: Icon(Icons.edit, color: AppTheme.primaryColor),
                label: Text('Edit Profil', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primaryColor, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
                },
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Tentang Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AppModalDialog(
                      title: 'Konfirmasi Logout',
                      headerIcon: Icons.logout,
                      scrollable: false,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(false),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(true),
                                  child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await GoogleSignIn().signOut();
                      await _auth.signOut();
                    } catch (_) {}
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Keluar (Logout)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

