import 'package:flutter/material.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'unscanned_residents_page.dart';
import 'scan_ranking_page.dart';

class ReportsPage extends StatefulWidget {
  final String villageId;
  final Map<String, dynamic>? permissions;
  final List<dynamic>? currentUserRoles;

  const ReportsPage({
    super.key,
    required this.villageId,
    this.permissions,
    this.currentUserRoles,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final List<Map<String, dynamic>> _reportOptions;

  @override
  void initState() {
    super.initState();
    _reportOptions = [
      {
        'title': 'Warga Belum Scan',
        'icon': Icons.person_off_outlined,
        'color': Colors.orange,
        'gradient': [Colors.orange.shade400, Colors.deepOrange.shade400],
        'description': 'Daftar warga yang belum ditarik jimpitan hari ini',
        'onTap': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => UnscannedResidentsPage(
                    villageId: widget.villageId,
                    permissions: widget.permissions,
                    currentUserRoles: widget.currentUserRoles,
                  ),
            ),
          );
        },
      },
      {
        'title': 'Ranking Petugas',
        'icon': Icons.leaderboard_outlined,
        'color': AppTheme.primaryColor,
        'gradient': [AppTheme.primaryColor, AppTheme.secondaryColor],
        'description': 'Statistik kerajinan petugas scan jimpitan',
        'onTap': (BuildContext ctx) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) =>
                  ScanRankingPage(villageId: widget.villageId),
            ),
          );
        },
      },

    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Jenis Laporan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pilih laporan yang ingin Anda lihat di bawah ini.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final report = _reportOptions[index];
                  return _buildReportCard(
                    title: report['title'],
                    icon: report['icon'],
                    gradient: report['gradient'],
                    onTap: () => report['onTap'](context),
                  );
                },
                childCount: _reportOptions.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF1E293B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
