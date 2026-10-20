import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/custom_toast.dart';

/// ============================================================================
/// GOOGLE PLAY REVIEWER / DEMO BYPASS
/// ============================================================================
/// Fitur ini dibuat khusus agar peninjau Google Play Store dapat melakukan login
/// secara mandiri tanpa terhalang Verifikasi 2 Langkah (2FA / OTP / SMS).
///
/// CARA MENGATUR:
/// 1. AKTIF/NONAKTIF CEPAT:
///    Cukup ganti `kEnableReviewerBypass = false;` di bawah ini.
///    Tombol di halaman login akan langsung hilang dan tidak bisa diakses.
///
/// 2. HAPUS PERMANEN (Saat sudah tidak diperlukan):
///    - Hapus file ini (`lib/utils/reviewer_bypass.dart`)
///    - Buka `lib/pages/login_page.dart` dan hapus blok bertanda:
///      `// === GOOGLE REVIEWER BYPASS ===`
/// ============================================================================

/// Toggle master untuk mengaktifkan / mematikan tombol login peninjau.
const bool kEnableReviewerBypass = false;

/// Default kredensial yang didaftarkan di Google Play Console > Akses Aplikasi:
const String kDefaultReviewerEmail = 'appsbeedua@gmail.com';
const String kDefaultReviewerPassword = 'Reviewer2026!';

class ReviewerBypassWidget extends StatelessWidget {
  final Function(User user) onSuccess;

  const ReviewerBypassWidget({
    super.key,
    required this.onSuccess,
  });

  void _showLoginDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReviewerLoginSheet(onSuccess: onSuccess),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnableReviewerBypass) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _showLoginDialog(context),
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: const Text(
            'Login Akun Penguji (Play Store)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }
}

class _ReviewerLoginSheet extends StatefulWidget {
  final Function(User user) onSuccess;

  const _ReviewerLoginSheet({required this.onSuccess});

  @override
  State<_ReviewerLoginSheet> createState() => _ReviewerLoginSheetState();
}

class _ReviewerLoginSheetState extends State<_ReviewerLoginSheet> {
  final TextEditingController _emailController =
      TextEditingController(text: kDefaultReviewerEmail);
  final TextEditingController _passwordController =
      TextEditingController(text: kDefaultReviewerPassword);
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleBypassLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      CustomToast.show(context, 'Email dan password tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    EasyLoading.show(status: 'Memverifikasi akun penguji...');

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        EasyLoading.dismiss();
        if (mounted) {
          Navigator.of(context).pop(); // Tutup bottom sheet
          widget.onSuccess(user);
        }
      } else {
        throw Exception('User tidak ditemukan setelah otentikasi.');
      }
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        String msg = 'Gagal login: ${e.message}';
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          msg = 'Email atau password penguji salah.';
        }
        CustomToast.show(context, msg, isError: true);
      }
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) {
        CustomToast.show(context, 'Terjadi kesalahan: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.security_rounded, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login Akun Penguji',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Google Play Reviewer Access',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode ini digunakan untuk pengujian Google Play tanpa memerlukan verifikasi 2 langkah (2FA/SMS/Galaxy Prompt).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Penguji',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleBypassLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Masuk Sekarang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
