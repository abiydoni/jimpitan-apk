import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:jimpitan/models/menu_item.dart';
import 'package:jimpitan/utils/menu_helper.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class MenusPage extends StatefulWidget {
  final Map<String, bool> permissions;
  
  const MenusPage({super.key, required this.permissions});

  @override
  State<MenusPage> createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  
  String _selectedIcon = 'widgets';
  String _selectedPosition = 'grid';

  Future<List<dynamic>>? _menusFuture;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupFCM();
    _syncCoreMenus();
  }

  void _loadData() {
    setState(() {
      _menusFuture = ApiService.getMenus();
    });
  }

  void _setupFCM() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['action'] == 'REFRESH_MENUS' || message.data['action'] == 'REFRESH_ALL') {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _idController.dispose();
    _labelController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  // Sinkronisasi otomatis agar menu yang sudah terlanjur di database mendapat label isCore dan position
  void _syncCoreMenus() async {
    try {
      // appMenus di-import dari menu_item.dart
      for (var menu in appMenus) {
        if (menu.isCore) {
          await ApiService.updateMenu(
            menu.id,
            {
              'isCore': true,
              if (menu.position == 'footer' || menu.position == 'hidden') 'position': menu.position,
            },
          );
        }
      }
      _loadData();
    } catch (e) {
      debugPrint("Gagal sinkronisasi core menus: $e");
    }
  }

  void _showMenuFormDialog([Map<String, dynamic>? doc]) {
    if (doc != null) {
      final data = doc;
      _idController.text = doc['id'] ?? '';
      _labelController.text = data['label'] ?? '';
      _orderController.text = (data['order'] ?? 99).toString();
      _selectedIcon = data['icon'] ?? 'widgets';
      _selectedPosition = data['position'] ?? 'grid';
    } else {
      _idController.clear();
      _labelController.clear();
      _orderController.text = '99';
      _selectedIcon = 'widgets';
      _selectedPosition = 'grid';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppModalDialog(
              title: doc == null ? 'Tambah Menu Baru' : 'Edit Menu',
              headerIcon: Icons.widgets_rounded,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      const SizedBox(height: 24),
                      _buildModernTextField(
                        controller: _idController,
                        label: 'Menu ID',
                        hint: 'misal: laporan_baru',
                        icon: Icons.tag,
                        enabled: doc == null,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _labelController,
                        label: 'Label Menu',
                        hint: 'Nama menu yang tampil',
                        icon: Icons.title,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _orderController,
                        label: 'Urutan',
                        hint: 'misal: 1, 2, 3',
                        icon: Icons.format_list_numbered,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Ikon Menu',
                          prefixIcon: const Icon(Icons.image, color: Colors.black45),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        initialValue: _selectedIcon,
                        items: MenuHelper.availableIconNames.map((iconName) {
                          return DropdownMenuItem(
                            value: iconName,
                            child: Row(
                              children: [
                                Icon(MenuHelper.getIcon(iconName), color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Text(iconName, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => _selectedIcon = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Lokasi Menu',
                          prefixIcon: const Icon(Icons.place, color: Colors.black45),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        initialValue: _selectedPosition,
                        items: const [
                          DropdownMenuItem(value: 'grid', child: Text('Beranda Tengah (Grid)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'footer', child: Text('Bawah (Footer)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'hidden', child: Text('Tersembunyi (Khusus Tombol)', style: TextStyle(fontSize: 14))),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => _selectedPosition = val);
                        },
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
                                if (_idController.text.isEmpty || _labelController.text.isEmpty) return;
                                  EasyLoading.show(status: 'Menyimpan...');
                                  try {
                                    if (doc == null) {
                                      await ApiService.updateMenu(
                                        _idController.text,
                                        {
                                          'id': _idController.text,
                                          'label': _labelController.text,
                                          'icon': _selectedIcon,
                                          'order': 99,
                                          'defaultRoles': ['SUPER_ADMIN'],
                                          'isActive': true,
                                          'position': _selectedPosition,
                                        },
                                      );
                                    } else {
                                      await ApiService.updateMenu(
                                        doc['id'],
                                        {
                                          'label': _labelController.text,
                                          'icon': _selectedIcon,
                                          'order': doc['order'] ?? 99,
                                          'position': _selectedPosition,
                                        },
                                      );
                                    }
                                    
                                    _loadData();
                                    if (context.mounted) { CustomToast.show(context, 'Data berhasil disimpan'); Navigator.pop(context); }
                                  } catch (e) {
                                    EasyLoading.showError('Gagal menyimpan menu');
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
          }
        );
      },
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? Colors.black87 : Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        prefixIcon: Icon(icon, color: enabled ? Colors.black45 : Colors.black26),
        filled: true,
        fillColor: Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _toggleMenuStatus(String docId, bool currentStatus) async {
    EasyLoading.show(status: 'Mengubah status...');
    try {
      await ApiService.updateMenu(docId, {'isActive': !currentStatus});
      _loadData();
    } catch (e) {
      EasyLoading.showError('Gagal mengubah status');
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _deleteMenu(String docId) async {
    showDialog(
      context: context,
      builder: (context) => AppModalDialog(
        title: 'Hapus Menu',
        headerIcon: Icons.delete,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apakah Anda yakin ingin menghapus menu ini secara permanen dari database?'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      EasyLoading.show(status: 'Menghapus...');
                      try {
                        await ApiService.deleteMenu(docId);
                        _loadData();
                        if (context.mounted) { CustomToast.show(context, 'Data berhasil dihapus'); Navigator.pop(context); }
                      } catch (e) {
                        EasyLoading.showError('Gagal menghapus menu');
                      } finally {
                        EasyLoading.dismiss();
                      }
                    },
                    child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.permissions['view'] != true) {
      return const Scaffold(
        appBar: CustomGradientAppBar(titleText: 'Manajemen Menu Master'),
        body: Center(child: Text('Anda tidak memiliki akses ke halaman ini.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: CustomGradientAppBar(
        titleText: 'Kelola Menu Akses',
        actions: [
          if (widget.permissions['create'] == true)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
              onPressed: () => _showMenuFormDialog(),
              tooltip: 'Tambah Menu',
            ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _menusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          
          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 100),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final data = snapshot.data![index] as Map<String, dynamic>;
              final isCore = data['isCore'] == true;
              final isActive = data['isActive'] == true;
              
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(MenuHelper.getIcon(data['icon'] ?? 'widgets'), color: AppTheme.primaryColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['label'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildBadge("Urutan: ${data['order'] ?? 99}", const Color(0xFFF1F5F9), const Color(0xFF475569)),
                                if (isCore) 
                                  _buildBadge("SISTEM", const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
                                if (data['position'] == 'footer') 
                                  _buildBadge("FOOTER", const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.permissions['delete'] == true && !isCore)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMenu(data['id']),
                        ),
                      if (widget.permissions['edit'] == true)
                        IconButton(
                          icon: Icon(Icons.edit, color: AppTheme.primaryColor),
                          onPressed: () => _showMenuFormDialog(data),
                        ),
                      Switch(
                        value: isActive,
                        activeTrackColor: AppTheme.primaryColor,
                        activeThumbColor: Colors.white,
                        onChanged: (val) => _toggleMenuStatus(data['id'], isActive),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Belum Ada Menu",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tambahkan menu pertama Anda untuk\nditampilkan di aplikasi warga.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
