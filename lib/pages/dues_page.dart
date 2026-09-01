import 'package:flutter/material.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'dues_kk_list_page.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/main.dart'; // import routeObserver

class DuesPage extends StatefulWidget {
  final String villageId;
  final List<String> currentUserRoles;
  final Map<String, bool>? permissions;

  const DuesPage({
    super.key,
    required this.villageId,
    required this.currentUserRoles,
    this.permissions,
  });

  @override
  State<DuesPage> createState() => _DuesPageState();
}

class _DuesPageState extends State<DuesPage> with RouteAware {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final tariffs = await ApiService.getTariffs(widget.villageId);
    final village = await ApiService.getVillage(widget.villageId);
    final tariffPermissions = village?['config']?['tariffPermissions'] as Map<String, dynamic>? ?? {};
    return {
      'tariffs': tariffs,
      'tariffPermissions': tariffPermissions,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Rekapitulasi Iuran'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan memuat data.'));
          }

          final rawTariffs = (snapshot.data?['tariffs'] as List<dynamic>?) ?? [];
          final tariffPermissions = (snapshot.data?['tariffPermissions'] as Map<String, dynamic>?) ?? {};
          
          final isGodMode = widget.currentUserRoles.contains('SUPER_ADMIN') || widget.currentUserRoles.contains('ADMIN_DESA');

          final tariffs = rawTariffs.where((t) {
            if (t['isActive'] != true) return false;
            if (isGodMode) return true;
            
            final tId = t['id'].toString();
            final permsForTariff = tariffPermissions[tId] as Map<String, dynamic>? ?? {};
            
            // Check if user has permission
            for (var role in widget.currentUserRoles) {
              // Jika role tidak ada di map permsForTariff, berarti defaultnya true
              if (!permsForTariff.containsKey(role) || permsForTariff[role] == true) {
                return true;
              }
            }
            return false;
          }).toList();

          if (tariffs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada jenis iuran yang ditambahkan.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          
          if (tariffs.length == 1) {
            final data = Map<String, dynamic>.from(tariffs.first as Map? ?? {});
            final docId = data['id']?.toString() ?? '';
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DuesKkListPage(
                    villageId: widget.villageId,
                    tariffId: docId,
                    tariffData: data,
                    currentUserRoles: widget.currentUserRoles,
                    permissions: widget.permissions,
                  ),
                ),
              );
            });
            
            return const Center(child: CircularProgressIndicator());
          }

          final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tariffs.length,
            itemBuilder: (context, index) {
              final data = Map<String, dynamic>.from(tariffs[index] as Map? ?? {});
              final docId = data['id']?.toString() ?? '';
              final name = data['name'] ?? 'Iuran Tanpa Nama';
              final amount = data['amount'] ?? 0;
              final type = data['type'] ?? 'Bulanan';
              
              IconData icon = Icons.receipt_long;
              if (type == 'Bulanan') icon = Icons.calendar_month;
              if (type == 'Tahunan') icon = Icons.event_note;
              if (type == 'Sekali Bayar') icon = Icons.looks_one;
              if (type == 'Harian' || type == 'Jimpitan') icon = Icons.nightlight_round;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DuesKkListPage(
                            villageId: widget.villageId,
                            tariffId: docId,
                            tariffData: data,
                            currentUserRoles: widget.currentUserRoles,
                            permissions: widget.permissions,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: AppTheme.primaryColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currencyFormat.format(amount),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
