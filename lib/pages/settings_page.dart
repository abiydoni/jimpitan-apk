import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_gradient_app_bar.dart';
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
  final _villageFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  String _uniqueCode = '';
  DateTime? _startDate;
  bool _isLoading = true;
  Map<String, dynamic>? _subscriptionData;

  bool get _canEdit => widget.permissions['edit'] ?? false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final villageData = await ApiService.getVillage(widget.villageId);
      if (villageData != null) {
        _nameController.text = villageData['name']?.toString() ?? '';
        _addressController.text = villageData['address']?.toString() ?? '';
        _uniqueCode = villageData['uniqueCode']?.toString() ?? '';

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

  Future<void> _saveVillageInfo() async {
    if (!_canEdit) return;
    if (!_villageFormKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final newAddress = _addressController.text.trim();

    try {
      EasyLoading.show(status: 'Menyimpan Profil Desa...');
      final success = await ApiService.updateVillage(widget.villageId, {
        'name': newName,
        'address': newAddress,
      });

      if (success) {
        if (mounted) {
          CustomToast.show(context, 'Data profil desa berhasil diperbarui!');
        }
      } else {
        if (mounted) {
          CustomToast.show(context, 'Gagal memperbarui data desa', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Terjadi kesalahan: $e', isError: true);
      }
    } finally {
      EasyLoading.dismiss();
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
          appBar: const CustomGradientAppBar(
            titleText: 'Pengaturan Desa',
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVillageInfoCard(themeColor),
                    const SizedBox(height: 16),
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
                                final isSelected = themeColor.toARGB32() == color.toARGB32();

                                return InkWell(
                                  onTap: () async {
                                    AppTheme.changeTheme(color);
                                    try {
                                      final villageData = await ApiService.getVillage(widget.villageId);
                                      Map<String, dynamic> config = {};
                                      if (villageData != null && villageData['config'] != null) {
                                        var rawConf = villageData['config'];
                                        if (rawConf is String) {
                                          try {
                                            rawConf = json.decode(rawConf);
                                            if (rawConf is String) rawConf = json.decode(rawConf);
                                          } catch (_) {}
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
                                        CustomToast.show(context, 'Tema desa diperbarui ke $name!');
                                      }
                                    } catch (e) {
                                      debugPrint('Gagal menyimpan tema desa: $e');
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
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: color.withValues(alpha: 0.4),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : null,
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

  Widget _buildVillageInfoCard(Color themeColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _villageFormKey,
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
                    child: Icon(Icons.maps_home_work, color: themeColor),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profil & Informasi Desa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nama, alamat resmi, dan kode registrasi warga',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                enabled: _canEdit,
                decoration: InputDecoration(
                  labelText: 'Nama Desa / Lingkungan',
                  hintText: 'Contoh: RT 03 RW 05 Sukamaju',
                  prefixIcon: Icon(Icons.apartment, color: themeColor),
                  filled: true,
                  fillColor: _canEdit ? const Color(0xFFF8FAFC) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(12),
                     borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama desa tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Kode Unik Desa
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.vpn_key_rounded, color: themeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kode Unik Desa (Gabung Warga)',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _uniqueCode.isNotEmpty ? _uniqueCode : '-',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_uniqueCode.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: themeColor),
                        tooltip: 'Salin Kode Desa',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _uniqueCode));
                          CustomToast.show(context, 'Kode Desa disalin: $_uniqueCode');
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                enabled: _canEdit,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alamat / Lokasi Desa',
                  hintText: 'Alamat lengkap desa / RT / RW',
                  prefixIcon: Icon(Icons.location_on_outlined, color: themeColor),
                  filled: true,
                  fillColor: _canEdit ? const Color(0xFFF8FAFC) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alamat desa tidak boleh kosong';
                  }
                  return null;
                },
              ),
              if (_canEdit) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text(
                      'Simpan Perubahan Desa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: _saveVillageInfo,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

