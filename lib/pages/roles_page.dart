import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_gradient_app_bar.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/models/menu_item.dart';
import 'package:jimpitan/utils/menu_helper.dart';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:jimpitan/utils/custom_toast.dart';

class RolesPage extends StatefulWidget {
  final Map<String, bool> permissions;
  final String villageId;
  final List<String> currentUserRoles;
  const RolesPage({
    super.key,
    required this.permissions,
    required this.villageId,
    required this.currentUserRoles,
  });

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  String get _currentVillageId => widget.villageId;

  List<String> _availableRoles = ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'];
  List<String> _managedRoles = [];
  Map<String, Map<String, Map<String, bool>>> _menuPermissions = {};
  List<dynamic> _tariffs = [];
  Map<String, Map<String, bool>> _tariffPermissions = {};
  List<AppMenuItem> _dynamicMenus = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final villageData = await ApiService.getVillage(_currentVillageId);
      final config = villageData?['config'] as Map<String, dynamic>? ?? {};

      // Ambil daftar role kustom dari backend
      final customRoles = await ApiService.getRoles(_currentVillageId);
      
      // Gabungkan peran default dan kustom
      Set<String> allRoles = {'SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'};
      allRoles.addAll(customRoles);
      
      _availableRoles = allRoles.toList();

      // Atur role yang akan ditampilkan berdasarkan hak akses pengguna
      if (widget.currentUserRoles.contains('SUPER_ADMIN')) {
        // Super Admin melihat SEMUA jabatan
        _managedRoles = _availableRoles.toList();
      } else if (widget.currentUserRoles.contains('ADMIN_DESA')) {
        // Admin Desa tidak boleh mengatur Super Admin dan tidak boleh mengatur dirinya sendiri
        _managedRoles = _availableRoles.where((r) => r != 'SUPER_ADMIN' && r != 'ADMIN_DESA').toList();
      } else {
        _managedRoles = [];
      }

      // Ambil daftar iuran
      _tariffs = await ApiService.getTariffs(_currentVillageId);

      // Parse tariffPermissions
      final rawTariffPerms = config['tariffPermissions'] as Map<String, dynamic>? ?? {};
      _tariffPermissions = {};
      for (var t in _tariffs) {
        final tId = t['id'].toString();
        _tariffPermissions[tId] = {};
        
        final existingForTariff = rawTariffPerms[tId] as Map<String, dynamic>? ?? {};
        
        for (var role in _availableRoles) {
          if (existingForTariff.containsKey(role)) {
            _tariffPermissions[tId]![role] = existingForTariff[role] == true;
          } else {
            // Jika kosong/belum di-set, default = true (semua bisa akses jika diizinkan di menu iuran)
            _tariffPermissions[tId]![role] = true;
          }
        }
      }

