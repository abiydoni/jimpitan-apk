import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/update_checker.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _currentVersion = 'Memuat...';
  bool _isLoading = true;
  bool _hasUpdate = false;
  String _latestVersion = '';
  bool _is64Bit = true;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVer = info.version;
      final is64 = await is64BitDevice();
      
      final versionData = await ApiService.checkAppVersion();
      
      bool hasUp = false;
      String latest = '';

      if (versionData != null) {
        latest = versionData['latestVersion']?.toString() ?? '';
        
        if (latest.isNotEmpty && currentVer.isNotEmpty) {
          hasUp = _isNewerVersion(latest, currentVer);
        }
      }

      if (mounted) {
        setState(() {
          _currentVersion = currentVer;
          _hasUpdate = hasUp;
          _latestVersion = latest;
          _is64Bit = is64;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentVersion = 'Tidak diketahui';
        });
      }
    }
  }

  bool _isNewerVersion(String a, String b) {
    try {
      final partsA = a.split('.').map(int.parse).toList();
      final partsB = b.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final va = i < partsA.length ? partsA[i] : 0;
        final vb = i < partsB.length ? partsB[i] : 0;
        if (va > vb) return true;
        if (va < vb) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomGradientAppBar(
        titleText: 'Tentang Aplikasi',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade50,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/images/jimpitanemasbulat.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.volunteer_activism_rounded, size: 50, color: AppTheme.primaryColor);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Jimpitan Digital',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Versi $_currentVersion',
                                style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _is64Bit ? Colors.blue.shade50 : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _is64Bit ? Colors.blue.shade200 : Colors.amber.shade300, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_is64Bit ? Icons.bolt_rounded : Icons.phone_android_rounded, size: 14, color: _is64Bit ? Colors.blue.shade700 : Colors.amber.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    _is64Bit ? '64-bit' : '32-bit (HP Lama)',
                                    style: TextStyle(
                                      color: _is64Bit ? Colors.blue.shade800 : Colors.amber.shade900,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_hasUpdate)
                          Column(
                            children: [
                              const Text(
                                'Versi terbaru telah tersedia!\nSilakan update aplikasi Anda melalui tombol di bawah ini:',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () async {
                                  // Panggil in-app downloader
                                  await checkAndShowUpdateDialog(context, forceShow: true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.system_update_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Update v$_latestVersion Sekarang',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Aplikasi sudah yang terbaru',
                                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Solusi cerdas untuk mempermudah hidup bertetangga. Catat iuran, pantau kas RT, hingga diskusi warga jadi lebih praktis, rapi, dan super transparan!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(
                      'Fasilitas Utama',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildCompactFeature(Icons.account_balance_wallet_rounded, Colors.green, 'Kas Transparan', 'Pantau iuran & kas real-time')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCompactFeature(Icons.groups_rounded, Colors.blue, 'Data Warga', 'Pendataan warga di cloud aman')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCompactFeature(Icons.forum_rounded, Colors.orange, 'Ruang Diskusi', 'Chat antar warga dalam 1 RT')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCompactFeature(Icons.security_rounded, Colors.red, 'Keamanan', 'Akses privat khusus warga diverifikasi')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Footer
            const Text('Dipersembahkan dengan ❤️ oleh', style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://appsbee.my.id');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/appsbee.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.code, color: Colors.white, size: 28),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFeature(IconData icon, Color color, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3)),
        ],
      ),
    );
  }
}
