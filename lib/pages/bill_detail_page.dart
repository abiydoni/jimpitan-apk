import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../utils/resident_pdf_export.dart';
import '../utils/api_service.dart';
import 'package:intl/intl.dart';
import 'package:jimpitan/main.dart'; // import routeObserver
import 'package:jimpitan/utils/custom_toast.dart';

class BillDetailPage extends StatefulWidget {
  final String familyId;
  final String villageId;
  final DateTime startDate;
  final Map<String, dynamic>? userData;

  const BillDetailPage({
    super.key,
    required this.familyId,
    required this.villageId,
    required this.startDate,
    this.userData,
  });

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> with RouteAware {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tariffs = [];
  final Map<String, int> _payments = {};
  final Map<String, List<Map<String, dynamic>>> _paymentHistory = {};
  Set<String> _exemptedTariffIds = {};
  List<Map<String, dynamic>> _myExemptions = [];
  Map<String, dynamic>? _freshUserData;
  DateTime? _freshVillageStartDate;

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
    _loadData(showLoading: false);
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      _payments.clear();
      _paymentHistory.clear();
      _exemptedTariffIds.clear();
      _myExemptions.clear();

      // 1. Fetch active tariffs
      final allTariffs = await ApiService.getTariffs(widget.villageId);
      _tariffs = List<Map<String, dynamic>>.from(allTariffs.where((t) => t['isActive'] == true));

      final allVillages = await ApiService.getVillages();
      final myVillage = allVillages.firstWhere((v) => v['id'] == widget.villageId, orElse: () => {});
      final config = myVillage['config'] as Map<String, dynamic>? ?? {};
      if (config['startDate'] != null) {
        final sDate = config['startDate'];
        if (sDate is String) {
          _freshVillageStartDate = DateTime.tryParse(sDate)?.toLocal();
        } else if (sDate is int) {
          _freshVillageStartDate = DateTime.fromMillisecondsSinceEpoch(sDate);
        }
      }

      final allUsers = await ApiService.getUsers(widget.villageId);
      _freshUserData = allUsers.firstWhere(
        (u) => (u['uid']?.toString() == widget.userData?['uid']?.toString()) || 
               (u['familyId']?.toString() == widget.familyId),
        orElse: () => widget.userData ?? {},
      );

      // 2. Fetch active exemptions for this family
      final now = DateTime.now();

      String code = widget.familyId;
      String noKk = widget.familyId;
      final currentUserData = _freshUserData ?? widget.userData;
      if (currentUserData != null) {
        code = currentUserData['uniqueCode']?.toString() ?? currentUserData['code']?.toString() ?? widget.familyId;
        noKk = currentUserData['noKK']?.toString() ?? widget.familyId;
      }

      final uid = currentUserData?['uid']?.toString() ?? '';

      final allExemptions = await ApiService.getExemptions(widget.villageId);

      final Set<String> exempted = {};
      final List<Map<String, dynamic>> myExs = [];
      for (var exData in allExemptions) {
        final exKkId = exData['kkId']?.toString() ?? '';

        if (exKkId == widget.familyId || exKkId == code || exKkId == noKk || (uid.isNotEmpty && exKkId == uid)) {
          myExs.add(exData);
          DateTime? startTs = _parseDate(exData['startDate']);
          DateTime? endTs = _parseDate(exData['endDate']);
          
          if (startTs == null) {
            continue;
          }
          if (startTs.compareTo(now) > 0) {
            continue;
          } // belum mulai
          if (endTs != null && endTs.compareTo(now) < 0) {
            continue;
          } // sudah berakhir
          exempted.add(exData['tariffId']?.toString() ?? '');
        }
      }
      _exemptedTariffIds = exempted;
      _myExemptions = myExs;

      // 3. Fetch payment history dari dues_journals (iuran bulanan/tahunan/dll)
      final allJournals = await ApiService.getDuesJournals(widget.villageId);
      final myJournals = allJournals.where((d) {
        final k = d['kkId']?.toString() ?? '';
        return k == widget.familyId || k == code || k == noKk || (uid.isNotEmpty && k == uid);
      }).toList();

      // Aggregate payments by tariffId
      for (var data in myJournals) {
        final tariffId = data['tariffId']?.toString() ?? '';
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        if (tariffId.isEmpty) continue;
        _payments[tariffId] = (_payments[tariffId] ?? 0) + amount;
        if (_paymentHistory[tariffId] == null) _paymentHistory[tariffId] = [];
        _paymentHistory[tariffId]!.add(data);
      }

      // 4. Juga baca jimpitan_history untuk tarif harian scan QR
      final allHistory = await ApiService.getJimpitanHistory(widget.villageId);
      final myHistory = allHistory.where((d) {
        final k = d['kkId']?.toString() ?? '';
        return k == widget.familyId || k == code || k == noKk || (uid.isNotEmpty && k == uid);
      }).toList();

      for (var data in myHistory) {
        if (data['villageId'] != widget.villageId) {
          continue;
        }
        
        // Pembayaran tipe TAGIHAN sudah dicatat di dues_journals, jadi jangan dihitung ganda
        final type = data['type']?.toString();
        if (type == 'TAGIHAN') {
          continue;
        }

        // Cari tariff yang bertipe Harian untuk desa ini
        for (var tariff in _tariffs) {
          final tType = tariff['type']?.toString() ?? '';
          if (tType == 'Harian') {
            final tariffId = tariff['id']?.toString() ?? '';
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            _payments[tariffId] = (_payments[tariffId] ?? 0) + amount;
            if (_paymentHistory[tariffId] == null) {
              _paymentHistory[tariffId] = [];
            }
            _paymentHistory[tariffId]!.add(data);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading bill details: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime _getEffectiveStartDate(Map<String, dynamic> tariff) {
    DateTime effective = _freshVillageStartDate ?? widget.startDate;

    final currentUserData = _freshUserData ?? widget.userData;
    if (currentUserData != null && currentUserData['createdAt'] != null) {
      final uCreated = currentUserData['createdAt'];
      DateTime? uDate;
      if (uCreated is String) {
        uDate = DateTime.tryParse(uCreated)?.toLocal();
      } else if (uCreated is int) {
        uDate = DateTime.fromMillisecondsSinceEpoch(uCreated);
      }

      if (uDate != null && uDate.isAfter(effective)) {
        effective = uDate;
      }
    }

    if (tariff['createdAt'] != null) {
      final tCreated = tariff['createdAt'];
      DateTime? tDate;
      if (tCreated is String) {
        tDate = DateTime.tryParse(tCreated)?.toLocal();
      } else if (tCreated is int) {
        tDate = DateTime.fromMillisecondsSinceEpoch(tCreated);
      }
      if (tDate != null && tDate.isAfter(effective)) {
        effective = tDate;
      }
    }
    return effective;
  }

  /// Returns effective start date AND its source label
  (DateTime, String) _getEffectiveDateWithSource(Map<String, dynamic> tariff) {
    DateTime effective = _freshVillageStartDate ?? widget.startDate;
    String source = 'Registrasi Desa';

    final currentUserData = _freshUserData ?? widget.userData;
    if (currentUserData != null && currentUserData['createdAt'] != null) {
      final uCreated = currentUserData['createdAt'];
      DateTime? uDate;
      if (uCreated is String) {
        uDate = DateTime.tryParse(uCreated)?.toLocal();
      } else if (uCreated is int) {
        uDate = DateTime.fromMillisecondsSinceEpoch(uCreated);
      }
      if (uDate != null && uDate.isAfter(effective)) {
        effective = uDate;
        source = 'Registrasi Warga';
      }
    }

    if (tariff['createdAt'] != null) {
      final tCreated = tariff['createdAt'];
      DateTime? tDate;
      if (tCreated is String) {
        tDate = DateTime.tryParse(tCreated)?.toLocal();
      } else if (tCreated is int) {
        tDate = DateTime.fromMillisecondsSinceEpoch(tCreated);
      }
      if (tDate != null && tDate.isAfter(effective)) {
        effective = tDate;
        source = 'Registrasi Tarif';
      }
    }
    return (effective, source);
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String && val.isNotEmpty) return DateTime.tryParse(val)?.toLocal();
    return null;
  }

  int _calculateExpectedTotal(
    String type,
    int nominal,
    Map<String, dynamic> tariff,
  ) {
    final start = _getEffectiveStartDate(tariff);
    final now = DateTime.now();

    if (type == 'Harian') {
      final startMidnight = DateTime(start.year, start.month, start.day);
      final endOfMonthMidnight = DateTime(now.year, now.month + 1, 0);
      
      Set<String> exemptedDates = {};
      for (var ex in _myExemptions) {
        if (ex['tariffId'] == tariff['id']) {
          DateTime? s = _parseDate(ex['startDate']);
          DateTime? e = _parseDate(ex['endDate']);
          if (s != null) {
            DateTime c = DateTime(s.year, s.month, s.day);
            DateTime end = e != null ? DateTime(e.year, e.month, e.day) : endOfMonthMidnight;
            while (!c.isAfter(end)) {
              exemptedDates.add(DateFormat('yyyy-MM-dd').format(c));
              c = c.add(const Duration(days: 1));
            }
          }
        }
      }

      int validDays = 0;
      DateTime current = startMidnight;
      while (!current.isAfter(endOfMonthMidnight)) {
        if (!exemptedDates.contains(DateFormat('yyyy-MM-dd').format(current))) {
          validDays++;
        }
        current = current.add(const Duration(days: 1));
      }

      return validDays * nominal;
    } else if (type == 'Bulanan') {
      int validMonths = 0;
      DateTime current = DateTime(start.year, start.month, 1);
      final endOfYearMonth = DateTime(now.year, 12, 1);

      while (!current.isAfter(endOfYearMonth)) {
        final monthStart = DateTime(current.year, current.month, 1);
        final monthEnd = DateTime(current.year, current.month + 1, 0, 23, 59, 59);

        bool isMonthExempted = false;
        for (var ex in _myExemptions) {
          if (ex['tariffId'] == tariff['id']) {
            DateTime? s = _parseDate(ex['startDate']);
            DateTime? e = _parseDate(ex['endDate']);
            if (s != null) {
              final sStart = DateTime(s.year, s.month, s.day);
              final eEnd = e != null ? DateTime(e.year, e.month, e.day, 23, 59, 59) : null;

              if (!sStart.isAfter(monthEnd) && (eEnd == null || !eEnd.isBefore(monthStart))) {
                isMonthExempted = true;
                break;
              }
            }
          }
        }

        if (!isMonthExempted) {
          validMonths++;
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      return validMonths * nominal;
    } else if (type == 'Tahunan') {
      int validYears = 0;
      for (int y = start.year; y <= now.year; y++) {
        final yearStart = DateTime(y, 1, 1);
        final yearEnd = DateTime(y, 12, 31, 23, 59, 59);

        bool isYearExempted = false;
        for (var ex in _myExemptions) {
          if (ex['tariffId'] == tariff['id']) {
            DateTime? s = _parseDate(ex['startDate']);
            DateTime? e = _parseDate(ex['endDate']);
            if (s != null) {
              final sStart = DateTime(s.year, s.month, s.day);
              final eEnd = e != null ? DateTime(e.year, e.month, e.day, 23, 59, 59) : null;

              if (!sStart.isAfter(yearEnd) && (eEnd == null || !eEnd.isBefore(yearStart))) {
                isYearExempted = true;
                break;
              }
            }
          }
        }

        if (!isYearExempted) {
          validYears++;
        }
      }

      return validYears * nominal;
    } else if (type == 'Sekali Bayar' ||
        type == 'Insidentil' ||
        type == 'Lainnya') {
      bool isExempted = false;
      for (var ex in _myExemptions) {
        if (ex['tariffId'] == tariff['id']) {
          isExempted = true;
          break;
        }
      }
      return isExempted ? 0 : nominal;
    }
    return 0; // Default fallback
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<void> _shareBillDetailPdf() async {
    try {
      final tariffs = <Map<String, dynamic>>[];
      int overallExpected = 0;
      int overallPaid = 0;

      for (final tariff in _tariffs) {
        if (_exemptedTariffIds.contains(tariff['id'])) continue;
        final tariffId = tariff['id']?.toString() ?? '';
        final type = tariff['type']?.toString() ?? 'Harian';
        final nominal = (tariff['amount'] as num?)?.toInt() ?? 0;
        final expectedTotal = _calculateExpectedTotal(type, nominal, tariff);
        final totalPaid = _payments[tariffId] ?? 0;
        overallExpected += expectedTotal;
        overallPaid += totalPaid;
        tariffs.add({
          'name': tariff['name']?.toString() ?? 'Tarif',
          'type': type,
          'paid': totalPaid,
          'arrears': expectedTotal - totalPaid,
        });
      }

      final overallTotal = (overallExpected - overallPaid).clamp(
        0,
        999999999999,
      );
      final currentUserData = _freshUserData ?? widget.userData;
      final residentName = currentUserData?['name']?.toString() ?? 'Warga';
      final fileName =
          'Detail_Tagihan_${residentName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}.pdf';

      await shareBillDetailPdf(
        residentName: residentName,
        fileName: fileName,
        tariffs: tariffs,
        overallExpected: overallExpected,
        overallPaid: overallPaid,
        overallTotal: overallTotal,
      );

      if (mounted) {
        CustomToast.show(context, 'PDF detail tagihan berhasil dibagikan.');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal membuat PDF detail tagihan: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int overallExpected = 0;
    int overallPaid = 0;
    if (!_isLoading && _tariffs.isNotEmpty) {
      for (var tariff in _tariffs) {
        if (_exemptedTariffIds.contains(tariff['id'])) continue; // dibebaskan
        final tariffId = tariff['id']?.toString() ?? '';
        final type = tariff['type']?.toString() ?? 'Harian';
        final nominal = (tariff['amount'] as num?)?.toInt() ?? 0;
        overallExpected += _calculateExpectedTotal(type, nominal, tariff);
        overallPaid += _payments[tariffId] ?? 0;
      }
    }
    final overallTotal = (overallExpected - overallPaid).clamp(
      0,
      double.maxFinite.toInt(),
    );

    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, primaryColor, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC), // Light modern background
            body: Stack(
              children: [
                // Glowing orb 1
                Positioned(
                  top: -100,
                  right: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.15),
                          blurRadius: 100,
                          spreadRadius: 50,
                        ),
                      ],
                    ),
                  ),
                ),
                // Glowing orb 2
                Positioned(
                  bottom: 50,
                  left: -100,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.1),
                          blurRadius: 80,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
                // Main content
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          _buildSliverAppBar(overallTotal, primaryColor),
                          if (_tariffs.isEmpty)
                            const SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  "Belum ada daftar tarif di desa ini.",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final visibleTariffs = _tariffs
                                        .where(
                                          (t) =>
                                              !_exemptedTariffIds.contains(t['id']),
                                        )
                                        .toList();

                                    if (index < visibleTariffs.length) {
                                      return _buildTariffCard(
                                        visibleTariffs[index],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  childCount: _tariffs
                                      .where(
                                        (t) =>
                                            !_exemptedTariffIds.contains(t['id']),
                                      )
                                      .length,
                                ),
                              ),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(int overallTotal, Color primaryColor) {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
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
      ),
      title: const Text(
        'Detail Tagihan Warga',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            onTap: _shareBillDetailPdf,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                AppTheme.secondaryColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Dekorasi Lingkaran Kanan Atas
              Positioned(
                right: -30,
                top: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 140,
                    height: 140,
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
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Total Semua Tagihan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatCurrency(overallTotal),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (overallTotal == 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '✨ Lunas! Terima kasih.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Return list of unpaid periods (label, amount, paid).
  List<Map<String, dynamic>> _getUnpaidPeriods(
    String type,
    int nominal,
    int totalPaid,
    Map<String, dynamic> tariff,
  ) {
    final start = _getEffectiveStartDate(tariff);
    final now = DateTime.now();
    final periods = <Map<String, dynamic>>[];

    if (type == 'Bulanan') {
      DateTime cursor = DateTime(start.year, start.month, 1);
      final endOfYearMonth = DateTime(now.year, 12, 1);
      int accumulatedPaid = totalPaid;
      while (!cursor.isAfter(endOfYearMonth)) {
        final monthStart = DateTime(cursor.year, cursor.month, 1);
        final monthEnd = DateTime(cursor.year, cursor.month + 1, 0, 23, 59, 59);

        bool isMonthExempted = false;
        for (var ex in _myExemptions) {
          if (ex['tariffId'] == tariff['id']) {
            DateTime? s = ex['startDate'] != null
                ? DateTime.tryParse(ex['startDate'].toString())?.toLocal()
                : null;
            DateTime? e = ex['endDate'] != null
                ? DateTime.tryParse(ex['endDate'].toString())?.toLocal()
                : null;
            if (s != null) {
              final sStart = DateTime(s.year, s.month, s.day);
              final eEnd = e != null
                  ? DateTime(e.year, e.month, e.day, 23, 59, 59)
                  : null;

              if (!sStart.isAfter(monthEnd) &&
                  (eEnd == null || !eEnd.isBefore(monthStart))) {
                isMonthExempted = true;
                break;
              }
            }
          }
        }

        if (!isMonthExempted) {
          final label = '${_monthName(cursor.month)} ${cursor.year}';
          final paid = accumulatedPaid >= nominal
              ? nominal
              : (accumulatedPaid > 0 ? accumulatedPaid : 0);
          accumulatedPaid = (accumulatedPaid - nominal).clamp(0, 9999999);
          periods.add({
            'label': label,
            'amount': nominal,
            'paid': paid,
            'date': cursor,
          });
        }
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }
    } else if (type == 'Tahunan') {
      int accumulatedPaid = totalPaid;
      for (int y = start.year; y <= now.year; y++) {
        final yearStart = DateTime(y, 1, 1);
        final yearEnd = DateTime(y, 12, 31, 23, 59, 59);

        bool isYearExempted = false;
        for (var ex in _myExemptions) {
          if (ex['tariffId'] == tariff['id']) {
            DateTime? s = ex['startDate'] != null
                ? DateTime.tryParse(ex['startDate'].toString())?.toLocal()
                : null;
            DateTime? e = ex['endDate'] != null
                ? DateTime.tryParse(ex['endDate'].toString())?.toLocal()
                : null;
            if (s != null) {
              final sStart = DateTime(s.year, s.month, s.day);
              final eEnd = e != null
                  ? DateTime(e.year, e.month, e.day, 23, 59, 59)
                  : null;

              if (!sStart.isAfter(yearEnd) &&
                  (eEnd == null || !eEnd.isBefore(yearStart))) {
                isYearExempted = true;
                break;
              }
            }
          }
        }

        if (!isYearExempted) {
          final paid = accumulatedPaid >= nominal
              ? nominal
              : (accumulatedPaid > 0 ? accumulatedPaid : 0);
          accumulatedPaid = (accumulatedPaid - nominal).clamp(0, 9999999);
          periods.add({
            'label': 'Tahun $y',
            'amount': nominal,
            'paid': paid,
            'date': DateTime(y),
          });
        }
      }
    } else if (type == 'Harian') {
      final startMidnight = DateTime(start.year, start.month, start.day);
      final endOfMonthMidnight = DateTime(now.year, now.month + 1, 0);
      
      Set<String> exemptedDates = {};
      for (var ex in _myExemptions) {
        if (ex['tariffId'] == tariff['id']) {
          DateTime? s = _parseDate(ex['startDate']);
          DateTime? e = _parseDate(ex['endDate']);
          if (s != null) {
            DateTime c = DateTime(s.year, s.month, s.day);
            DateTime end = e != null ? DateTime(e.year, e.month, e.day) : endOfMonthMidnight;
            while (!c.isAfter(end)) {
              exemptedDates.add(DateFormat('yyyy-MM-dd').format(c));
              c = c.add(const Duration(days: 1));
            }
          }
        }
      }

      List<DateTime> validDates = [];
      DateTime current = startMidnight;
      while (!current.isAfter(endOfMonthMidnight)) {
        if (!exemptedDates.contains(DateFormat('yyyy-MM-dd').format(current))) {
          validDates.add(current);
        }
        current = current.add(const Duration(days: 1));
      }

      Map<String, int> dailyPaid = {};
      final history = _paymentHistory[tariff['id']] ?? [];
      
      for (var h in history) {
        final tsStr = h['timestamp'] ?? h['createdAt'];
        if (tsStr != null) {
           final t = DateTime.tryParse(tsStr.toString())?.toLocal();
           if (t != null) {
              final dStr = DateFormat('yyyy-MM-dd').format(t);
              final amt = (h['amount'] as num?)?.toInt() ?? 0;
              dailyPaid[dStr] = (dailyPaid[dStr] ?? 0) + amt;
           }
        }
      }

      int totalAssignedFromScans = 0;
      Set<String> validDateStrings = validDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();
      
      for (var dStr in dailyPaid.keys.toList()) {
         if (validDateStrings.contains(dStr)) {
            int amt = dailyPaid[dStr]!;
            int applied = amt >= nominal ? nominal : amt;
            dailyPaid[dStr] = applied;
            totalAssignedFromScans += applied;
         } else {
            dailyPaid[dStr] = 0;
         }
      }

      int remainingPool = totalPaid - totalAssignedFromScans;
      if (remainingPool < 0) remainingPool = 0;

      for (var date in validDates) {
         final dStr = DateFormat('yyyy-MM-dd').format(date);
         int currentPaid = dailyPaid[dStr] ?? 0;
         if (currentPaid < nominal && remainingPool > 0) {
            int needed = nominal - currentPaid;
            int applied = remainingPool >= needed ? needed : remainingPool;
            dailyPaid[dStr] = currentPaid + applied;
            remainingPool -= applied;
         }
      }

      Map<String, Map<String, dynamic>> monthlyData = {};
      
      for (var date in validDates) {
        final dStr = DateFormat('yyyy-MM-dd').format(date);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (!monthlyData.containsKey(monthKey)) {
          monthlyData[monthKey] = {
             'date': DateTime(date.year, date.month),
             'amount': 0,
             'paid': 0,
             'unpaidDates': <int>[],
          };
        }
        
        monthlyData[monthKey]!['amount'] = (monthlyData[monthKey]!['amount'] as int) + nominal;
        
        int paidForDay = dailyPaid[dStr] ?? 0;
        monthlyData[monthKey]!['paid'] = (monthlyData[monthKey]!['paid'] as int) + paidForDay;
        
        if (paidForDay < nominal) {
           (monthlyData[monthKey]!['unpaidDates'] as List<int>).add(date.day);
        }
      }

      final sortedKeys = monthlyData.keys.toList()..sort();
      for (var key in sortedKeys) {
        final data = monthlyData[key]!;
        final date = data['date'] as DateTime;
        final unpaidDays = data['unpaidDates'] as List<int>;
        
        String label = '${_monthName(date.month)} ${date.year}';
        if (unpaidDays.isNotEmpty) {
           String daysStr = _formatDayRanges(unpaidDays);
           label += ' (Tgl $daysStr)';
        }
        
        periods.add({
          'label': label,
          'amount': data['amount'],
          'paid': data['paid'],
          'date': date,
        });
      }
    }
    return periods;
  }

  String _formatDayRanges(List<int> days) {
    if (days.isEmpty) return '';
    List<String> ranges = [];
    int start = days[0];
    int prev = days[0];
    
    for (int i = 1; i < days.length; i++) {
      if (days[i] == prev + 1) {
        prev = days[i];
      } else {
        if (start == prev) {
          ranges.add('$start');
        } else {
          ranges.add('$start-$prev');
        }
        start = days[i];
        prev = days[i];
      }
    }
    if (start == prev) {
      ranges.add('$start');
    } else {
      ranges.add('$start-$prev');
    }
    return ranges.join(', ');
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return names[month - 1];
  }

  Widget _buildTariffCard(Map<String, dynamic> tariff) {
    final name = tariff['name']?.toString() ?? 'Tarif';
    final type = tariff['type']?.toString() ?? 'Harian';
    final nominal = (tariff['amount'] as num?)?.toInt() ?? 0;
    final tariffId = tariff['id']?.toString() ?? '';

    final expectedTotal = _calculateExpectedTotal(type, nominal, tariff);
    final totalPaid = _payments[tariffId] ?? 0;
    final arrears = expectedTotal - totalPaid;
    final (effectiveDate, effectiveSource) = _getEffectiveDateWithSource(tariff);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showPaymentHistory(tariffId, name),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildModernInfoRow(
                              'Tarif per $type',
                              _formatCurrency(nominal),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            // Mulai dihitung
                            Row(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Mulai dihitung: ${DateFormat('dd MMMM yyyy', 'id_ID').format(effectiveDate)} ($effectiveSource)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            _buildModernInfoRow(
                              'Total Diwajibkan',
                              _formatCurrency(expectedTotal),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            _buildModernInfoRow(
                              'Total Terbayar',
                              _formatCurrency(totalPaid),
                              valueColor: Colors.green.shade600,
                            ),
                          ],
                        ),
                      ),

                      // Period Breakdown — hanya tampil untuk Bulanan/Tahunan/Harian
                      if (type == 'Bulanan' ||
                          type == 'Tahunan' ||
                          type == 'Harian') ...[
                        const SizedBox(height: 12),
                        _buildPeriodBreakdown(type, nominal, totalPaid, tariff),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sisa Tagihan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: arrears > 0
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: arrears > 0
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Text(
                              _formatCurrency(arrears > 0 ? arrears : 0),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: arrears > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodBreakdown(
    String type,
    int nominal,
    int totalPaid,
    Map<String, dynamic> tariff,
  ) {
    final unpaidPeriods = _getUnpaidPeriods(type, nominal, totalPaid, tariff);
    // Only show periods that are NOT fully paid
    final unpaid = unpaidPeriods
        .where((p) => (p['amount'] as int) - (p['paid'] as int) > 0)
        .toList();
    if (unpaid.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: 10,
          ),
          leading: Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade400,
            size: 20,
          ),
          title: Text(
            '${unpaid.length} periode belum lunas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          subtitle: Text(
            'Ketuk untuk lihat detail',
            style: TextStyle(fontSize: 11, color: Colors.red.shade400),
          ),
          iconColor: Colors.red.shade400,
          collapsedIconColor: Colors.red.shade300,
          children: unpaid.map((p) {
            final bill = p['amount'] as int;
            final paid = p['paid'] as int;
            final sisa = bill - paid;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 12,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p['label'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Rp ${_formatCurrency(sisa)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPaymentHistory(String tariffId, String tariffName) {
    final history = _paymentHistory[tariffId] ?? [];
    history.sort((a, b) {
      final tAStr = a['timestamp'] ?? a['createdAt'];
      final tBStr = b['timestamp'] ?? b['createdAt'];
      DateTime? tA = tAStr != null ? DateTime.tryParse(tAStr.toString())?.toLocal() : null;
      DateTime? tB = tBStr != null ? DateTime.tryParse(tBStr.toString())?.toLocal() : null;
      if (tA == null || tB == null) return 0;
      return tB.compareTo(tA);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 5,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riwayat Pembayaran',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tariffName,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada riwayat pembayaran',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final item = history[index];
                              final amount =
                                  (item['amount'] as num?)?.toInt() ?? 0;
                              final tsStr = item['timestamp'] ?? item['createdAt'];
                              DateTime? ts = tsStr != null ? DateTime.tryParse(tsStr.toString())?.toLocal() : null;
                              final dateStr = ts != null
                                  ? '${ts.day}/${ts.month}/${ts.year}'
                                  : '-';
                              final desc =
                                  item['description']?.toString() ??
                                  item['period']?.toString() ??
                                  '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.green.shade600,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            desc.isNotEmpty
                                                ? desc
                                                : 'Pembayaran Masuk',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '+${_formatCurrency(amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.green.shade700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
