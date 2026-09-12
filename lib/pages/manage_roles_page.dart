import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/app_theme.dart';
import 'package:jimpitan/widgets/app_modal_dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class ManageRolesPage extends StatefulWidget {
  final Map<String, bool> permissions;
  final String villageId;
  final List<String> currentUserRoles;
  const ManageRolesPage({
    super.key,
    required this.permissions,
    required this.villageId,
    required this.currentUserRoles,
  });

  @override
  State<ManageRolesPage> createState() => _ManageRolesPageState();
}

class _ManageRolesPageState extends State<ManageRolesPage> {
  String get _currentVillageId => widget.villageId;
  final List<String> _protectedRoles = ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'];

  bool _isLoading = true;
  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final loadedRoles = await ApiService.getRoles(_currentVillageId);
      setState(() {
        if (widget.currentUserRoles.contains('SUPER_ADMIN')) {
          _roles = loadedRoles;
        } else {
          _roles = loadedRoles
              .where((r) => r != 'SUPER_ADMIN' && r != 'ADMIN_DESA')
              .toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat jabatan: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveRolesToServer() async {
    EasyLoading.show(status: 'Menyimpan...');
    try {
      // Asumsi ApiService.saveRoles akan mengirim List<String> ke backend
      await ApiService.saveRoles(_currentVillageId, _roles);
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _showAddRoleDialog() {
    final TextEditingController roleController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AppModalDialog(
          title: 'Tambah Jabatan Baru',
          headerIcon: Icons.badge,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              TextField(
                controller: roleController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Nama Jabatan',
                  hintText: 'Contoh: KETUA_RT',
                  prefixIcon: const Icon(Icons.title, color: Colors.black45),
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
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                        String newRole = roleController.text
                            .trim()
                            .toUpperCase()
                            .replaceAll(' ', '_');
                        if (newRole.isEmpty) return;

                        if (_roles.contains(newRole)) {
                          CustomToast.show(context, 'Jabatan sudah ada!');
                          return;
                        }

                        setState(() {
                          _roles.add(newRole);
                        });

                        await _saveRolesToServer();
                        if (context.mounted) {
                          CustomToast.show(context, 'Jabatan berhasil disimpan');
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
  }

  void _deleteRole(String role) async {
    if (_protectedRoles.contains(role)) {
      CustomToast.show(context, 'Jabatan $role adalah jabatan sistem dan tidak bisa dihapus!',);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppModalDialog(
          title: 'Konfirmasi Hapus',
          headerIcon: Icons.delete,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Apakah Anda yakin ingin menghapus jabatan $role? (Catatan: Hak akses pada menu juga akan hilang)',
              ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(color: Colors.white),
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

    if (confirm == true) {
      setState(() {
        _roles.remove(role);
      });
      await _saveRolesToServer();
      if (mounted) CustomToast.show(context, 'Jabatan berhasil dihapus');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomGradientAppBar(
        titleText: 'Manajemen Jabatan',
        actions: [
          if (widget.permissions['create'] == true)
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: Colors.white,
                size: 28,
              ),
              onPressed: _isLoading ? null : _showAddRoleDialog,
              tooltip: 'Tambah Jabatan',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isProtected = _protectedRoles.contains(role);

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isProtected
                                ? [Colors.red.shade400, Colors.red.shade700]
                                : [
                                    AppTheme.primaryColor,
                                    AppTheme.secondaryColor,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isProtected
                                          ? Colors.red
                                          : AppTheme.primaryColor)
                                      .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isProtected ? Icons.security : Icons.badge,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        role,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isProtected
                            ? "Jabatan Sistem (Dilindungi)"
                            : "Jabatan Kustom",
                      ),
                      trailing: isProtected
                          ? const Icon(Icons.lock, color: Colors.grey)
                          : (widget.permissions['delete'] == true
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteRole(role),
                                    tooltip: 'Hapus Jabatan',
                                  )
                                : null),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
