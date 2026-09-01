import 'package:flutter/material.dart';
import 'package:jimpitan/models/menu_item.dart';
import 'package:jimpitan/utils/api_service.dart';

class MenuHelper {
  // Mapping dari String di Database ke IconData Flutter
  static final Map<String, IconData> _iconMap = {
    'qr_code_scanner': Icons.qr_code_scanner,
    'history': Icons.history,
    'bar_chart': Icons.bar_chart,
    'business': Icons.business,
    'admin_panel_settings': Icons.admin_panel_settings,
    'people': Icons.people,
    'badge': Icons.badge,
    'volunteer_activism': Icons.volunteer_activism,
    'monetization_on': Icons.monetization_on,
    'flag': Icons.flag,
    'security': Icons.security,
    'favorite': Icons.favorite,
    'settings': Icons.settings,
    'help_outline': Icons.help_outline,
    'info_outline': Icons.info_outline,
    'info': Icons.info,
    'account_balance': Icons.account_balance,
    'local_hospital': Icons.local_hospital,
    'attach_money': Icons.attach_money,
    'notifications': Icons.notifications,
    'event': Icons.event,
    'widgets': Icons.widgets,
    'home_filled': Icons.home_filled,
    'person': Icons.person,
    'forum': Icons.forum,
    'calendar_month': Icons.calendar_month,
    'inventory_2': Icons.inventory_2,
    'account_balance_wallet': Icons.account_balance_wallet,
    'book': Icons.book,
    'slideshow': Icons.slideshow,
    'edit_square': Icons.edit_square,
    // Tambahan sinkronisasi Backend
    'home': Icons.home,
    'payments': Icons.payments,
    'payments_outlined': Icons.payments_outlined,
    'savings': Icons.savings,
    'savings_outlined': Icons.savings_outlined,
    'assignment': Icons.assignment,
    'chat': Icons.chat,
    'warning': Icons.warning,
    'build': Icons.build,
    'store': Icons.store,
    'map': Icons.map,
    'article': Icons.article,
    'campaign': Icons.campaign,
    'health_and_safety': Icons.health_and_safety,
    'support_agent': Icons.support_agent,
    'dashboard': Icons.dashboard,
    'list': Icons.list,
  };

  static IconData getIcon(String iconName) {
    return _iconMap[iconName] ?? Icons.widgets; // Fallback icon
  }
  
  static String getIconName(IconData iconData) {
    return _iconMap.entries.firstWhere((e) => e.value == iconData, orElse: () => const MapEntry('widgets', Icons.widgets)).key;
  }

  static List<String> get availableIconNames => _iconMap.keys.toList();

  // Migrasi Otomatis (Akan menambahkan menu baru jika belum ada di database)
  static Future<void> checkAndMigrateMenus() async {
    final menusList = await ApiService.getMenus();
    final existingIds = menusList.map((m) => m['id'].toString()).toSet();
    
    bool hasNewMenu = false;
    
    int order = menusList.length + 1;
    for (var menu in appMenus) {
      bool needsUpdate = false;
      Map<String, dynamic>? data;
      
      if (!existingIds.contains(menu.id)) {
        needsUpdate = true;
      } else {
        data = menusList.firstWhere((m) => m['id'].toString() == menu.id);
        
        if (data?['label'] == null || data?['defaultRoles'] == null) {
          needsUpdate = true;
        }
        
        if (menu.id == 'settings' && data?['position'] != 'hidden') {
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        await ApiService.updateMenu(menu.id, {
          'id': menu.id,
          'label': data?['label'] ?? menu.label, // Pertahankan label yang ada jika ada
          'icon': data?['icon'] ?? getIconName(menu.icon), // Pertahankan icon yang ada jika ada
          'defaultRoles': data?['defaultRoles'] ?? menu.defaultRoles,
          'order': data?['order'] ?? order,
          'isActive': data?['isActive'] ?? true,
          'isCore': menu.isCore,
          'position': data?['position'] ?? menu.position,
        });
        order++;
        hasNewMenu = true;
      }
    }
    
    if (hasNewMenu) {
      debugPrint("Penambahan menu baru (Home/Profile/dll) selesai!");
    }
  }

  // Mengubah JSON/Map menjadi AppMenuItem (untuk backend API)
  static AppMenuItem fromJson(Map<String, dynamic> data) {
    return AppMenuItem(
      id: data['id']?.toString() ?? 'unknown',
      label: data['label'] ?? 'Unknown Menu',
      icon: getIcon(data['icon'] ?? 'widgets'),
      defaultRoles: data['defaultRoles'] != null ? List<String>.from(data['defaultRoles']) : [],
      isCore: data['isCore'] == true,
      position: data['position'] ?? 'grid',
    );
  }
}
