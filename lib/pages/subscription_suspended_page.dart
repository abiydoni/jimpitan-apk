import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/pages/village_invoice_page.dart';

class SubscriptionSuspendedPage extends StatefulWidget {
  const SubscriptionSuspendedPage({super.key});

  @override
  State<SubscriptionSuspendedPage> createState() =>
      _SubscriptionSuspendedPageState();
}

class _SubscriptionSuspendedPageState extends State<SubscriptionSuspendedPage> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _villageId = '';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await ApiService.getUser(user.uid);
      if (userData != null) {
        final roles = List<String>.from(userData['roles'] ?? []);
        setState(() {
          _isAdmin = roles.contains('ADMIN_DESA') || roles.contains('SUPER_ADMIN');
          _villageId = userData['villageId'] ?? '';
          _isLoading = false;
        });
        return;
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Akses Ditangguhkan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Masa aktif langganan sistem desa Anda telah habis atau sedang ditangguhkan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'Silakan lunasi tagihan untuk mengaktifkan kembali sistem.'
                  : 'Silakan hubungi Ketua RT atau Pengurus Desa Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            if (_isAdmin && _villageId.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VillageInvoicePage(villageId: _villageId),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Lihat Tagihan & Bayar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // Reset notifier so it doesn't trigger again on re-login automatically
                ApiService.isSuspendedNotifier.value = false;
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar Aplikasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
