import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final double radius;
  final IconData defaultIcon;
  final double iconSize;

  const UserAvatar({
    super.key,
    required this.userData,
    this.radius = 20,
    this.defaultIcon = Icons.person,
    this.iconSize = 24,
  });

  static final Map<String, Uint8List> _base64Cache = {};

  /// Ambil huruf inisial dari data user
  String _getInitial() {
    if (userData == null) return '';
    String? name = userData!['name']?.toString();
    if (name == null || name.trim().isEmpty) name = userData!['nama']?.toString();
    if (name == null || name.trim().isEmpty) name = userData!['namaLengkap']?.toString();
    if (name != null && name.trim().isNotEmpty) {
      return name.trim().substring(0, 1).toUpperCase();
    }
    return '';
  }

  /// Widget fallback: inisial atau ikon default
  Widget _buildFallback() {
    final initial = _getInitial();
    if (initial.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.8,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(defaultIcon, size: iconSize, color: Colors.grey.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) return _buildFallback();

    // 1. Coba base64 foto (custom upload) — langsung pakai MemoryImage
    final foto = userData!['foto'];
    if (foto != null && foto.toString().isNotEmpty) {
      try {
        String base64Str = foto.toString();
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        if (!_base64Cache.containsKey(base64Str)) {
          _base64Cache[base64Str] = base64Decode(base64Str);
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: MemoryImage(_base64Cache[base64Str]!),
        );
      } catch (_) {
        // Lanjut ke fallback berikutnya
      }
    }

    // 2. Coba photoUrl (Google / Auth provider) — gunakan Image.network
    //    dengan errorBuilder agar gagal load -> tampil inisial, bukan abu-abu kosong
    final photoUrl = userData!['photoUrl'];
    if (photoUrl != null && photoUrl.toString().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            photoUrl.toString(),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallback();
            },
          ),
        ),
      );
    }

    // 3. Tidak ada foto sama sekali -> inisial / ikon
    return _buildFallback();
  }
}
