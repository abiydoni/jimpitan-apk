import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/utils/app_theme.dart';
import '../widgets/user_avatar.dart';

class ScanRankingPage extends StatefulWidget {
  final String villageId;

  const ScanRankingPage({super.key, required this.villageId});

  @override
  State<ScanRankingPage> createState() => _ScanRankingPageState();
}

class _ScanRankingPageState extends State<ScanRankingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _historyFuture;

  // Filter bulan & tahun
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<int> _years = List.generate(
    5,
    (i) => DateTime.now().year - i,
  );

  static const List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  Map<String, Map<String, dynamic>> _kkPhotos = {};

  @override
  void initState() {
    super.initState();
    _historyFuture = ApiService.getJimpitanHistory(widget.villageId);
    _loadPhotos();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
        children: [
          // Header gradient dengan SafeArea
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // AppBar row
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, right: 16, top: 4, bottom: 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Ranking Scan Terbanyak',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  // Ikon dan subtitle
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.leaderboard,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Statistik kerajinan petugas scan jimpitan',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // TabBar di dalam gradient
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Bulanan'),
                      Tab(text: 'Tahunan'),
                      Tab(text: 'Semua'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // TabBarView mengisi sisa layar
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRankingView('month'),
                _buildRankingView('year'),
                _buildRankingView('all'),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildRankingView(String period) {
    return Column(
      children: [
        // Period selector
        if (period == 'month')
          _buildMonthYearSelector()
        else if (period == 'year')
          _buildYearSelector(),

        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data ?? [];

              // Filter berdasarkan periode
              final filtered = docs.where((doc) {
                final data = doc as Map<String, dynamic>;
                
                DateTime? ts;
                if (data['timestamp'] is String) ts = DateTime.tryParse(data['timestamp']);
                
                if (ts == null) return false;
                final dt = ts;
                if (period == 'month') {
                  return dt.year == _selectedYear &&
                      dt.month == _selectedMonth;
                } else if (period == 'year') {
                  return dt.year == _selectedYear;
                }
                return true; // 'all'
              }).toList();

              // Rekap per petugas - hanya scan QR (type JIMPITAN)
              final Map<String, Map<String, dynamic>> rankMap = {};
              for (final doc in filtered) {
                final data = doc as Map<String, dynamic>;
                final type = data['type']?.toString().toUpperCase() ?? '';
                if (type != 'JIMPITAN') {
                  continue; // Hanya hitung yang dari scan QR
                }

                final uid = data['scannedBy'] as String? ?? 'unknown';
                final name = data['scannedByName'] as String? ?? 'Petugas';
                final amount =
                    (data['amount'] as num?)?.toInt() ?? 0;
                if (rankMap.containsKey(uid)) {
                  rankMap[uid]!['count'] = rankMap[uid]!['count'] + 1;
                  rankMap[uid]!['total'] = rankMap[uid]!['total'] + amount;
                } else {
                  rankMap[uid] = {
                    'uid': uid,
                    'name': name,
                    'count': 1,
                    'total': amount,
                  };
                  if (_kkPhotos.containsKey(uid)) {
                    rankMap[uid]!['foto'] = _kkPhotos[uid]!['foto'];
                    rankMap[uid]!['photoUrl'] = _kkPhotos[uid]!['photoUrl'];
                  }
                }
              }

              final ranking = rankMap.values.toList()
                ..sort(
                    (a, b) => (b['count'] as int).compareTo(a['count'] as int));

              // Jika tidak ada transaksi scan QR sama sekali, tampilkan empty state
              if (ranking.isEmpty) {
                return _buildEmptyState(period);
              }

              final currencyFormat = NumberFormat.currency(
                  locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

              final top3 = ranking.take(3).toList();
              final rest = ranking.skip(3).toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: rest.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildPodium(top3);
                  }

                  final item = rest[index - 1];
                  final rank = index + 3;

                  return _buildRankCard(
                    rank: rank,
                    userData: item,
                    scanCount: item['count'] as int,
                    totalAmount: item['total'] as int,
                    currencyFormat: currencyFormat,
                    isTop3: false,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthYearSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Bulan
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (i) {
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(_monthNames[i],
                          style: const TextStyle(fontSize: 13)),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMonth = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tahun
          Expanded(
            flex: 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  isExpanded: true,
                  items: _years.map((y) {
                    return DropdownMenuItem(
                        value: y,
                        child: Text(y.toString(),
                            style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedYear = v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('Tahun:',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _years.map((y) {
                  final selected = y == _selectedYear;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedYear = y),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        y.toString(),
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard({
    required int rank,
    required Map<String, dynamic> userData,
    required int scanCount,
    required int totalAmount,
    required NumberFormat currencyFormat,
    required bool isTop3,
  }) {
    final medalColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    final medalIcons = ['🥇', '🥈', '🥉'];

    Color cardBg = Colors.white;
    if (rank == 1) cardBg = const Color(0xFFFFFDE7);
    if (rank == 2) cardBg = const Color(0xFFF5F5F5);
    if (rank == 3) cardBg = const Color(0xFFFFF3E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: isTop3
            ? Border.all(color: medalColors[rank - 1].withValues(alpha: 0.4))
            : Border.all(color: Colors.grey.shade200),
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: medalColors[rank - 1].withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 44,
              child: isTop3
                  ? Text(
                      medalIcons[rank - 1],
                      style: const TextStyle(fontSize: 28),
                      textAlign: TextAlign.center,
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              userData: userData,
              radius: 20,
            ),
            const SizedBox(width: 12),
            // Nama & total
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData['name']?.toString() ?? 'Tanpa Nama',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Jumlah scan
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  scanCount.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: isTop3 && rank == 1
                        ? Colors.amber.shade700
                        : AppTheme.primaryColor,
                  ),
                ),
                const Text(
                  'scan',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3) {
    if (top3.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (top3.length > 1) _buildPodiumColumn(top3[1], 2, 120, Colors.grey.shade400, Colors.grey.shade600),
          _buildPodiumColumn(top3[0], 1, 160, Colors.amber, Colors.orange.shade700),
          if (top3.length > 2) _buildPodiumColumn(top3[2], 3, 90, Colors.brown.shade300, Colors.brown.shade600),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(Map<String, dynamic> data, int rank, double height, Color primaryColor, Color shadowColor) {
    String initials = data['name'].toString().trim();
    initials = initials.isNotEmpty ? initials.substring(0, 1).toUpperCase() : '?';

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          UserAvatar(
            userData: data,
            radius: rank == 1 ? 28 : 22,
          ),
          const SizedBox(height: 8),
          Text(
            data['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: rank == 1 ? FontWeight.w900 : FontWeight.bold,
              fontSize: rank == 1 ? 14 : 12,
            ),
          ),
          Text(
            '${data['count']} Scan',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: height),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Container(
                      height: value,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor.withValues(alpha: 0.8), primaryColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        )
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String period) {
    String label = period == 'month'
        ? '${_monthNames[_selectedMonth - 1]} $_selectedYear'
        : period == 'year'
            ? 'tahun $_selectedYear'
            : 'semua waktu';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada data scan\npada periode $label.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
