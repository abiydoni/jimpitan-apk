import 'dart:async';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/user_avatar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/main.dart'; // import routeObserver

class ScanReportPage extends StatefulWidget {
  final String villageId;
  const ScanReportPage({super.key, required this.villageId});

  @override
  State<ScanReportPage> createState() => _ScanReportPageState();
}

class _ScanReportPageState extends State<ScanReportPage> with RouteAware {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _historyList = [];
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  Map<String, Map<String, dynamic>> _kkPhotos = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _loadPhotos();
    // Polling secara background tiap 3 detik untuk realtime tanpa me-refresh UI secara kasar
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchDataSilent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _fetchDataSilent();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getJimpitanHistory(widget.villageId);
      if (mounted) {
        setState(() {
          _historyList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final users = await ApiService.getUsers(widget.villageId);
      final Map<String, Map<String, dynamic>> photos = {};
      // Pass 1: Temukan foto Kepala Keluarga untuk setiap kkId / noKK
      final Map<String, Map<String, dynamic>> kkPhotoMap = {};
      
      for (var d in users) {
        final statusHubungan = (d['statusHubungan'] ?? '').toString().toLowerCase();
        if (statusHubungan == 'kepala keluarga') {
          final kkId = d['kkId']?.toString() ?? '';
          final noKk = d['noKK']?.toString() ?? '';
          final photoData = {
            'foto': d['foto'],
            'photoUrl': d['photoUrl'],
          };
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

  Future<void> _fetchDataSilent() async {
    try {
      final data = await ApiService.getJimpitanHistory(widget.villageId);
      if (mounted) {
        setState(() {
          _historyList = data;
        });
      }
    } catch (e) {
      // Abaikan error pada silent update agar tidak mengganggu UI pengguna
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchInitialData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 2),
          Text(
            value, 
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
          ),
          Text(
            label, 
            style: const TextStyle(color: Colors.white70, fontSize: 9)
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
    DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Scan Jimpitan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Muat Ulang',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDate(context),
            tooltip: 'Pilih Tanggal',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading && _historyList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _historyList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Terjadi kesalahan: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleRefresh,
                    child: const Text('Coba Lagi'),
                  )
                ],
              ),
            );
          }


          // Local filtering and sorting to avoid composite index requirement
          final allDocs = _historyList;
          final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

          final filteredDocs = allDocs.where((data) {
            if (data['date'] != null && data['date'].toString().isNotEmpty) {
              return data['date'].toString().startsWith(selectedDateStr);
            }

            DateTime? dt;
            if (data['timestamp'] is String) dt = DateTime.tryParse(data['timestamp']);
            if (dt == null) return false;
            return dt.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   dt.isBefore(endDate.add(const Duration(seconds: 1)));
          }).toList();

          filteredDocs.sort((a, b) {
            DateTime? tsA;
            if (a['timestamp'] is String) tsA = DateTime.tryParse(a['timestamp']);
            DateTime? tsB;
            if (b['timestamp'] is String) tsB = DateTime.tryParse(b['timestamp']);
            
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA); // descending
          });

          // Hitung Total Saldo dan Statistik
          int totalAmount = 0;
          int totalScan = 0;
          int totalTagihan = 0;
          int totalManual = 0;

          for (var data in filteredDocs) {
            totalAmount += (data['amount'] as num?)?.toInt() ?? 0;
            if (data['type'] == 'TAGIHAN') {
              totalTagihan++;
            } else if (data['type'] == 'MANUAL') {
              totalManual++;
            } else {
              totalScan++;
            }
          }
          int totalWarga = filteredDocs.length;

          final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppTheme.primaryColor,
            child: Column(
              children: [
                // Summary Header
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
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
                        child: Column(
                          children: [
                            const Text(
                              'Total Terkumpul',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currencyFormat.format(totalAmount),
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 24, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 12),
                              child: Text(
                                DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_selectedDate),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(child: _buildStatItem(Icons.people, '$totalWarga', 'Total Warga')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildStatItem(Icons.qr_code_scanner, '$totalScan', 'Via Scan')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildStatItem(Icons.event_available, '$totalTagihan', 'Via Tagihan')),
                                const SizedBox(width: 4),
                                Expanded(child: _buildStatItem(Icons.edit_note, '$totalManual', 'Via Manual')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Dekorasi lingkaran 1
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      // Dekorasi lingkaran 2
                      Positioned(
                        bottom: -30,
                        left: -30,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // List Transaksi
                Expanded(
                  child: filteredDocs.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          const Center(child: Text('Tidak ada data scan pada tanggal ini.')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index] as Map<String, dynamic>;
                          final String name = data['name'] ?? 'Anonim';
                          final int amount = (data['amount'] as num?)?.toInt() ?? 0;
                          
                          String timeString = '';
                          if (data['timestamp'] != null) {
                            DateTime? ts = DateTime.tryParse(data['timestamp']);
                            if (ts != null) {
                              timeString = DateFormat('HH:mm').format(ts);
                            }
                          }

                          // Ambil foto dari _kkPhotos
                          final String kkId = (data['kkId'] ?? '').toString();
                          final String userUid = (data['userUid'] ?? data['uid'] ?? '').toString();
                          final String uniqueCode = (data['uniqueCode'] ?? data['code'] ?? '').toString();
                          
                          Map<String, dynamic>? photoData;
                          if (kkId.isNotEmpty && _kkPhotos.containsKey(kkId)) {
                            photoData = _kkPhotos[kkId];
                          } else if (userUid.isNotEmpty && _kkPhotos.containsKey(userUid)) {
                            photoData = _kkPhotos[userUid];
                          } else if (uniqueCode.isNotEmpty && _kkPhotos.containsKey(uniqueCode)) {
                            photoData = _kkPhotos[uniqueCode];
                          }

                          final Map<String, dynamic> combinedData = Map.from(data);
                          if (photoData != null) {
                            combinedData['foto'] = photoData['foto'];
                            combinedData['photoUrl'] = photoData['photoUrl'];
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                    UserAvatar(
                                      userData: combinedData,
                                      radius: 18,
                                    ),
                                  ],
                                ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                data['type'] == 'TAGIHAN' 
                                    ? 'Pembayaran Tagihan • $timeString'
                                    : data['type'] == 'MANUAL'
                                        ? 'Input Manual • $timeString'
                                        : 'Discan oleh: ${data['scannedByName'] ?? 'Petugas'} • $timeString',
                                style: const TextStyle(fontSize: 12, height: 1.2),
                              ),
                              trailing: Text(
                                currencyFormat.format(amount),
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              isThreeLine: false,
                            ),
                          ),
                        );
                      },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
