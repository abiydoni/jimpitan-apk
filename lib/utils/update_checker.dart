
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:in_app_update/in_app_update.dart';
import '../utils/api_service.dart';
import '../utils/app_theme.dart';

/// Mendeteksi apakah perangkat Android menggunakan arsitektur 64-bit (HP Baru / ARM64)
/// atau arsitektur 32-bit (HP Lama / ARMv7).
Future<bool> is64BitDevice() async {
  if (!Platform.isAndroid) return true;
  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final supported64 = androidInfo.supported64BitAbis;
    if (supported64.isNotEmpty) return true;

    final supportedAbis = androidInfo.supportedAbis;
    if (supportedAbis.any((abi) => abi.toLowerCase().contains('64') || abi.toLowerCase().contains('arm64'))) {
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Error detecting device ABI: $e');
    return true; // Default to 64-bit jika gagal deteksi
  }
}

/// Cek versi app ke server dan tampilkan dialog update jika ada versi baru.
/// Panggil di initState halaman utama setelah user login.
Future<void> checkAndShowUpdateDialog(BuildContext context, {bool forceShow = false}) async {
  try {
    // 1. Coba fitur resmi Play Store In-App Update
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        } else if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return;
        }
      }
    } catch (e) {
      // Akan gagal (throw error) jika APK diinstal dari luar Play Store (contoh: WhatsApp).
      // Kita abaikan secara diam-diam dan lanjutkan ke sistem fallback.
      debugPrint('Play Store Update skipped: $e');
    }

    // 2. Fallback (Sistem Mandiri): Ambil versi app yang sedang berjalan
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version; // misal: "1.9.2"

    // Ambil info versi terbaru dari server backend
    final versionData = await ApiService.checkAppVersion();
    if (versionData == null) return;

    final showNotification = versionData['showNotification'] ?? versionData['showUpdateNotification'] ?? true;
    final latestVersion = versionData['latestVersion']?.toString() ?? '';
    final minVersion = versionData['minVersion']?.toString() ?? '';
    final forceUpdate = versionData['forceUpdate'] == true;
    final updateUrl64 = versionData['updateUrl']?.toString() ?? '';
    final updateUrlLegacy = versionData['updateUrlLegacy']?.toString() ?? '';
    final releaseNotes = versionData['releaseNotes']?.toString() ?? '';

    // Deteksi arsitektur perangkat (HP Baru / HP Lama)
    final is64 = await is64BitDevice();
    String finalUpdateUrl = updateUrl64;
    if (!is64 && updateUrlLegacy.trim().isNotEmpty) {
      // Jika HP Lama (32-bit) dan link khusus HP lama tersedia di backend
      finalUpdateUrl = updateUrlLegacy.trim();
    } else if (finalUpdateUrl.isEmpty && updateUrlLegacy.trim().isNotEmpty) {
      finalUpdateUrl = updateUrlLegacy.trim();
    }

    // Bandingkan versi (simple string comparison untuk format X.Y.Z)
    if (!_isNewerVersion(latestVersion, currentVersion) && !forceShow) return;

    final isForced = forceUpdate || _isNewerVersion(minVersion, currentVersion);

    // Jika di backend notifikasi update ditutup (showNotification = false) & bukan force update & bukan pemicu manual, jangan munculkan pop-up otomatis di dashboard
    if (showNotification == false && !isForced && !forceShow) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialogWidget(
        latestVersion: latestVersion,
        releaseNotes: releaseNotes,
        isForced: isForced,
        updateUrl: finalUpdateUrl,
      ),
    );
  } catch (e) {
    debugPrint('checkAndShowUpdateDialog error: $e');
  }
}

class UpdateDialogWidget extends StatefulWidget {
  final String latestVersion;
  final String releaseNotes;
  final bool isForced;
  final String updateUrl;

  const UpdateDialogWidget({
    super.key,
    required this.latestVersion,
    required this.releaseNotes,
    required this.isForced,
    required this.updateUrl,
  });

  @override
  State<UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<UpdateDialogWidget> {
  bool _isDownloading = false;
  double _progress = 0;
  String _status = '';
  String? _savedApkPath;

  Future<void> _handleUpdate() async {
    final url = widget.updateUrl;
    
    // Jika URL adalah APK, lakukan in-app download
    if (url.toLowerCase().endsWith('.apk')) {
      await _downloadAndInstall(url);
    } else {
      // Jika Play Store atau URL lain, buka di browser
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openInstaller(String path) async {
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done && mounted) {
      setState(() {
        _status = 'Gagal membuka installer. Mengalihkan ke browser...';
      });
      final uri = Uri.tryParse(widget.updateUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _downloadAndInstall(String url) async {
    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = 'Menyiapkan unduhan...';
    });

    try {
      final dir = await getTemporaryDirectory();
      
      final savePath = '${dir.path}/jimpitan_update_${widget.latestVersion}.apk';
      final dio = Dio();

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status = 'Mengunduh... ${( _progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'Membuka installer...';
          _savedApkPath = savePath;
          _isDownloading = false;
        });
      }

      await _openInstaller(savePath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error Unduh: $e';
          _isDownloading = false;
        });
      }
      debugPrint('Download error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canClose = !widget.isForced && !_isDownloading;

    return PopScope(
      canPop: canClose,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Update Tersedia', style: TextStyle(fontSize: 18)),
            ),
            if (canClose)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versi ${widget.latestVersion} sudah tersedia.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (widget.releaseNotes.isNotEmpty && !_isDownloading)
              Text(widget.releaseNotes, style: TextStyle(color: Colors.grey.shade600)),
              
            if (widget.isForced && !_isDownloading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update ini wajib dilakukan untuk melanjutkan.',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Download Progress UI
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _status,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
              ),
            ] else if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _status,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (canClose)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
          if (!_isDownloading && _savedApkPath != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _openInstaller(_savedApkPath!),
              icon: const Icon(Icons.install_mobile, size: 18),
              label: const Text('Pasang APK'),
            )
          else if (!_isDownloading)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _handleUpdate,
              child: const Text('Update Sekarang'),
            ),
        ],
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

/// Tampilkan dialog unduhan APK khusus (tanpa cek versi) 
/// Berguna untuk mengunduh APK dari link di chat atau tempat lain.
Future<void> showDownloadApkDialog(BuildContext context, String apkUrl) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: DirectDownloadDialog(url: apkUrl),
    ),
  );
}

class DirectDownloadDialog extends StatefulWidget {
  final String url;
  const DirectDownloadDialog({super.key, required this.url});

  @override
  State<DirectDownloadDialog> createState() => _DirectDownloadDialogState();
}

class _DirectDownloadDialogState extends State<DirectDownloadDialog> {
  double _progress = 0;
  String _status = 'Menyiapkan unduhan...';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/jimpitan_download_${DateTime.now().millisecondsSinceEpoch}.apk';
      final dio = Dio();

      await dio.download(
        widget.url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _status = 'Mengunduh... ${( _progress * 100).toStringAsFixed(0)}%';
            });
          }
        },
      );

      setState(() {
        _status = 'Membuka installer...';
      });

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        setState(() {
          _status = 'Gagal membuka APK.';
          _isError = true;
        });
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _status = 'Error Unduh: $e';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.download_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('Mengunduh APK', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isError) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade200,
              color: AppTheme.primaryColor,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: Text(
              _status,
              style: TextStyle(
                fontSize: 13, 
                color: _isError ? Colors.red : Colors.grey.shade700, 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      actions: [
        if (_isError)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
      ],
    );
  }
}