      final menusList = await ApiService.getMenus();
      if (menusList.isNotEmpty) {
        _dynamicMenus = menusList
            .map((m) => MenuHelper.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
      } else {
        _dynamicMenus = appMenus.toList();
      }

      final rawPermissions = config['menuPermissions'] as Map<String, dynamic>? ?? {};

      _menuPermissions = {};
      for (var menu in _dynamicMenus) {
        _menuPermissions[menu.id] = {};
        for (var role in _availableRoles) {
          Map? existingRoleMap;
          if (rawPermissions[menu.id] is Map) {
            existingRoleMap = rawPermissions[menu.id] as Map;
          } else if (rawPermissions[menu.id] is List) {
            // Format lama: List of roles yang punya akses 'view'
            List legacyList = rawPermissions[menu.id] as List;
            existingRoleMap = {};
            for (var r in _availableRoles) {
               bool hasLegacyView = legacyList.contains(r);
               bool isSuper = r == 'SUPER_ADMIN';
               bool isAdmin = r == 'ADMIN_DESA';
               existingRoleMap[r] = {
                 'view': hasLegacyView,
                 'create': isSuper || isAdmin,
                 'edit': isSuper || isAdmin,
                 'delete': isSuper,
               };
            }
          }

          Map? existing;
          if (existingRoleMap != null && existingRoleMap[role] is Map) {
            existing = existingRoleMap[role] as Map;
          }

          if (existing == null) {
            // Gunakan nilai acuan dari defaultRoles menu (tabel menu) jika jabatan belum ada di matriks
            List<String> defRoles = menu.defaultRoles.isNotEmpty
                ? menu.defaultRoles
                : appMenus.firstWhere(
                    (am) => am.id == menu.id,
                    orElse: () => menu,
                  ).defaultRoles;
            bool hasView = defRoles.contains(role);
            bool isSuperAdmin = role == 'SUPER_ADMIN';
            bool isAdminDesa = role == 'ADMIN_DESA';
            
            _menuPermissions[menu.id]![role] = {
              'view': hasView,
              'create': isSuperAdmin || isAdminDesa,
              'edit': isSuperAdmin || isAdminDesa,
              'delete': isSuperAdmin,
            };
          } else {
            _menuPermissions[menu.id]![role] = {
              'view': existing['view'] == true,
              'create': existing['create'] == true,
              'edit': existing['edit'] == true,
              'delete': existing['delete'] == true,
            };
          }
        }
      }

      // Logika untuk menyaring menu berdasarkan hak akses pengguna saat ini
      if (!widget.currentUserRoles.contains('SUPER_ADMIN')) {
        _dynamicMenus.removeWhere((menu) {
          bool hasAccess = false;
          for (var role in widget.currentUserRoles) {
            if (_menuPermissions[menu.id]?[role]?['view'] == true) {
              hasAccess = true;
              break;
            }
          }
          return !hasAccess;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Gagal memuat matriks akses: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePermissions() async {
    EasyLoading.show(status: 'Menyimpan...');
    try {
      await _savePermissionsSilent();
      if (mounted) {
        CustomToast.show(context, 'Matriks Akses Menu Berhasil Disimpan!');
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _savePermissionsSilent([
    Map<String, Map<String, Map<String, bool>>>? permissionsToSave,
  ]) async {
    final perms = permissionsToSave ?? _menuPermissions;
    final villageData = await ApiService.getVillage(_currentVillageId);
    if (villageData != null) {
      final config = villageData['config'] as Map<String, dynamic>? ?? {};
      config['menuPermissions'] = perms;
      config['tariffPermissions'] = _tariffPermissions;
      await ApiService.updateVillage(_currentVillageId, {
        'config': config,
      });
    }
  }


  void _updatePermission(
    String menuId,
    String role,
    String action,
    bool value,
  ) {
    setState(() {
      _menuPermissions[menuId]![role]![action] = value;

      if (action == 'view' && value == false) {
        _menuPermissions[menuId]![role]!['create'] = false;
        _menuPermissions[menuId]![role]!['edit'] = false;
        _menuPermissions[menuId]![role]!['delete'] = false;
      }

      if ((action == 'create' || action == 'edit' || action == 'delete') &&
          value == true) {
        _menuPermissions[menuId]![role]!['view'] = true;
      }
    });

    // Auto-save ke Firebase secara diam-diam (background)
    _savePermissionsSilent();
  }

  // Fungsi untuk mengecek status header kolom (true / false / null (sebagian))
  bool? _getColumnState(String role, String action) {
    if (_dynamicMenus.isEmpty) return false;

    int trueCount = 0;
    for (var menu in _dynamicMenus) {
      if (_menuPermissions[menu.id]?[role]?[action] == true) {
        trueCount++;
      }
    }
    if (trueCount == 0) return false;
    if (trueCount == _dynamicMenus.length) return true;
    return null; // Tristate (sebagian tercentang akan jadi bentuk kotak/garis)
  }

  // Fungsi untuk toggle semua baris dalam satu kolom
  void _toggleColumn(String role, String action) {
    final currentState = _getColumnState(role, action);
    // Jika semua true, maka jadikan false. Jika sebagian (null) atau false, jadikan true.
    final bool nextValue = (currentState == true) ? false : true;

    setState(() {
      for (var menu in _dynamicMenus) {
        _menuPermissions[menu.id]![role]![action] = nextValue;

        // Aplikasikan logika cerdas yang sama
        if (action == 'view' && nextValue == false) {
          _menuPermissions[menu.id]![role]!['create'] = false;
          _menuPermissions[menu.id]![role]!['edit'] = false;
          _menuPermissions[menu.id]![role]!['delete'] = false;
        }

        if ((action == 'create' || action == 'edit' || action == 'delete') &&
            nextValue == true) {
          _menuPermissions[menu.id]![role]!['view'] = true;
        }
      }
    });

    // Auto-save ke Firebase secara diam-diam (background)
    _savePermissionsSilent();
  }

  Widget _buildHeaderCheckbox(String label, String role, String action) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        SizedBox(
          height: 32,
          child: Checkbox(
            tristate: true,
            value: _getColumnState(role, action),
            onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                ? (val) => _toggleColumn(role, action)
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomGradientAppBar(
        titleText: 'Matriks Akses Menu',
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Simpan',
            onPressed: _isLoading ? null : _savePermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _managedRoles.length,
              itemBuilder: (context, index) {
                final role = _managedRoles[index];

                int allowedMenusCount = 0;
                for (var menu in _dynamicMenus) {
                  if (_menuPermissions[menu.id]?[role]?['view'] == true) {
                    allowedMenusCount++;
                  }
                }

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
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        role,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Akses ke $allowedMenusCount Menu",
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 64,
                            columnSpacing: 16,
                            columns: [
                              const DataColumn(
                                label: Text(
                                  'Menu',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: _buildHeaderCheckbox(
                                  'View',
                                  role,
                                  'view',
                                ),
                              ),
                              DataColumn(
                                label: _buildHeaderCheckbox(
                                  'Create',
                                  role,
                                  'create',
                                ),
                              ),
                              DataColumn(
                                label: _buildHeaderCheckbox(
                                  'Edit',
                                  role,
                                  'edit',
                                ),
                              ),
                              DataColumn(
                                label: _buildHeaderCheckbox(
                                  'Delete',
                                  role,
                                  'delete',
                                ),
                              ),
                            ],
                            rows: _dynamicMenus.expand((menu) {
                              // Cek null safety jika menu baru dibuat tapi matrix lama belum punya data
                              final actions =
                                  _menuPermissions[menu.id]?[role] ??
                                  {
                                    'view': false,
                                    'create': false,
                                    'edit': false,
                                    'delete': false,
                                  };
                                  
                              final menuRow = DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Icon(
                                          menu.icon,
                                          size: 16,
                                          color: Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          menu.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Checkbox(
                                      value: actions['view'],
                                      onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                                          ? (val) => _updatePermission(
                                              menu.id,
                                              role,
                                              'view',
                                              val ?? false,
                                            )
                                          : null,
                                    ),
                                  ),
                                  DataCell(
                                    Checkbox(
                                      value: actions['create'],
                                      onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                                          ? (val) => _updatePermission(
                                              menu.id,
                                              role,
                                              'create',
                                              val ?? false,
                                            )
                                          : null,
                                    ),
                                  ),
                                  DataCell(
                                    Checkbox(
                                      value: actions['edit'],
                                      onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                                          ? (val) => _updatePermission(
                                              menu.id,
                                              role,
                                              'edit',
                                              val ?? false,
                                            )
                                          : null,
                                    ),
                                  ),
                                  DataCell(
                                    Checkbox(
                                      value: actions['delete'],
                                      onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                                          ? (val) => _updatePermission(
                                              menu.id,
                                              role,
                                              'delete',
                                              val ?? false,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                              final List<DataRow> rows = [menuRow];
                              
                              if (menu.id == 'iuran' && actions['view'] == true) {
                                for (var tariff in _tariffs) {
                                  final tId = tariff['id'].toString();
                                  final tName = tariff['name'] ?? 'Tanpa Nama';
                                  final hasAccess = _tariffPermissions[tId]?[role] ?? false;
                                  
                                  rows.add(
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Padding(
                                            padding: const EdgeInsets.only(left: 24.0),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(tName, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Checkbox(
                                            value: hasAccess,
                                            onChanged: (widget.permissions['edit'] == true || widget.currentUserRoles.contains('SUPER_ADMIN'))
                                                ? (val) {
                                                    setState(() {
                                                      _tariffPermissions[tId] ??= {};
                                                      _tariffPermissions[tId]![role] = val ?? false;
                                                    });
                                                  }
                                                : null,
                                            activeColor: AppTheme.secondaryColor,
                                          ),
                                        ),
                                        const DataCell(Text('')), // Kosong untuk create
                                        const DataCell(Text('')), // Kosong untuk edit
                                        const DataCell(Text('')), // Kosong untuk delete
                                      ],
                                    ),
                                  );
                                }
                              }
                              
                              return rows;
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
