import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:math';

class VillagesPage extends StatefulWidget {
  final Map<String, bool> permissions;
  const VillagesPage({super.key, required this.permissions});

  @override
  State<VillagesPage> createState() => _VillagesPageState();
}

class _VillagesPageState extends State<VillagesPage> {
  List<dynamic> _villages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVillages();
  }

  Future<void> _fetchVillages() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getVillages();
    if (mounted) {
      setState(() {
        _villages = data;
        _isLoading = false;
      });
    }
  }

  void _showVillageDialog([Map<String, dynamic>? doc]) {
    final bool isEdit = doc != null;
    
    String initialCode = '';
    if (isEdit) {
      initialCode = doc['uniqueCode'] ?? '';
    } else {
      initialCode = (Random().nextInt(90000) + 10000).toString();
    }
    
    final TextEditingController nameController = TextEditingController(text: isEdit ? doc['name'] : '');
    final TextEditingController addressController = TextEditingController(text: isEdit ? doc['address'] : '');
    final TextEditingController uniqueCodeController = TextEditingController(text: initialCode);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AppModalDialog(
          title: isEdit ? 'Edit Desa' : 'Tambah Desa Baru',
          headerIcon: Icons.maps_home_work,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Desa',
                  prefixIcon: const Icon(Icons.home, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uniqueCodeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Kode Unik Desa (Otomatis Dibuat Sistem)',
                  prefixIcon: const Icon(Icons.vpn_key, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFE2E8F0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, letterSpacing: 2.0),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Alamat / Lokasi',
                  prefixIcon: const Icon(Icons.location_on, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty) return;
                        EasyLoading.show(status: 'Menyimpan desa...');
                        try {
                          if (isEdit) {
                            await ApiService.updateVillage(doc['id'], {
                              'name': nameController.text.trim(),
                              'address': addressController.text.trim(),
                              'uniqueCode': uniqueCodeController.text.trim().toUpperCase(),
                            });
                          } else {
                            await ApiService.createVillage({
                              'name': nameController.text.trim(),
                              'address': addressController.text.trim(),
                              'uniqueCode': uniqueCodeController.text.trim().toUpperCase(),
                            });
                          }
                          
                          if (context.mounted) {
                              if (mounted) CustomToast.show(context, 'Data berhasil disimpan');
                            Navigator.pop(context);
                            _fetchVillages();
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _deleteVillage(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppModalDialog(
          title: 'Konfirmasi Hapus',
          headerIcon: Icons.delete,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Apakah Anda yakin ingin menghapus desa ini?'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        EasyLoading.show(status: 'Menghapus desa...');
                        try {
                          await ApiService.deleteVillage(docId);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                            _fetchVillages();
                            CustomToast.show(context, 'Data berhasil dihapus');
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
        );
      },
    );

    if (confirm == true) {
      // Logic if any after delete
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Desa (Super Admin)'),
        actions: [
          if (widget.permissions['create'] == true)
            IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
              onPressed: () => _showVillageDialog(),
              tooltip: 'Tambah Desa',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _villages.isEmpty
            ? const Center(child: Text("Belum ada data desa."))
            : ListView.builder(
                itemCount: _villages.length,
                itemBuilder: (context, index) {
                  final village = _villages[index];
                  final docId = village['id'];
                  
                  final name = village['name'] ?? 'Desa Tanpa Nama';
                  final address = village['address'] ?? 'Belum ada alamat';
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_city, color: Colors.white),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(address),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.vpn_key, size: 14, color: Colors.black54),
                            SizedBox(width: 4),
                            Text(
                              village['uniqueCode'] ?? 'KODE BELUM DISET',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.permissions['edit'] == true || widget.permissions['update'] == true)
                          IconButton(
                            icon: Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _showVillageDialog(village),
                            tooltip: 'Edit Desa',
                          ),
                        if (widget.permissions['delete'] == true)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteVillage(docId),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
