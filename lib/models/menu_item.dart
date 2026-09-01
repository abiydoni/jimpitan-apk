import 'package:flutter/material.dart';

class AppMenuItem {
  final String id;
  final IconData icon;
  final String label;
  final List<String> defaultRoles;
  final bool isCore;
  final String position;

  AppMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.defaultRoles,
    this.isCore = false,
    this.position = 'grid',
  });
}

// Data statis untuk daftar menu master (Hak akses aslinya akan dibaca dari MySQL/Backend)
final List<AppMenuItem> appMenus = [
  AppMenuItem(
    id: 'scan',
    icon: Icons.qr_code_scanner,
    label: "Scan Jimpitan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'],
    position: 'hidden', // Hanya muncul sebagai FAB, tidak di grid
    isCore: true,
  ),
  AppMenuItem(
    id: 'history',
    icon: Icons.history,
    label: "Riwayat",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'],
    position: 'footer',
  ),
  AppMenuItem(
    id: 'report',
    icon: Icons.bar_chart,
    label: "Laporan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
    position: 'footer',
  ),
  AppMenuItem(
    id: 'chat',
    icon: Icons.forum,
    label: "Obrolan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'],
  ),
  AppMenuItem(
    id: 'villages',
    icon: Icons.business,
    label: "Manajemen Desa",
    defaultRoles: ['SUPER_ADMIN'],
    isCore: true,
  ),
  AppMenuItem(
    id: 'menus',
    icon: Icons.admin_panel_settings,
    label: "Matriks Akses",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
    isCore: true,
  ),
  AppMenuItem(
    id: 'menu_master',
    icon: Icons.widgets,
    label: "Manajemen Menu",
    defaultRoles: ['SUPER_ADMIN'],
    isCore: true,
  ),
  AppMenuItem(
    id: 'home',
    icon: Icons.home_filled,
    label: "Beranda",
    defaultRoles: [
      'SUPER_ADMIN',
      'ADMIN_DESA',
      'WARGA',
      'STAFF_SOSIAL',
      'PANITIA_17AN',
    ],
    isCore: true,
    position: 'footer',
  ),
  AppMenuItem(
    id: 'profile',
    icon: Icons.person,
    label: "Profil",
    defaultRoles: [
      'SUPER_ADMIN',
      'ADMIN_DESA',
      'WARGA',
      'STAFF_SOSIAL',
      'PANITIA_17AN',
    ],
    isCore: true,
    position: 'footer',
  ),
  AppMenuItem(
    id: 'users',
    icon: Icons.people,
    label: "Data Warga",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
    isCore: true,
  ),
  AppMenuItem(
    id: 'manage_roles',
    icon: Icons.badge,
    label: "Manajemen Jabatan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
    isCore: true,
  ),
  AppMenuItem(
    id: 'jadwal',
    icon: Icons.calendar_month,
    label: "Jadwal Jaga",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),

  AppMenuItem(
    id: 'tariffs',
    icon: Icons.attach_money,
    label: "Manajemen Tarif",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
  AppMenuItem(
    id: 'inventory',
    icon: Icons.inventory_2,
    label: "Inventaris RT",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA', 'PENGURUS_INVENTORY'],
  ),
  AppMenuItem(
    id: 'iuran',
    icon: Icons.account_balance_wallet,
    label: "Iuran Warga",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
  AppMenuItem(
    id: 'journals',
    icon: Icons.book,
    label: "Buku Kas",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
  AppMenuItem(
    id: 'slides',
    icon: Icons.slideshow,
    label: "Manajemen Slideshow",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
  AppMenuItem(
    id: 'exemptions',
    icon: Icons.person_off_outlined,
    label: "Pembebasan Iuran",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),

  AppMenuItem(
    id: 'settings',
    icon: Icons.settings,
    label: "Pengaturan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'],
    position: 'hidden',
  ),
  AppMenuItem(
    id: 'help',
    icon: Icons.help_outline,
    label: "Bantuan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA', 'WARGA'],
  ),
  AppMenuItem(
    id: 'about',
    icon: Icons.info_outline,
    label: "Tentang Aplikasi",
    defaultRoles: [
      'SUPER_ADMIN',
      'ADMIN_DESA',
      'WARGA',
      'STAFF_SOSIAL',
      'PANITIA_17AN',
      'PENGURUS_INVENTORY'
    ],
  ),
  AppMenuItem(
    id: 'scan_manual',
    icon: Icons.edit_square,
    label: "Scan Manual",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
  AppMenuItem(
    id: 'setor_jimpitan',
    icon: Icons.savings_outlined,
    label: "Setor Jimpitan",
    defaultRoles: ['SUPER_ADMIN', 'ADMIN_DESA'],
  ),
];
