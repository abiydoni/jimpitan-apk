import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jimpitan/main.dart';
import 'package:flutter/services.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleUserData(User user) async {
    await ApiService.loginSync({
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName,
      'photoUrl': user.photoURL,
    });
  }

  Future<void> _signInWithGoogle(String intent) async {
    if (!mounted) return;
    EasyLoading.show(status: 'Memproses Google...');
    try {
      // Simpan intent pengguna ke SharedPreferences sebelum login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_intent', intent);

      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
      } else {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          try {
            await googleSignIn.signOut();
          } catch (_) {}

          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

          if (googleUser == null) {
            EasyLoading.dismiss();
            return;
          }

          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          if (googleAuth.idToken == null) {
            throw Exception('Google Auth idToken is null. (accessToken: ${googleAuth.accessToken != null})');
          }

          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          userCredential = await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
        } catch (e, st) {
          debugPrint('Native GoogleSignIn failed ($e), falling back to signInWithProvider...');
          try {
            userCredential = await FirebaseAuth.instance.signInWithProvider(
              googleProvider,
            );
          } catch (fallbackError, fallbackSt) {
            EasyLoading.dismiss();
            if (mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Detail Error Google Sign-In'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '1. Native GoogleSignIn Error:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText('$e\n$st'),
                        const SizedBox(height: 8),
                        const Text(
                          '2. Fallback Provider Error:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText('$fallbackError\n$fallbackSt'),
                      ],
                    ),
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
            rethrow;
          }
        }
      }

      final User? user = userCredential.user;

      if (user != null) {
        // Cek dulu apakah user sudah terdaftar sebelum navigasi
        final userData = await ApiService.getUser(user.uid);
        final status = userData?['status']?.toString();

        if (intent == 'REGISTER_VILLAGE' &&
            userData != null &&
            status != 'INCOMPLETE') {
          // User mencoba daftar desa tapi sudah punya akun
          await GoogleSignIn().signOut();
          await FirebaseAuth.instance.signOut();
          EasyLoading.dismiss();
          if (mounted) {
            CustomToast.show(
              context,
              'Akun Anda sudah terdaftar. Silakan masuk melalui menu Login biasa (Masuk ke Aplikasi).',
              isError: true,
            );
          }
          return; // Hentikan proses, tetap di halaman login
        }

        await _handleUserData(user);

        EasyLoading.dismiss();
        if (mounted) {
          // Gunakan pushReplacementNamed jika memungkinkan, atau navigasi ke '/' yang akan me-reload AuthWrapper dari MyApp
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => AuthWrapper(user: user)),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError('Google Sign-In Gagal: ${e.message}');
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
    if (!mounted) return;
    CustomToast.show(context, message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent, // Ensure status bar is transparent
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Modern off-white background
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 100,
          ),
          child: Column(
            children: [
              // Premium Header
              Stack(
                children: [
                  ClipPath(
                    clipper: _ModernHeaderClipper(),
                    child: Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/jimpitanemasbulat.png',
                            width: 80,
                            height: 80,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Jimpitan Digital",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Transparansi Iuran Desa",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Form Login Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Pilih Layanan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Silakan pilih layanan yang Anda butuhkan untuk melanjutkan.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // 1. Tombol Masuk Aplikasi (Login Biasa)
                    _buildPortalButton(
                      title: 'Masuk ke Aplikasi atau Gabung Desa (Warga Baru)',
                      subtitle: 'Untuk warga & admin yang sudah terdaftar',
                      icon: Icons.login,
                      color: AppTheme.primaryColor,
                      onTap: () => _signInWithGoogle('LOGIN'),
                    ),

                    const SizedBox(height: 16),

                    // 3. Tombol Daftar Desa Baru
                    _buildPortalButton(
                      title: 'Daftarkan Desa Baru',
                      subtitle: 'Untuk Admin, Coba gratis 14 Hari',
                      icon: Icons.maps_home_work,
                      color: Colors.green,
                      onTap: () => _signInWithGoogle('REGISTER_VILLAGE'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info Banner Trial
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Masa Uji Coba (Trial) 14 Hari',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Bagi Desa/RT yang baru mendaftar, Anda otomatis mendapatkan akses fitur Premium gratis selama 14 hari penuh. Tanpa kartu kredit, 100% aman.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Footer
              const Text(
                'Dipersembahkan dengan ❤️ oleh',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse('https://appsbee.my.id');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/images/appsbee.png',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.code, color: Colors.white, size: 28),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

// Custom Clipper untuk efek lengkungan modern yang lebih soft
class _ModernHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);

    // Smooth curve
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
