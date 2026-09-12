import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class ScanPage extends StatefulWidget {
  final String villageId;
  const ScanPage({super.key, required this.villageId});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  Timer? _clockTimer;
  Timer? _syncTimer;
  DateTime _currentTime = DateTime.now();

  // Cache untuk menghindari API call berulang
  List<dynamic>? _cachedUsers;
  List<dynamic>? _cachedTariffs;

  // State untuk overlay notifikasi besar di tengah
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  List<dynamic> _todayScans = [];
  bool _isLoadingScans = true;

  @override
  void initState() {
    super.initState();
    _loadScans();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    // Poll data setiap 3 detik agar realtime tanpa berkedip (loading indicator dimatikan)
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _loadScansSilent();
      }
    });
  }

  Future<void> _loadScans() async {
    try {
      final results = await Future.wait([
        ApiService.getJimpitanHistory(widget.villageId),
        if (_cachedUsers == null)
          ApiService.getUsers(widget.villageId)
        else
          Future.value(_cachedUsers!),
        if (_cachedTariffs == null)
          ApiService.getTariffs(widget.villageId)
        else
          Future.value(_cachedTariffs!),
      ]);

      final histories = results[0];
      _cachedUsers = results[1];
      _cachedTariffs = results[2];

      final todayStart = DateTime(
        _currentTime.year,
        _currentTime.month,
        _currentTime.day,
        0,
        0,
        0,
      );

      final todayDocs = histories.where((data) {
        DateTime? t;
        if (data['timestamp'] is String) {
          t = DateTime.tryParse(data['timestamp']);
        }

        if (t == null) return false;
        return !t.isBefore(todayStart);
      }).toList();

      if (mounted) {
        setState(() {
          _todayScans = todayDocs;
          _isLoadingScans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingScans = false;
        });
      }
    }
  }

  Future<void> _loadScansSilent() async {
    try {
      final histories = await ApiService.getJimpitanHistory(widget.villageId);
      final todayStart = DateTime(
        _currentTime.year,
        _currentTime.month,
        _currentTime.day,
        0,
        0,
        0,
      );
      final todayDocs = histories.where((data) {
        DateTime? t;
        if (data['timestamp'] is String) {
          t = DateTime.tryParse(data['timestamp']);
        }
        if (t == null) return false;
        return !t.isBefore(todayStart);
      }).toList();

      if (mounted) {
        setState(() {
          _todayScans = todayDocs;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Generate & play suara 'ting' kaya gelas kristal dipukul (harmonic overtones)
  Future<void> _playTingSound() async {
    try {
      const int sampleRate = 44100;
      // Durasi lebih panjang agar resonansi terasa
      const double durationSec = 1.2;
      final int numSamples = (sampleRate * durationSec).toInt();

      final ByteData wav = ByteData(44 + numSamples * 2);
      wav.setUint32(0, 0x46464952, Endian.little); // 'RIFF'
      wav.setUint32(4, 36 + numSamples * 2, Endian.little);
      wav.setUint32(8, 0x45564157, Endian.little); // 'WAVE'
      wav.setUint32(12, 0x20746D66, Endian.little); // 'fmt '
      wav.setUint32(16, 16, Endian.little);
      wav.setUint16(20, 1, Endian.little); // PCM
      wav.setUint16(22, 1, Endian.little); // mono
      wav.setUint32(24, sampleRate, Endian.little);
      wav.setUint32(28, sampleRate * 2, Endian.little);
      wav.setUint16(32, 2, Endian.little);
      wav.setUint16(34, 16, Endian.little);
      wav.setUint32(36, 0x61746164, Endian.little); // 'data'
      wav.setUint32(40, numSamples * 2, Endian.little);

      // Frekuensi dasar gelas kristal ~800Hz + harmonik
      const double f1 = 880.0; // nada dasar
      const double f2 = 2640.0; // harmonik ke-3 (bright overtone)
      const double f3 = 4400.0; // harmonik ke-5 (sparkle)

      for (int i = 0; i < numSamples; i++) {
        final double t = i / sampleRate;
        // Serangan cepat lalu peluruhan lambat (seperti gelas dipukul)
        final double attack = math.min(t / 0.003, 1.0); // serangan 3ms
        final double decay = math.exp(-t * 4.5); // peluruhan alami
        final double envelope = attack * decay;
        // Mix tiga harmonik: nada dasar dominan + overtone
        final double sample =
            (math.sin(2 * math.pi * f1 * t) * 0.65 +
                math.sin(2 * math.pi * f2 * t) * 0.25 +
                math.sin(2 * math.pi * f3 * t) * 0.10) *
            envelope;
        final int pcm = (sample * 26000).clamp(-32768, 32767).toInt();
        wav.setInt16(44 + i * 2, pcm, Endian.little);
      }

      final player = AudioPlayer();
      await player.play(BytesSource(wav.buffer.asUint8List()));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }

  Future<void> _processScan(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Pastikan cache users & tariffs tersedia (dari memori RAM, instan 0 ms jika sudah dimuat di initState)
      if (_cachedUsers == null || _cachedTariffs == null) {
        final res = await Future.wait([
          _cachedUsers != null
              ? Future.value(_cachedUsers!)
              : ApiService.getUsers(widget.villageId),
          _cachedTariffs != null
              ? Future.value(_cachedTariffs!)
              : ApiService.getTariffs(widget.villageId),
        ]);
        _cachedUsers = res[0];
        _cachedTariffs = res[1];
      }

      final usersResult = _cachedUsers!;
      var userData = usersResult.cast<Map<String, dynamic>?>().firstWhere(
        (u) => u != null && (u['uniqueCode'] == qrData || u['kkId'] == qrData),
        orElse: () => null,
      );

      // Jika tidak ditemukan di cache lokal, coba refresh users dari server
      if (userData == null) {
        _cachedUsers = await ApiService.getUsers(widget.villageId);
        userData = _cachedUsers!.cast<Map<String, dynamic>?>().firstWhere(
          (u) =>
              u != null && (u['uniqueCode'] == qrData || u['kkId'] == qrData),
          orElse: () => null,
        );
      }

      if (userData == null) {
        _showScanOverlay('Data Warga tidak ditemukan.', isError: true);
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      String name = userData['name'] ?? 'Tidak diketahui';
      final familyId = userData['familyId']?.toString();
      if (familyId != null && familyId.isNotEmpty) {
        final kkUser = _cachedUsers!.cast<Map<String, dynamic>>().firstWhere(
          (u) =>
              u['familyId']?.toString() == familyId &&
              (u['statusHubungan']?.toString() == 'Kepala Keluarga' ||
                  u['isHeadOfFamily'] == true ||
                  (u['roles'] is List && u['roles'].contains('KK')) ||
                  u['roles'] == 'KK'),
          orElse: () => userData!,
        );
        name = kkUser['name'] ?? name;
      }

      final currentUser = FirebaseAuth.instance.currentUser;

      final String scannerName = await ApiService.getCurrentCitizenName(widget.villageId);

      // 2. Cek double scan HARI INI secara INSTAN dari memori RAM (_todayScans) tanpa menunggu network!
      final todayStart = DateTime(
        _currentTime.year,
        _currentTime.month,
        _currentTime.day,
      );
      final kkId = userData['uniqueCode'] ?? qrData;

      final scannedToday = _todayScans.where((h) {
        if (h['kkId'] != kkId) return false;
        final t = DateTime.tryParse(h['timestamp']?.toString() ?? '');
        return t != null && !t.isBefore(todayStart);
      }).toList();

      if (scannedToday.isNotEmpty) {
        _playTingSound();
        HapticFeedback.heavyImpact();
        await _showDeleteConfirmationDialog(scannedToday.first);
        return;
      }

      // 3. Cek tarif dari cache instan
      final tariffs = _cachedTariffs!;
      final tariffDoc = tariffs.cast<Map<String, dynamic>?>().firstWhere(
        (t) => t != null && t['id'] == '${widget.villageId}_jimpitan',
        orElse: () => null,
      );

      if (tariffDoc == null || tariffDoc['isActive'] != true) {
        _showScanOverlay(
          'Tarif jimpitan belum dikonfigurasi atau tidak aktif.',
          isError: true,
        );
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      final int currentNominal = (tariffDoc['amount'] as num?)?.toInt() ?? 0;
      if (currentNominal <= 0) {
        _showScanOverlay('Nominal tarif tidak valid.', isError: true);
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      // 4. INSTAN AUDIO & NOTIFIKASI (Optimistic UI)
      // Mainkan suara ting kristal dan getaran seketika (0 ms delay)!
      _playTingSound();
      HapticFeedback.heavyImpact();

      // Tampilkan notifikasi sukses seketika di tengah layar!
      _showScanOverlay(
        '$name\nRp ${NumberFormat('#,###', 'id_ID').format(currentNominal)}',
        isError: false,
      );

      // Tambahkan item sementara ke _todayScans secara optimistik agar UI statistik langsung bertambah & anti-double scan
      final now = DateTime.now();
      final optimisticDoc = {
        'id': 'temp_${now.millisecondsSinceEpoch}',
        'kkId': kkId,
        'name': name,
        'amount': currentNominal,
        'scannedBy': currentUser?.uid ?? 'unknown',
        'scannedByName': scannerName,
        'timestamp': now.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(now),
        'type': 'JIMPITAN',
        'villageId': widget.villageId,
      };

      setState(() {
        _todayScans = [optimisticDoc, ..._todayScans];
      });

      // 5. Simpan ke database di background secara Asinkron (tanpa memblokir UI/notifikasi)
      ApiService.createJimpitanHistory(optimisticDoc).then((success) {
        if (!success && mounted) {
          setState(() {
            _todayScans.removeWhere(
              (item) => item['id'] == optimisticDoc['id'],
            );
          });
          CustomToast.show(
            context,
            'Peringatan: Gagal menyimpan $name ke server, coba scan ulang.',
          );
        } else {
          _loadScansSilent();
        }
      });

      // Beri jeda 1.5 detik sebelum siap menyekat kartu berikutnya
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      _showScanOverlay('Terjadi kesalahan sistem.', isError: true);
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showScanOverlay(
    String message, {
    bool isError = false,
    bool isDelete = false,
  }) {
    if (!mounted) return;
    // Hapus overlay sebelumnya jika masih aktif
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _ScanResultOverlay(
        message: message,
        isError: isError,
        isDelete: isDelete,
      ),
    );
    _overlayEntry = entry;
    overlay.insert(entry);

    // Hilangkan otomatis setelah 2.2 detik agar cukup waktu membaca
    _overlayTimer = Timer(const Duration(milliseconds: 2200), () {
      entry.remove();
      if (_overlayEntry == entry) _overlayEntry = null;
    });
  }

  Future<void> _showDeleteConfirmationDialog(dynamic doc) async {
    final data = doc as Map<String, dynamic>;
    final name = data['name'] ?? 'Warga';
    final docId = data['id'].toString();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AppModalDialog(
          title: 'Sudah Discan Hari Ini',
          headerIcon: Icons.warning,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade700, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ATAS NAMA KEPALA KELUARGA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'KK ini sudah memberikan jimpitan hari ini.\nApakah Anda ingin membatalkan/menghapus data jimpitan sebelumnya?',
                style: TextStyle(fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Batal',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ApiService.deleteJimpitanHistory(docId);
                          _showScanOverlay(
                            '$name\nBerhasil dihapus dari riwayat',
                            isDelete: true,
                          );
                          _loadScans();
                          if (context.mounted) {
                            CustomToast.show(
                              context,
                              'Data $name berhasil dihapus',
                            );
                          }
                        } catch (e) {
                          _showScanOverlay(
                            'Gagal menghapus data.',
                            isError: true,
                          );
                        }
                      },
                      child: const Text(
                        'Hapus Data',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetailModal(List<dynamic> docs) {
    showDialog(
      context: context,
      builder: (context) {
        return _RealtimeDetailModalContent(
          villageId: widget.villageId,
          initialDocs: docs,
        );
      },
    );
  }

  String _getRealtimeDate(DateTime dt) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _getRealtimeTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildHeader(BuildContext context) {
    final docs = _todayScans;
    int totalAmount = 0;
    for (var doc in docs) {
      totalAmount +=
          ((doc as Map<String, dynamic>)['amount'] as num?)?.toInt() ?? 0;
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Gradient, Shadow & Lengkungan Bawah
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: topPadding + 10),
              // Top Bar Navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan QR Jimpitan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '${_getRealtimeDate(_currentTime)} • ${_getRealtimeTime(_currentTime)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _showDetailModal(docs),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Kartu Statistik Glassmorphism di dalam Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _isLoadingScans
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Warga terscan
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people_alt_outlined,
                                            color: Colors.white.withValues(alpha: 0.85),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Warga',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${docs.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                // Total terkumpul
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet_outlined,
                                            color: Colors.greenAccent.shade100,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Terkumpul',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Rp ${NumberFormat('#,###', 'id_ID').format(totalAmount)}',
                                        style: TextStyle(
                                          color: Colors.greenAccent.shade100,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Tombol detail
                                IconButton(
                                  onPressed: () => _showDetailModal(docs),
                                  icon: const Icon(Icons.list_alt, color: Colors.white),
                                  tooltip: 'Daftar Hasil Scan',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        // Dekorasi Lingkaran Kanan Atas
        Positioned(
          right: -40,
          top: -30,
          child: IgnorePointer(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        // Dekorasi Lingkaran Kiri Bawah
        Positioned(
          left: -20,
          bottom: 10,
          child: IgnorePointer(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, primaryColor, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF1A1A2E),
            body: Column(
              children: [
                // ── Header Gradasi & Lengkungan Sesuai Tema Halaman Utama ──
                _buildHeader(context),

                // ── Area Kartu Kamera Scanner ──
                Expanded(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      68 + (bottomPadding > 0 ? bottomPadding : 20),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1E2538,
                      ), // Warna kartu kamera slate gelap
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 1. Preview Kamera
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: MobileScanner(
                                    controller: _controller,
                                    onDetect: _processScan,
                                  ),
                                ),

                                // 2. Efek Blur & Gelap di 4 sisi luar kotak scan
                                Positioned.fill(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final width = constraints.maxWidth;
                                      final height = constraints.maxHeight;
                                      final boxSize =
                                          math.min(width, height) * 0.68;
                                      final left = (width - boxSize) / 2;
                                      final top = (height - boxSize) / 2;
                                      final bottom =
                                          height - (top + boxSize);
                                      final right =
                                          width - (left + boxSize);

                                      Widget buildPanel() {
                                        return ClipRect(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 12,
                                              sigmaY: 12,
                                            ),
                                            child: Container(
                                              color: Colors.black.withValues(
                                                alpha: 0.68,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return Stack(
                                        children: [
                                          // Top panel
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            height: top,
                                            child: buildPanel(),
                                          ),
                                          // Bottom panel
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            height: bottom,
                                            child: buildPanel(),
                                          ),
                                          // Left panel
                                          Positioned(
                                            top: top,
                                            bottom: bottom,
                                            left: 0,
                                            width: left,
                                            child: buildPanel(),
                                          ),
                                          // Right panel
                                          Positioned(
                                            top: top,
                                            bottom: bottom,
                                            right: 0,
                                            width: right,
                                            child: buildPanel(),
                                          ),
                                          // Frame sudut kotak di tengah
                                          Positioned(
                                            left: left,
                                            top: top,
                                            width: boxSize,
                                            height: boxSize,
                                            child: CustomPaint(
                                              painter:
                                                  _ScannerBoxCornersPainter(),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                // 3. Tombol Flash di pojok kanan atas preview
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: ValueListenableBuilder<MobileScannerState>(
                                    valueListenable: _controller,
                                    builder: (context, state, child) {
                                      final isFlashOn =
                                          state.torchState == TorchState.on;
                                      return ClipOval(
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1A1A2E),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              isFlashOn
                                                  ? Icons.flash_on
                                                  : Icons.flash_off,
                                              color: isFlashOn
                                                  ? Colors.amberAccent
                                                  : Colors.white70,
                                            ),
                                            iconSize: 22.0,
                                            onPressed: () {
                                              _controller.toggleTorch();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // 4. Loading overlay
                                if (_isProcessing)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // 5. Teks instruksi di bawah area kamera (di dalam card)
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isProcessing
                                  ? Icons.hourglass_top_rounded
                                  : Icons.qr_code_scanner_rounded,
                              size: 18,
                              color: _isProcessing
                                  ? Colors.amberAccent
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isProcessing
                                  ? 'Memproses...'
                                  : 'Scan di sini • Arahkan ke QR Code Warga',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Menggambar 4 sudut batas scan berwarna putih tegas melengkung presisi
class _ScannerBoxCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double len = w * 0.22;
    const double r = 16.0;

    final path = Path();
    // Kiri Atas
    path.moveTo(0, len);
    path.lineTo(0, r);
    path.arcToPoint(
      const Offset(r, 0),
      radius: const Radius.circular(r),
    );
    path.lineTo(len, 0);

    // Kanan Atas
    path.moveTo(w - len, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(
      Offset(w, r),
      radius: const Radius.circular(r),
    );
    path.lineTo(w, len);

    // Kanan Bawah
    path.moveTo(w, h - len);
    path.lineTo(w, h - r);
    path.arcToPoint(
      Offset(w - r, h),
      radius: const Radius.circular(r),
    );
    path.lineTo(w - len, h);

    // Kiri Bawah
    path.moveTo(len, h);
    path.lineTo(r, h);
    path.arcToPoint(
      Offset(0, h - r),
      radius: const Radius.circular(r),
    );
    path.lineTo(0, h - len);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Overlay besar di tengah layar setelah scan berhasil/gagal
class _ScanResultOverlay extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isDelete;

  const _ScanResultOverlay({
    required this.message,
    required this.isError,
    this.isDelete = false,
  });

  @override
  State<_ScanResultOverlay> createState() => _ScanResultOverlayState();
}

class _ScanResultOverlayState extends State<_ScanResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut));
    _opacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeIn));
    _anim.forward();

    // Mulai fade-out 300ms sebelum overlay dihapus
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) _anim.reverse();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.message.split('\n');
    IconData icon;
    Color bgColor;
    String title;

    if (widget.isError) {
      icon = Icons.error_rounded;
      bgColor = const Color(0xFFDC2626); // Merah
      title = 'GAGAL!';
    } else if (widget.isDelete) {
      icon = Icons.delete_forever_rounded;
      bgColor = const Color(0xFFEA580C); // Oranye Tua / Merah Bata
      title = 'DATA DIHAPUS!';
    } else {
      icon = Icons.check_circle_rounded;
      bgColor = const Color(0xFF16A34A); // Hijau
      title = 'SUKSES!';
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) =>
          Opacity(opacity: _opacityAnim.value, child: child),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.86,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.55),
                    blurRadius: 40,
                    spreadRadius: 6,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 84),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.isError &&
                      !widget.isDelete &&
                      lines.length >= 2) ...[
                    // Tampilan Sukses dengan label Atas Nama & Nominal yang jelas dan besar
                    const Text(
                      'ATAS NAMA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lines[0], // Nama warga
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'NOMINAL JIMPITAN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        lines[1], // Rp x.xxx
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ] else if (widget.isDelete && lines.length >= 2) ...[
                    // Tampilan Hapus dengan Atas Nama
                    const Text(
                      'ATAS NAMA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lines[0], // Nama warga
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      lines[1], // Keterangan berhasil dihapus
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    // Tampilan Error / Pesan Biasa
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..color = Colors.transparent;

    final borderPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Latar belakang gelap
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Hitung ukuran kotak tengah
    final double rectSize = size.width * 0.7;
    final double left = (size.width - rectSize) / 2;
    final double top = ((size.height - rectSize) / 2) + 50.0; // Diturunkan 50px
    final RRect rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, rectSize, rectSize),
      const Radius.circular(12),
    );

    // Bolongi bagian tengah
    canvas.drawRRect(rRect, clearPaint);

    // Gambar border siku di tiap ujung
    final double lineLength = rectSize * 0.2;

    // Kiri Atas
    canvas.drawLine(
      Offset(left, top),
      Offset(left + lineLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + lineLength),
      borderPaint,
    );

    // Kanan Atas
    canvas.drawLine(
      Offset(left + rectSize, top),
      Offset(left + rectSize - lineLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + rectSize, top),
      Offset(left + rectSize, top + lineLength),
      borderPaint,
    );

    // Kiri Bawah
    canvas.drawLine(
      Offset(left, top + rectSize),
      Offset(left + lineLength, top + rectSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + rectSize),
      Offset(left, top + rectSize - lineLength),
      borderPaint,
    );

    // Kanan Bawah
    canvas.drawLine(
      Offset(left + rectSize, top + rectSize),
      Offset(left + rectSize - lineLength, top + rectSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + rectSize, top + rectSize),
      Offset(left + rectSize, top + rectSize - lineLength),
      borderPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RealtimeDetailModalContent extends StatefulWidget {
  final String villageId;
  final List<dynamic> initialDocs;
  const _RealtimeDetailModalContent({
    required this.villageId,
    this.initialDocs = const [],
  });

  @override
  State<_RealtimeDetailModalContent> createState() =>
      _RealtimeDetailModalContentState();
}

class _RealtimeDetailModalContentState
    extends State<_RealtimeDetailModalContent> {
  late bool _isLoading;
  late List<dynamic> _docs;
  Map<String, Map<String, dynamic>> _kkPhotos = {};
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    final initialList = List<dynamic>.from(widget.initialDocs);
    initialList.sort((a, b) {
      final dataA = a as Map<String, dynamic>;
      final dataB = b as Map<String, dynamic>;
      DateTime? tA = dataA['timestamp'] != null
          ? DateTime.tryParse(dataA['timestamp'].toString())
          : null;
      DateTime? tB = dataB['timestamp'] != null
          ? DateTime.tryParse(dataB['timestamp'].toString())
          : null;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });
    _docs = initialList;
    _isLoading = _docs.isEmpty;

    _fetchData(silent: true);
    _loadPhotos();

    // Poll data secara realtime setiap 3 detik tanpa berkedip
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    try {
      final users = await ApiService.getUsers(widget.villageId);
      final Map<String, Map<String, dynamic>> photos = {};
      // Pass 1: Temukan foto Kepala Keluarga untuk setiap kkId / noKK
      final Map<String, Map<String, dynamic>> kkPhotoMap = {};

      for (var d in users) {
        final statusHubungan = (d['statusHubungan'] ?? '')
            .toString()
            .toLowerCase();
        if (statusHubungan == 'kepala keluarga') {
          final kkId = d['kkId']?.toString() ?? '';
          final noKk = d['noKK']?.toString() ?? '';
          final photoData = {'foto': d['foto'], 'photoUrl': d['photoUrl']};
          if (kkId.isNotEmpty) kkPhotoMap[kkId] = photoData;
          if (noKk.isNotEmpty) kkPhotoMap[noKk] = photoData;
        }
      }

      // Pass 2: Petakan SEMUA id (uid, code, uniqueCode) milik anggota keluarga ke foto Kepala Keluarganya!
      for (var d in users) {
        final uid = d['uid']?.toString() ?? '';
        final code = d['code']?.toString() ?? '';
        final uniqueCode = d['uniqueCode']?.toString() ?? '';
        final kkId = d['kkId']?.toString() ?? '';
        final noKk = d['noKK']?.toString() ?? '';

        // Ambil foto KK jika ada, jika tidak ada fallback ke foto anggota itu sendiri
        Map<String, dynamic> photoDataToUse = {
          'foto': d['foto'],
          'photoUrl': d['photoUrl'],
        };

        if (kkId.isNotEmpty && kkPhotoMap.containsKey(kkId)) {
          photoDataToUse = kkPhotoMap[kkId]!;
        } else if (noKk.isNotEmpty && kkPhotoMap.containsKey(noKk)) {
          photoDataToUse = kkPhotoMap[noKk]!;
        }

        if (uid.isNotEmpty) photos[uid] = photoDataToUse;
        if (code.isNotEmpty) photos[code] = photoDataToUse;
        if (uniqueCode.isNotEmpty) photos[uniqueCode] = photoDataToUse;
        if (noKk.isNotEmpty) photos[noKk] = photoDataToUse;
        if (kkId.isNotEmpty) photos[kkId] = photoDataToUse;
      }
      if (mounted) {
        setState(() {
          _kkPhotos = photos;
        });
      }
    } catch (e) {
      debugPrint('Error loading photos: $e');
    }
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent && _docs.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final histories = await ApiService.getJimpitanHistory(widget.villageId);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final todayDocs = histories.where((data) {
        DateTime? t;
        if (data['timestamp'] is String) {
          t = DateTime.tryParse(data['timestamp']);
        }
        if (t == null) return false;
        return !t.isBefore(todayStart);
      }).toList();

      todayDocs.sort((a, b) {
        final dataA = a as Map<String, dynamic>;
        final dataB = b as Map<String, dynamic>;
        DateTime? tA = dataA['timestamp'] != null
            ? DateTime.tryParse(dataA['timestamp'].toString())
            : null;
        DateTime? tB = dataB['timestamp'] != null
            ? DateTime.tryParse(dataB['timestamp'].toString())
            : null;
        if (tA == null || tB == null) return 0;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _docs = todayDocs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = 0;
    for (var doc in _docs) {
      final data = doc as Map<String, dynamic>;
      totalAmount += (data['amount'] as num?)?.toInt() ?? 0;
    }

    return AppModalDialog(
      title: 'Realtime Scan Hari Ini',
      headerIcon: Icons.history_toggle_off,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Terkumpul',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(totalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_docs.length} Warga',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _docs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada data scan',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _docs.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final data = _docs[index] as Map<String, dynamic>;
                        final name = data['name'] ?? 'Unknown';
                        final amount = data['amount'] ?? 0;

                        DateTime? timestamp;
                        if (data['timestamp'] != null) {
                          timestamp = DateTime.tryParse(
                            data['timestamp'].toString(),
                          );
                        }

                        final timeString = timestamp != null
                            ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
                            : '-';
                        final petugas = data['scannedByName'] ?? '-';

                        final type = data['type'] ?? 'JIMPITAN';

                        final String kkId = (data['kkId'] ?? '').toString();
                        final String userUid =
                            (data['userUid'] ?? data['uid'] ?? '').toString();
                        final String uniqueCode =
                            (data['uniqueCode'] ?? data['code'] ?? '')
                                .toString();

                        Map<String, dynamic>? photoData;
                        if (kkId.isNotEmpty && _kkPhotos.containsKey(kkId)) {
                          photoData = _kkPhotos[kkId];
                        } else if (userUid.isNotEmpty &&
                            _kkPhotos.containsKey(userUid)) {
                          photoData = _kkPhotos[userUid];
                        } else if (uniqueCode.isNotEmpty &&
                            _kkPhotos.containsKey(uniqueCode)) {
                          photoData = _kkPhotos[uniqueCode];
                        }

                        final Map<String, dynamic> combinedData = Map.from(
                          data,
                        );
                        if (photoData != null) {
                          combinedData['foto'] = photoData['foto'];
                          combinedData['photoUrl'] = photoData['photoUrl'];
                        }

                        Color iconColor;
                        String subtitlePrefix;

                        if (type == 'TAGIHAN') {
                          iconColor = Colors.blue;
                          subtitlePrefix = 'Pembayaran Tagihan';
                        } else if (type == 'MANUAL') {
                          iconColor = Colors.orange;
                          subtitlePrefix = 'Input Manual';
                        } else {
                          iconColor = Colors.green;
                          subtitlePrefix = 'Discan oleh: $petugas';
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              UserAvatar(userData: combinedData, radius: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeString,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.person_outline,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            subtitlePrefix,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Rp $amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: iconColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _fetchData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
