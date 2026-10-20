import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import '../utils/api_service.dart';
import '../utils/app_theme.dart';

const String kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=jimpitan.appsbee.my.id';
const String kPlayStoreMarketUri = 'market://details?id=jimpitan.appsbee.my.id';

/// Membuka aplikasi Google Play Store ke halaman aplikasi Jimpitan Digital
Future<void> launchPlayStore() async {
  final marketUri = Uri.parse(kPlayStoreMarketUri);
  final webUri = Uri.parse(kPlayStoreUrl);

  try {
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (e) {
    debugPrint('Could not launch market uri: $e');
  }

  try {
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Could not launch web play store uri: $e');
  }
}


/// Cek versi app ke Google Play Store & server backend.
/// Menampilkan dialog konfirmasi kecil dan elegan jika ada pembaruan.
Future<void> checkAndShowUpdateDialog(BuildContext context, {bool forceShow = false}) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version; // contoh: "1.10.1"

    // 1. Cek pembaruan via Google Play In-App Update API
    bool hasPlayStoreUpdate = false;
    AppUpdateInfo? playUpdateInfo;
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        hasPlayStoreUpdate = true;
        playUpdateInfo = updateInfo;
      }
    } catch (e) {
      debugPrint('Play Store In-App Update check skipped: $e');
    }

    // 2. Cek metadata versi dari server backend
    final versionData = await ApiService.checkAppVersion();
    final latestVersion = versionData?['latestVersion']?.toString() ?? '';
    final minVersion = versionData?['minVersion']?.toString() ?? '';
    final forceUpdate = versionData?['forceUpdate'] == true;
    final showNotification = versionData?['showNotification'] ?? versionData?['showUpdateNotification'] ?? true;
    final releaseNotes = versionData?['releaseNotes']?.toString() ?? '';

    final hasBackendUpdate = latestVersion.isNotEmpty && _isNewerVersion(latestVersion, currentVersion);
    final hasUpdate = hasPlayStoreUpdate || hasBackendUpdate;

    if (!hasUpdate && !forceShow) return;

    final isForced = forceUpdate || (minVersion.isNotEmpty && _isNewerVersion(minVersion, currentVersion));

    // Jika notifikasi ditutup di backend & bukan update wajib & bukan pemicu manual, lewati
    if (showNotification == false && !isForced && !forceShow) return;

    if (!context.mounted) return;

    final displayLatestVersion = latestVersion.isNotEmpty ? latestVersion : 'Terbaru';

    showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (ctx) => CompactUpdateDialog(
        currentVersion: currentVersion,
        latestVersion: displayLatestVersion,
        releaseNotes: releaseNotes,
        isForced: isForced,
        playUpdateInfo: playUpdateInfo,
      ),
    );
  } catch (e) {
    debugPrint('checkAndShowUpdateDialog error: $e');
  }
}

/// Dialog Konfirmasi Pembaruan: Dibuat Kecil, Elegan, dan Ramah Pengguna
class CompactUpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final bool isForced;
  final AppUpdateInfo? playUpdateInfo;

  const CompactUpdateDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.isForced,
    this.playUpdateInfo,
  });

  Future<void> _handleUpdate(BuildContext context) async {
    Navigator.of(context).pop();

    // 1. Jika In-App Update Play Store tersedia, gunakan alur resmi Google Play
    if (playUpdateInfo != null && playUpdateInfo!.immediateUpdateAllowed) {
      try {
        await InAppUpdate.performImmediateUpdate();
        return;
      } catch (e) {
        debugPrint('performImmediateUpdate error: $e');
      }
    }

    // 2. Fallback: Buka Google Play Store secara langsung
    await launchPlayStore();
  }

  @override
  Widget build(BuildContext context) {
    final canClose = !isForced;

    return PopScope(
      canPop: canClose,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon Kecil & Modern
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),

              // Judul & Badge Versi
              const Text(
                'Pembaruan Tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v$currentVersion ➔ v$latestVersion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Pesan Singkat
              Text(
                isForced
                    ? 'Versi terbaru wajib diperbarui untuk dapat melanjutkan penggunaan aplikasi.'
                    : 'Versi baru sudah siap di Google Play Store. Perbarui sekarang untuk performa dan stabilitas terbaik.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isForced ? Colors.red.shade700 : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              // Catatan Rilis (jika ada)
              if (releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    releaseNotes.trim(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Tombol Tindakan (Tunda / Perbarui)
              Row(
                children: [
                  if (canClose) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Nanti',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleUpdate(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Perbarui',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandingkan dua versi dalam format "X.Y.Z".
/// Return true jika [a] lebih baru dari [b].
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
    return false; // sama
  } catch (_) {
    return false;
  }
}
