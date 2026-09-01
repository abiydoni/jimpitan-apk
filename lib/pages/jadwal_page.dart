
import 'package:jimpitan/utils/resident_pdf_export.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:math' as math;
import 'package:jimpitan/main.dart'; // import routeObserver
import 'package:jimpitan/utils/custom_toast.dart';

class JadwalPage extends StatefulWidget {
  final String villageId;
  final Map<String, bool>? permissions;

  const JadwalPage({super.key, required this.villageId, this.permissions});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> with RouteAware {
  bool get _canEdit => widget.permissions == null || widget.permissions!['edit'] == true;

  String _searchQuery = '';
  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  late Future<List<dynamic>> _usersFuture;
  late Future<List<dynamic>> _schedulesFuture;

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
      _usersFuture = ApiService.getUsers(widget.villageId).then((users) => 
          users.where((u) => u['status'] == 'ACTIVE').toList());
      _schedulesFuture = ApiService.getSchedules(widget.villageId);
    });
  }

  Future<void> _shareSchedulePdf() async {
    try {
      final usersSnap = await ApiService.getUsers(widget.villageId);
      final activeUsers = usersSnap.where((u) => u['status'] == 'ACTIVE').toList();

      final schedulesSnap = await ApiService.getSchedules(widget.villageId);

      final scheduleMap = <String, String>{};
      for (final data in schedulesSnap) {
        final nik = (data['nik'] ?? '').toString();
        final hari = (data['hari'] ?? '').toString();
        if (nik.isNotEmpty && hari.isNotEmpty) {
          scheduleMap[nik] = hari;
        }
      }

      final Map<String, List<String>> groupedSchedules = {
        'Senin': [],
        'Selasa': [],
        'Rabu': [],
        'Kamis': [],
        'Jumat': [],
        'Sabtu': [],
        'Minggu': [],
      };

      final users = activeUsers; // Include all active users, even without NIK

      for (final data in users) {
        final nik = (data['nik'] ?? '').toString();
        final name = (data['name'] ?? 'Tanpa Nama').toString();
        if (nik.isNotEmpty && scheduleMap.containsKey(nik)) {
          final day = scheduleMap[nik]!;
          if (groupedSchedules.containsKey(day)) {
            groupedSchedules[day]!.add(name);
          }
        }
      }

      // Urutkan nama per hari
      for (final day in groupedSchedules.keys) {
        groupedSchedules[day]!.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }

      final fileName =
          'Jadwal_Jaga_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf';
      await shareSchedulePdf(
        title: 'Jadwal Jaga Warga',
        subtitle: 'Daftar pembagian jadwal jaga warga desa',
        fileName: fileName,
        groupedSchedules: groupedSchedules,
      );

      if (mounted) {
        CustomToast.show(context, 'PDF jadwal berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat PDF jadwal: $e')));
      }
    }
  }

  Future<void> _updateSchedule(String nik, String name, String? hari) async {
    EasyLoading.show(status: 'Menyimpan jadwal...');
    try {
      final success = await ApiService.updateSchedule(widget.villageId, nik, name, hari);
      if (success) {
        _loadData();
      }
                              if (mounted) CustomToast.show(context, 'Data berhasil disimpan');
    } catch (e) {
      EasyLoading.showError('Gagal menyimpan jadwal');
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _showEditBottomSheet(String nik, String name, String? currentHari) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Ubah Jadwal: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                title: const Text('Kosongkan Jadwal', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _updateSchedule(nik, name, null);
                },
              ),
              ..._days.map((day) => ListTile(
                leading: Icon(Icons.calendar_today, color: currentHari == day ? Colors.blue : null),
                title: Text(day, style: TextStyle(fontWeight: currentHari == day ? FontWeight.bold : FontWeight.normal)),
                trailing: currentHari == day ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _updateSchedule(nik, name, day);
                },
              )),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDayCard(String day, List<dynamic> dayUsers, Color headerColor, IconData icon, {bool isFullWidth = false}) {
    Widget listViewWidget = dayUsers.isEmpty
        ? const Center(child: Text('-', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            shrinkWrap: true,
            physics: isFullWidth ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            itemCount: dayUsers.length,
            itemBuilder: (context, index) {
              final data = dayUsers[index];
              final nik = data['nik']?.toString() ?? '';
              final name = data['name']?.toString() ?? 'Tanpa Nama';
              return InkWell(
                onTap: _canEdit ? () => _showEditBottomSheet(nik, name, day == 'Belum Ada Jadwal' ? null : day) : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    children: [
                      Text('${index + 1}.', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    day.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isFullWidth)
            listViewWidget
          else
            Expanded(child: listViewWidget),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Jaga Warga'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareSchedulePdf,
            tooltip: 'Bagikan PDF Jadwal',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari NIK atau Nama...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _schedulesFuture,
              builder: (context, scheduleSnapshot) {
                if (!scheduleSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Map of nik -> schedule day
                Map<String, String> scheduleMap = {};
                for (var data in scheduleSnapshot.data!) {
                  if (data['nik'] != null && data['hari'] != null) {
                    scheduleMap[data['nik']] = data['hari'];
                  }
                }

                return FutureBuilder<List<dynamic>>(
                  future: _usersFuture,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var users = userSnapshot.data!;

                    // Filter based on search query
                    if (_searchQuery.isNotEmpty) {
                      users = users.where((data) {
                        final name = (data['name'] ?? '')
                            .toString()
                            .toLowerCase();
                        final nik = (data['nik'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_searchQuery) ||
                            nik.contains(_searchQuery);
                      }).toList();
                    }

                    // Sort by name
                    users.sort((a, b) {
                      final nameA = a['name']?.toString() ?? '';
                      final nameB = b['name']?.toString() ?? '';
                      return nameA.compareTo(nameB);
                    });

                    if (users.isEmpty) {
                      return const Center(
                        child: Text('Tidak ada warga ditemukan.'),
                      );
                    }

                    Map<String, List<dynamic>> groupedUsers = {
                      'Senin': [],
                      'Selasa': [],
                      'Rabu': [],
                      'Kamis': [],
                      'Jumat': [],
                      'Sabtu': [],
                      'Minggu': [],
                      'Belum Ada Jadwal': [],
                    };

                    for (var data in users) {
                      final nik = data['nik']?.toString() ?? '';
                      if (nik.isEmpty) continue;

                      final currentHari = scheduleMap[nik];
                      if (currentHari != null &&
                          groupedUsers.containsKey(currentHari)) {
                        groupedUsers[currentHari]!.add(data);
                      } else {
                        groupedUsers['Belum Ada Jadwal']!.add(data);
                      }
                    }

                    Map<String, Color> dayColors = {
                      'Senin': Colors.blue.shade100,
                      'Selasa': Colors.green.shade100,
                      'Rabu': Colors.orange.shade100,
                      'Kamis': Colors.purple.shade100,
                      'Jumat': Colors.pink.shade100,
                      'Sabtu': Colors.teal.shade100,
                      'Minggu': Colors.red.shade100,
                    };

                    Map<String, IconData> dayIcons = {
                      'Senin': Icons.work_outline,
                      'Selasa': Icons.directions_run,
                      'Rabu': Icons.group_outlined,
                      'Kamis': Icons.nature_people_outlined,
                      'Jumat': Icons.favorite_border,
                      'Sabtu': Icons.sports_esports_outlined,
                      'Minggu': Icons.weekend_outlined,
                      'Belum Ada Jadwal': Icons.help_outline,
                    };

                    List<dynamic> unscheduledUsers = groupedUsers['Belum Ada Jadwal'] ?? [];

                    // Hitung jumlah warga terbanyak dalam satu hari (Senin-Minggu)
                    int maxUsersInDay = 0;
                    for (String day in _days) {
                      int count = (groupedUsers[day] ?? []).length;
                      if (count > maxUsersInDay) {
                        maxUsersInDay = count;
                      }
                    }
                    
                    // Kalkulasi tinggi dinamis: Header(~40) + ListView Padding(~16) + (tiap item ~30)
                    // Ditambah sedikit buffer. Batasi maksimal tinggi setara 6 orang agar tidak terlalu panjang (bisa scroll).
                    int effectiveMax = math.min(maxUsersInDay == 0 ? 1 : maxUsersInDay, 6);
                    double dynamicHeight = 60.0 + (effectiveMax * 30.0);

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: dynamicHeight,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              String day = _days[index];
                              List<dynamic> dayUsers = groupedUsers[day] ?? [];
                              return _buildDayCard(day, dayUsers, dayColors[day]!, dayIcons[day]!);
                            },
                            childCount: _days.length,
                          ),
                        ),
                        if (unscheduledUsers.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _buildDayCard(
                                'Belum Ada Jadwal',
                                unscheduledUsers,
                                Colors.grey.shade200,
                                dayIcons['Belum Ada Jadwal']!,
                                isFullWidth: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
