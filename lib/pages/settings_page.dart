import 'package:flutter/material.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'dart:convert';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/pages/village_invoice_page.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class SettingsPage extends StatefulWidget {
  final String villageId;
  final Map<String, bool> permissions;
  final String? userDocId;

  const SettingsPage({
    super.key,
    required this.villageId,
    required this.permissions,
    this.userDocId,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  DateTime? _startDate;
  bool _isLoading = true;
  Map<String, dynamic>? _subscriptionData;

  bool get _canEdit => widget.permissions['edit'] ?? false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final villageData = await ApiService.getVillage(widget.villageId);
      if (villageData != null) {
        Map<String, dynamic> config = {};
        if (villageData['config'] != null) {
          if (villageData['config'] is String) {
            var decoded = json.decode(villageData['config']);
            if (decoded is String) {
               decoded = json.decode(decoded);
            }
            if (decoded is Map) {
              config = Map<String, dynamic>.from(decoded);
            }
          } else if (villageData['config'] is Map) {
            config = Map<String, dynamic>.from(villageData['config']);
          }
        }
        final startDateStr = config['startDate'];
        if (startDateStr != null) {
          if (startDateStr is String) {
            _startDate = DateTime.parse(startDateStr).toLocal();
          } else if (startDateStr is int) {
            _startDate = DateTime.fromMillisecondsSinceEpoch(startDateStr);
          }
        }
        _subscriptionData = await ApiService.getVillageSubscription(widget.villageId);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_startDate == null) {
      CustomToast.show(context, 'Silakan pilih tanggal mulai terlebih dahulu');
      return;
    }

    try {
      EasyLoading.show(status: 'Menyimpan...');
      
      final villageData = await ApiService.getVillage(widget.villageId);
      Map<String, dynamic> config = {};
      if (villageData != null && villageData['config'] != null) {
        if (villageData['config'] is String) {
          var decoded = json.decode(villageData['config']);
          if (decoded is String) {
             decoded = json.decode(decoded);
          }
          if (decoded is Map) {
            config = Map<String, dynamic>.from(decoded);
          }
        } else if (villageData['config'] is Map) {
          config = Map<String, dynamic>.from(villageData['config']);
        }
      }
      
      config['startDate'] = _startDate!.toIso8601String();
      
      await ApiService.updateVillage(widget.villageId, {
        'config': config,
      });

      if (mounted) {
        CustomToast.show(context, 'Pengaturan berhasil disimpan!');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal menyimpan: $e', isError: true);
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _selectDate() async {
    if (!_canEdit) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, themeColor, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pengaturan Desa'),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.date_range, color: themeColor),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Tanggal Mulai Aplikasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tanggal ini digunakan sebagai acuan awal dimulainya argometer tagihan jimpitan. '
                              'Sistem akan menghitung tagihan harian warga mulai dari tanggal yang dipilih di bawah ini.',
                              style: TextStyle(color: Colors.grey, height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _startDate != null 
                                        ? DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_startDate!)
                                        : 'Belum diatur (Pilih Tanggal)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _startDate != null ? Colors.black87 : Colors.grey,
                                        fontWeight: _startDate != null ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (_canEdit)
                                      Icon(Icons.edit_calendar, color: themeColor),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_canEdit)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _saveSettings,
                                  child: const Text(
                                    'Simpan Pengaturan',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.palette, color: themeColor),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Tema Warna Resmi Desa',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Pilih warna aksen resmi untuk desa Anda. Tema warna ini akan otomatis diterapkan ke seluruh warga dan pengurus di desa ini.',
                              style: TextStyle(color: Colors.grey, height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: AppTheme.availableThemes.map((themeData) {
                                final name = themeData['name'] as String;
                                final color = themeData['color'] as Color;
                                final isSelected = themeColor == color;

                                return InkWell(
                                  onTap: () async {
                                    AppTheme.changeTheme(color);
                                    try {
                                      final villageData = await ApiService.getVillage(widget.villageId);
                                      Map<String, dynamic> config = {};
                                      if (villageData != null && villageData['config'] != null) {
                                        var rawConf = villageData['config'];
                                        if (rawConf is String) {
                                          rawConf = json.decode(rawConf);
                                        }
                                        if (rawConf is String) {
                                          rawConf = json.decode(rawConf);
                                        }
                                        if (rawConf is Map) {
                                          config = Map<String, dynamic>.from(rawConf);
                                        }
                                      }
                                      config['themeColor'] = color.toARGB32();
                                      await ApiService.updateVillage(widget.villageId, {
                                        'config': config,
                                      });
                                      if (context.mounted) {
                                        CustomToast.show(context, 'Tema desa berhasil diperbarui untuk seluruh warga!');
                                      }
                                    } catch (e) {
                                      debugPrint('Gagal menyimpan tema desa: $e');
                                      if (context.mounted) {
                                        CustomToast.show(context, 'Gagal menyimpan tema: $e', isError: true);
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 70,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? color : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected ? color : Colors.grey.shade700,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_subscriptionData != null) ...[
                      const SizedBox(height: 16),
                      _buildSubscriptionCard(themeColor),
                    ],
                  ],
                ),
              ),
        );
      }
    );
  }

  Widget _buildSubscriptionCard(Color themeColor) {
    final status = _subscriptionData!['status'] ?? 'UNKNOWN';
    final plan = _subscriptionData!['plan'] ?? {};
    final planName = plan['name'] ?? 'Custom Plan';
    final endDate = _subscriptionData!['endDate'];
    
    Color statusColor = Colors.green;
    String statusText = 'Aktif';
    if (status == 'EXPIRED') {
      statusColor = Colors.red;
      statusText = 'Kedaluwarsa';
    } else if (status == 'TRIAL') {
      statusColor = Colors.orange;
      statusText = 'Uji Coba';
    }
    
    String formattedDate = '-';
    if (endDate != null) {
      try {
        formattedDate = DateFormat('dd MMM yyyy').format(DateTime.parse(endDate).toLocal());
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified, color: themeColor),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Status Langganan Desa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Detail Paket',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(planName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'Berlaku Sampai',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: themeColor,
                  side: BorderSide(color: themeColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text(
                  'Lihat Tagihan Langganan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VillageInvoicePage(villageId: widget.villageId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
