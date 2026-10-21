import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/main.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class JoinVillagePage extends StatefulWidget {
  const JoinVillagePage({super.key});

  @override
  State<JoinVillagePage> createState() => _JoinVillagePageState();
}

class _JoinVillagePageState extends State<JoinVillagePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();

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
    _codeController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _joinVillage() async {
    if (_codeController.text.trim().length < 5) {
      _showError('Mohon isi 5 digit Kode Desa dengan lengkap.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    EasyLoading.show(status: 'Memeriksa...');

    try {
      final code = _codeController.text.trim().toUpperCase();
      
      // Cari desa berdasarkan kode
      final village = await ApiService.checkVillageCode(code);
          
      if (village == null) {
        EasyLoading.dismiss();
        _showError('Kode Desa tidak ditemukan. Pastikan Anda memasukkan kode yang benar.');
        return;
      }
      
      final villageId = village['id'];
      final inputNik = _nikController.text.trim();
      final inputName = _nameController.text.trim();

      // KASUS 1: Jika user MEMASUKKAN NIK -> Otomatis sinkronisasi & verifikasi kemiripan nama
      if (inputNik.isNotEmpty) {
        EasyLoading.show(status: 'Mencocokkan NIK & Nama...');
        final claimRes = await ApiService.claimAccount(
          user.uid,
          user.email ?? '',
          inputNik,
          villageId,
          inputName,
        );

        if (claimRes['success'] == true) {
          EasyLoading.dismiss();
          if (mounted) {
            CustomToast.show(
              context,
              claimRes['message'] ?? 'Akun berhasil disinkronkan langsung!',
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => AuthWrapper(user: user)),
              (route) => false,
            );
          }
          return;
        } else {
          // Gagal sinkronisasi karena NIK tidak cocok atau nama tidak sesuai
          EasyLoading.dismiss();
          _showError(claimRes['message'] ?? 'Gagal mencocokkan NIK dengan data warga.');
          return;
        }
      }

      // KASUS 2: Jika user HANYA memasukkan Nama (NIK kosong) -> Alur manual biasa (status: PENDING)
      EasyLoading.show(status: 'Mendaftar...');
      final userData = {
        'uid': user.uid,
        'name': inputName,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'roles': ['WARGA'],
        'villageId': villageId,
        'status': 'PENDING',
      };

      final success = await ApiService.updateProfile(user.uid, userData);

      if (!success) {
        throw Exception('Gagal bergabung dengan desa');
      }

      // Kirim chat notifikasi ke semua admin desa
      try {
        final usersSnap = await ApiService.getUsers(villageId);
        final admins = usersSnap.where((u) {
          if (u is Map) {
            final roles = u['roles'] as List<dynamic>? ?? [];
            return roles.contains('ADMIN') || roles.contains('ADMIN_DESA');
          }
          return false;
        }).toList();

        final userName = inputName;
        final message = 'Halo Admin, warga baru bernama *$userName* baru saja mendaftar/bergabung ke lingkungan. Mohon cek pendaftarannya.';

        for (final admin in admins) {
          final adminUid = admin['uid']?.toString();
          if (adminUid != null) {
            final uids = [user.uid, adminUid];
            uids.sort();
            final roomId = 'PERSONAL_${uids[0]}_${uids[1]}';
            await ApiService.sendMessage(
              villageId,
              user.uid,
              adminUid,
              message,
              roomId: roomId,
              senderName: userName,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to send notification to admins: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthWrapper(user: user)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Terjadi kesalahan: ${e.toString()}');
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _showError(String message) {
    CustomToast.show(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: CustomGradientAppBar(
          titleText: 'Gabung Desa / Lingkungan',
          centerTitle: true,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Illustration/Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.maps_home_work_outlined, size: 48, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Lengkapi Data Diri',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan kode desa dari Ketua RT Anda beserta data diri yang sesuai.',
                  style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 32),
                
                const Text(
                  'Kode Desa',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _OtpInput(
                  onCompleted: (code) {
                    _codeController.text = code;
                  },
                ),
                const SizedBox(height: 24),
                
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Nama Lengkap (Sesuai KTP)',
                  hint: 'Masukkan nama lengkap',
                  icon: Icons.person_outline,
                  validatorMsg: 'Nama Lengkap wajib diisi',
                ),
                const SizedBox(height: 20),
                
                _buildModernTextField(
                  controller: _nikController,
                  label: 'NIK (Opsional)',
                  hint: 'Masukkan 16 digit NIK jika sudah didaftarkan RT',
                  icon: Icons.badge_outlined,
                  validatorMsg: '',
                  keyboardType: TextInputType.number,
                  isRequired: false,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, top: 6.0),
                  child: Text(
                    '💡 Jika NIK diisi dan cocok dengan data di RT, akun Anda akan otomatis terhubung langsung.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                  ),
                ),
                
                const SizedBox(height: 36),
                
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _joinVillage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Gabung Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String validatorMsg,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (v) {
        if (!isRequired) return null;
        return v == null || v.isEmpty ? validatorMsg : null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: const BorderSide(color: Colors.red, width: 1.5)
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), 
          borderSide: const BorderSide(color: Colors.red, width: 2)
        ),
      ),
    );
  }
}

class _OtpInput extends StatefulWidget {
  final Function(String) onCompleted;
  const _OtpInput({required this.onCompleted});

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final List<TextEditingController> _controllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 4) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    String code = _controllers.map((c) => c.text).join();
    widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.15,
          height: 65,
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.toUpperCase());
              }),
            ],
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2.5),
              ),
            ),
            onChanged: (value) => _onChanged(value, index),
          ),
        );
      }),
    );
  }
}

