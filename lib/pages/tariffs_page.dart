import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/api_service.dart';

import 'package:jimpitan/widgets/app_modal_dialog.dart';

class TariffsPage extends StatefulWidget {
  final Map<String, bool> permissions;
  final String villageId;
  const TariffsPage({
    super.key,
    required this.permissions,
    required this.villageId,
  });

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  late Future<List<dynamic>> _tariffsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _tariffsFuture = ApiService.getTariffs(widget.villageId).then((tariffs) {
        _ensureDefaultJimpitanTariff(tariffs);
        return tariffs;
      });
    });
  }

  Future<void> _ensureDefaultJimpitanTariff(List<dynamic> tariffs) async {
    final String docId = '${widget.villageId}_jimpitan';
    final hasJimpitan = tariffs.any((t) => t['id'] == docId);

    if (!hasJimpitan) {
      await ApiService.createTariff({
        'id': docId,
        'name': 'Jimpitan Default',
        'amount': 500,
        'type': 'Harian',
        'isActive': true,
        'villageId': widget.villageId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      // reload
      if (mounted) _loadData();
    }
  }

  void _showTariffForm({Map<String, dynamic>? data}) {
    final bool isEdit = data != null;

    final String rawId = data?['id'] ?? '';
    final TextEditingController idController = TextEditingController(
      text: isEdit ? rawId.replaceFirst('${widget.villageId}_', '') : '',
    );
    final TextEditingController nameController = TextEditingController(
      text: isEdit ? (data['name'] ?? '') : '',
    );
    final TextEditingController amountController = TextEditingController(
      text: isEdit ? (data['amount']?.toString() ?? '') : '',
    );
    String selectedType = isEdit ? (data['type'] ?? 'Bulanan') : 'Bulanan';
    bool isActive = isEdit ? (data['isActive'] ?? true) : true;
    
    DateTime effectiveDate = DateTime.now();
    if (isEdit && data['createdAt'] != null) {
      final dynamic rawDate = data['createdAt'];
      if (rawDate is String) {
        effectiveDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
      } else if (rawDate is int) {
        effectiveDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
      }
    }

    final bool isJimpitan = idController.text.trim().toLowerCase() == 'jimpitan';

    final List<String> tariffTypes = [
      if (selectedType == 'Harian') 'Harian',
      'Bulanan',
      'Tahunan',
      'Sekali Bayar',
      'Insidental',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppModalDialog(
              title: isEdit ? 'Edit Tarif' : 'Tambah Tarif Baru',
              headerIcon: Icons.payments,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                      TextField(
                        controller: idController,
                        enabled: !isEdit,
                        decoration: InputDecoration(
                          labelText: 'ID Tarif (misal: jimpitan)',
                          hintText: 'Tanpa spasi, huruf kecil',
                          prefixIcon: const Icon(
                            Icons.key,
                            color: Colors.black45,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        enabled: !isJimpitan,
                        decoration: InputDecoration(
                          labelText: 'Nama Tarif (misal: Kas Kematian)',
                          prefixIcon: const Icon(
                            Icons.label,
                            color: Colors.black45,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal (Rp)',
                          prefixIcon: const Icon(
                            Icons.money,
                            color: Colors.black45,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Periode / Tipe Pembayaran',
                          prefixIcon: const Icon(
                            Icons.event_repeat,
                            color: Colors.black45,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: tariffTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: isJimpitan ? null : (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: effectiveDate,
                            firstDate: DateTime(2000),
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
                          if (picked != null) {
                            setDialogState(() {
                              effectiveDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tanggal Efektif Tarif',
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.black45),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            DateFormat('dd MMMM yyyy', 'id_ID').format(effectiveDate),
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            'Status Aktif',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          value: isActive,
                          onChanged: isJimpitan ? null : (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          activeTrackColor: Color(
                            0xFF6F4E37,
                          ).withValues(alpha: 0.5),
                          activeThumbColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Batal',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (idController.text.isEmpty ||
                                    nameController.text.isEmpty ||
                                    amountController.text.isEmpty) {
                                  return;
                                }

                                final String docId =
                                    '${widget.villageId}_${idController.text.trim().toLowerCase()}';
                                final int amount =
                                    int.tryParse(amountController.text) ?? 0;

                                final Map<String, dynamic> data = {
                                  'name': nameController.text.trim(),
                                  'amount': amount,
                                  'type': selectedType,
                                  'isActive': isActive,
                                  'villageId': widget.villageId,
                                  'updatedAt': DateTime.now().toIso8601String(),
                                  'createdAt': effectiveDate.toIso8601String(),
                                };

                                EasyLoading.show(status: 'Menyimpan...');
                                bool success = false;
                                try {
                                  if (isEdit) {
                                    success = await ApiService.updateTariff(docId, data);
                                  } else {
                                    data['id'] = docId;
                                    success = await ApiService.createTariff(data);
                                  }

                                  if (success && context.mounted) {
                          CustomToast.show(context, 'Data berhasil disimpan');
                          CustomToast.show(context, 'Data berhasil disimpan');
                                    Navigator.pop(context);
                                    _loadData();
                                  }
                                } catch (e) {
                                  EasyLoading.showError('Gagal menyimpan');
                                } finally {
                                  EasyLoading.dismiss();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Simpan',
                                style: TextStyle(fontWeight: FontWeight.bold),
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
      },
    );
  }

  void _deleteTariff(String id) {
    showDialog(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Hapus Tarif',
        headerIcon: Icons.delete,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Anda yakin ingin menghapus tarif $id?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      EasyLoading.show(status: 'Menghapus...');
                      try {
                        bool success = await ApiService.deleteTariff(id);
                        if (success && context.mounted) {
                          CustomToast.show(context, 'Data berhasil dihapus');
                          Navigator.pop(context);
                          _loadData();
                        }
                      } catch (e) {
                        EasyLoading.showError('Gagal menghapus');
                      } finally {
                        EasyLoading.dismiss();
                      }
                    },
                    child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomGradientAppBar(
        titleText: 'Manajemen Tarif',
        actions: [
          if (widget.permissions['create'] == true)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
              onPressed: () => _showTariffForm(),
              tooltip: 'Tambah Tarif',
            ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _tariffsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Belum ada data tarif.'));
          }

          final docs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = Map<String, dynamic>.from(docs[index] as Map? ?? {});
              final String id = data['id'] ?? '';
              final String name = data['name'] ?? 'No Name';
              final int amount = data['amount'] ?? 0;
              final String type = data['type'] ?? 'Harian';
              final bool isActive = data['isActive'] ?? true;
              
              DateTime effectiveDate = DateTime.now();
              if (data['createdAt'] != null) {
                final dynamic rawDate = data['createdAt'];
                if (rawDate is String) {
                  effectiveDate = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
                } else if (rawDate is int) {
                  effectiveDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
                }
              }
              final String formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(effectiveDate);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Color(
                              0xFF6F4E37,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.request_quote,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'ID: $id\nNominal: Rp $amount • $type\nEfektif: $formattedDate',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.permissions['edit'] == true)
                          IconButton(
                            icon: Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _showTariffForm(data: data),
                          ),
                        if (id != '${widget.villageId}_jimpitan' && widget.permissions['delete'] == true)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTariff(id),
                          ),
                      ],
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
