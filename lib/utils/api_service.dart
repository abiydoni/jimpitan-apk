import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // URL bisa diubah saat build tanpa edit kode:
  // flutter build apk --dart-define=API_URL=https://api.namadomain.com/api
  static const String _customUrl = String.fromEnvironment('API_URL');

  static String get baseUrl {
    // Jika URL di-set saat build, gunakan itu (untuk semua platform)
    if (_customUrl.isNotEmpty) {
      return _customUrl;
    }

    if (kIsWeb) {
      return 'https://jimpitan-server.appsbee.my.id/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'https://jimpitan-server.appsbee.my.id/api';
    }

    return 'https://jimpitan-server.appsbee.my.id/api';
  }

  /// Notifier global jika subscription expired
  static final ValueNotifier<bool> isSuspendedNotifier = ValueNotifier<bool>(
    false,
  );

  /// Helper untuk mendapatkan header otentikasi dengan Firebase Auth ID Token
  static Future<Map<String, String>> _getHeaders() async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $idToken',
    };
  }

  static void _checkResponse(http.Response response) {
    if (response.statusCode == 403) {
      try {
        final body = json.decode(response.body);
        if (body['code'] == 'SUBSCRIPTION_SUSPENDED') {
          isSuspendedNotifier.value = true;
        }
      } catch (_) {}
    }
  }

  static Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    Uri finalUrl = url;
    final Map<String, dynamic> queryParams = Map<String, dynamic>.from(url.queryParameters);
    queryParams['_t'] = DateTime.now().millisecondsSinceEpoch.toString();
    finalUrl = url.replace(queryParameters: queryParams);
    
    final Map<String, String> finalHeaders = headers ?? {};
    finalHeaders['Cache-Control'] = 'no-cache, no-store, must-revalidate';
    finalHeaders['Pragma'] = 'no-cache';
    finalHeaders['Expires'] = '0';

    final res = await http.get(finalUrl, headers: finalHeaders.isNotEmpty ? finalHeaders : null);
    _checkResponse(res);
    return res;
  }

  static Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final res = await http.post(url, headers: headers, body: body);
    _checkResponse(res);
    return res;
  }

  static Future<http.Response> _put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final res = await http.put(url, headers: headers, body: body);
    _checkResponse(res);
    return res;
  }

  static Future<http.Response> _delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final res = await http.delete(url, headers: headers);
    _checkResponse(res);
    return res;
  }

  static Future<List<dynamic>> getMenus() async {
    try {
      final response = await _get(Uri.parse('$baseUrl/master/menus'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting menus: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getSlides(String villageId) async {
    try {
      final response = await _get(Uri.parse('$baseUrl/master/slides?villageId=$villageId'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting slides: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/master/users/$uid'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> loginSync(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/auth/login-sync'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> resData = json.decode(response.body);
        if (resData['success'] == true) {
          return resData['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error login sync: $e');
      return null;
    }
  }

  /// Cek versi terbaru app dari server.
  /// Endpoint ini tidak memerlukan autentikasi.
  static Future<Map<String, dynamic>?> checkAppVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/config/version'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking app version: $e');
      return null;
    }
  }

  static final Map<String, List<dynamic>> _usersCache = {};

  static Future<List<dynamic>> getUsers(
    String villageId, [
    String? status,
  ]) async {
    final cacheKey = '$villageId${status != null ? '_$status' : ''}';
    try {
      String url = '$baseUrl/master/users?villageId=$villageId';
      if (status != null) {
        url += '&status=$status';
      }
      final response = await _get(
        Uri.parse(url),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> users = data['data'] ?? [];
          _usersCache[cacheKey] = List<dynamic>.from(users);
          return users;
        }
      }
      if (_usersCache.containsKey(cacheKey) && _usersCache[cacheKey]!.isNotEmpty) {
        debugPrint('Server status ${response.statusCode}, returning cached users for $cacheKey.');
        return _usersCache[cacheKey]!;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting users: $e');
      if (_usersCache.containsKey(cacheKey) && _usersCache[cacheKey]!.isNotEmpty) {
        debugPrint('Network exception, returning cached users for $cacheKey.');
        return _usersCache[cacheKey]!;
      }
      return [];
    }
  }

  static Future<String> getCurrentCitizenName(String villageId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 'Warga';

    List<dynamic> users = _usersCache[villageId] ?? [];
    if (users.isEmpty) {
      users = await getUsers(villageId);
    }

    final currentLoggedUserData = users.cast<Map<String, dynamic>?>().firstWhere(
      (u) =>
          u != null &&
          (u['uid'] == currentUser.uid ||
              u['userUid'] == currentUser.uid ||
              u['email'] == currentUser.email),
      orElse: () => null,
    );

    if (currentLoggedUserData != null &&
        currentLoggedUserData['name'] != null &&
        currentLoggedUserData['name'].toString().isNotEmpty) {
      return currentLoggedUserData['name'];
    }

    return currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Warga';
  }

  static Future<Map<String, dynamic>?> claimAccount(
    String uid,
    String email,
    String nik,
    String villageId,
    String name,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/auth/claim-account'),
        body: {
          'uid': uid,
          'email': email,
          'nik': nik,
          'villageId': villageId,
          'name': name,
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error claiming account: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkVillageCode(String code) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/auth/village/$code'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking village code: $e');
      return null;
    }
  }

  static Future<bool> updateProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/auth/profile/$uid'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        final Map<String, dynamic> body = json.decode(response.body);
        throw Exception(body['message'] ?? 'Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<List<dynamic>> getVillages() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/master/villages'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> list = data['data'] ?? [];
          for (var village in list) {
            if (village != null && village['config'] is String) {
              try {
                var decoded = json.decode(village['config']);
                if (decoded is String) {
                  decoded = json.decode(decoded);
                }
                village['config'] = decoded;
              } catch (e) {
                debugPrint(
                  'Failed to decode config for village ${village['id']}: $e',
                );
                village['config'] = {};
              }
            }
          }
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting villages: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getVillage(String id) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/master/villages/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final village = data['data'];
          if (village != null && village['config'] is String) {
            try {
              var decoded = json.decode(village['config']);
              // Jika masih berupa String (double-encoded), decode lagi
              if (decoded is String) {
                decoded = json.decode(decoded);
              }
              village['config'] = decoded;
            } catch (e) {
              debugPrint(
                'Failed to decode config for village ${village['id']}: $e',
              );
              // Fallback to empty Map on error
              village['config'] = {};
            }
          }
          return village;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting village: $e');
      return null;
    }
  }

  static Future<bool> createVillage(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/villages'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating village: $e');
      return false;
    }
  }

  static Future<bool> updateVillage(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/master/villages/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating village: $e');
      return false;
    }
  }

  static Future<bool> saveUserFamily(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/users/family'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      if (response.statusCode != 200) {
        throw Exception('Status ${response.statusCode}: ${response.body}\nPayload: ${json.encode(data)}');
      }
      return true;
    } catch (e) {
      debugPrint('Error saving user family: $e');
      rethrow;
    }
  }

  static Future<bool> linkUserAccount(Map<String, dynamic> payload) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/users/link-account'),
        headers: await _getHeaders(),
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error linking user: $e');
      return false;
    }
  }

  static Future<String?> bulkImportUsers(
    String villageId,
    List<Map<String, dynamic>> users,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/users/bulk-import'),
        headers: await _getHeaders(),
        body: json.encode({'villageId': villageId, 'users': users}),
      );
      if (response.statusCode == 200) {
        return null; // success
      }
      try {
        final data = json.decode(response.body);
        return data['message'] ?? 'Error ${response.statusCode}';
      } catch (_) {
        return 'Terjadi kesalahan pada server (Error ${response.statusCode})';
      }
    } catch (e) {
      debugPrint('Error bulk importing users: $e');
      return e.toString();
    }
  }

  static Future<bool> deleteUserFamily(String familyId) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/master/users/family/$familyId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting user family: $e');
      return false;
    }
  }

  static Future<bool> deleteVillage(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/master/villages/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting village: $e');
      return false;
    }
  }

  static Future<bool> registerVillage(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/villages/register'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error registering village: $e');
      return false;
    }
  }

  // Dues & Jimpitan
  static Future<List<dynamic>> getTariffs(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/dues/tariffs/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting tariffs: $e');
      return [];
    }
  }

  static Future<bool> createTariff(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/dues/tariffs'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating tariff: $e');
      return false;
    }
  }

  static Future<bool> updateTariff(String id, Map<String, dynamic> data) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/dues/tariffs/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating tariff: $e');
      return false;
    }
  }

  static Future<bool> deleteTariff(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/dues/tariffs/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting tariff: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getExemptions(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/dues/exemptions/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting exemptions: $e');
      return [];
    }
  }

  static Future<bool> createExemption(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/dues/exemptions'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating exemption: $e');
      return false;
    }
  }

  static Future<bool> updateExemption(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/dues/exemptions/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating exemption: $e');
      return false;
    }
  }

  static Future<bool> deleteExemption(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/dues/exemptions/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting exemption: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getDuesJournals(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/dues/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting dues journals: $e');
      return [];
    }
  }

  static Future<bool> createDuesJournal(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/dues'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        debugPrint('createDuesJournal Failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error creating dues journal: $e');
      return false;
    }
  }

  static Future<bool> deleteDuesJournal(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/dues/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting dues journal: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getJimpitanHistory(String villageId) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await _get(
        Uri.parse('$baseUrl/dues/jimpitan/$villageId?_t=$ts'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting jimpitan history: $e');
      return [];
    }
  }

  static Future<bool> createJimpitanHistory(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/dues/jimpitan'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      if (response.statusCode != 201) {
        debugPrint('Error creating jimpitan history: ${response.statusCode} - ${response.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Exception creating jimpitan history: $e');
      return false;
    }
  }

  static Future<bool> deleteJimpitanHistory(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/dues/jimpitan/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting jimpitan history: $e');
      return false;
    }
  }

  // Inventory
  static Future<List<dynamic>> getInventoryItems(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/inventory/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting inventory items: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getInventoryLoans(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/inventory/loan/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting inventory loans: $e');
      return [];
    }
  }

  // Jadwal
  static Future<List<dynamic>> getSchedules(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/jadwal/$villageId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting schedules: $e');
      return [];
    }
  }

  static Future<bool> updateSchedule(
    String villageId,
    String nik,
    String namaLengkap,
    String? hari,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/jadwal/$villageId/$nik'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode({'namaLengkap': namaLengkap, 'hari': hari ?? ''}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating schedule: $e');
      return false;
    }
  }

  // Chat
  static Future<List<dynamic>> getChatContacts(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/chat/$villageId/users'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting chat contacts: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getMessages(
    String villageId,
    String targetUid,
    String uid, {
    String? roomId,
  }) async {
    try {
      // Jika roomId ada (grup), kirim sebagai query param agar backend menggunakan logika grup
      final isGroup = targetUid.startsWith('GROUP_');
      final roomIdParam = isGroup ? '&roomId=${roomId ?? targetUid}' : '';
      final response = await _get(
        Uri.parse('$baseUrl/chat/$villageId/messages/$targetUid?uid=$uid$roomIdParam'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  static Future<bool> sendMessage(
    String villageId,
    String senderUid,
    String? receiverUid,
    String message, {
    String? roomId,
    String? senderName,
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderName,
    bool isForwarded = false,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/chat/$villageId/messages'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode({
          'senderUid': senderUid,
          'receiverUid': receiverUid,
          'roomId': roomId,
          'senderName': senderName,
          'message': message,
          'replyToId': replyToId,
          'replyToMessage': replyToMessage,
          'replyToSenderName': replyToSenderName,
          'isForwarded': isForwarded,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return false;
    }
  }

  static Future<bool> updateMessage(
    String villageId,
    String messageId, {
    String? message,
    bool? isDeleted,
    bool? isEdited,
  }) async {
    final Map<String, dynamic> body = {};
    if (message != null) body['message'] = message;
    if (isDeleted != null) body['isDeleted'] = isDeleted;
    if (isEdited != null) body['isEdited'] = isEdited;

    try {
      final response = await _put(
        Uri.parse('$baseUrl/chat/$villageId/messages/$messageId'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating message: $e');
      return false;
    }
  }

  static Future<Map<String, int>> getUnreadCounts(
    String villageId,
    String uid,
  ) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/chat/$villageId/unread?uid=$uid'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final raw = data['data'] as Map<String, dynamic>;
          return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting unread counts: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getUnreadCountsAndDetails(
    String villageId,
    String uid,
  ) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/chat/$villageId/unread?uid=$uid'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final rawCounts = data['data'] as Map<String, dynamic>;
          final details = data['details'] as List<dynamic>? ?? [];
          return {
            'counts': rawCounts.map((k, v) => MapEntry(k, (v as num).toInt())),
            'details': details,
          };
        }
      }
      return {'counts': <String, int>{}, 'details': []};
    } catch (e) {
      debugPrint('Error getting unread details: $e');
      return {'counts': <String, int>{}, 'details': []};
    }
  }

  static Future<void> markMessagesRead(
    String villageId,
    String uid, {
    String? roomId,
    String? senderUid,
  }) async {
    try {
      await _post(
        Uri.parse('$baseUrl/chat/$villageId/mark-read'),
        headers: await _getHeaders(),
        body: json.encode({
          'uid': uid,
          if (roomId != null) ...{'roomId': roomId},
          if (senderUid != null) ...{'senderUid': senderUid},
        }),
      );
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  static Future<void> updateOnlineStatus(
    String uid, {
    required bool isOnline,
  }) async {
    try {
      await _put(
        Uri.parse('$baseUrl/master/users/$uid/online-status'),
        headers: await _getHeaders(),
        body: json.encode({'isOnline': isOnline}),
      );
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Inventory Mutations
  static Future<bool> createInventoryItem(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/inventory'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error creating inventory item: $e');
      return false;
    }
  }

  static Future<bool> updateInventoryItem(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/inventory/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      return false;
    }
  }

  static Future<bool> deleteInventoryItem(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/inventory/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      return false;
    }
  }

  static Future<bool> recordLoan(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/inventory/loan'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error recording loan: $e');
      return false;
    }
  }

  static Future<bool> returnLoan(
    String loanId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/inventory/loan/return/$loanId'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error returning loan: $e');
      return false;
    }
  }

  static Future<bool> cancelLoan(String loanId) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/inventory/loan/$loanId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error canceling loan: $e');
      return false;
    }
  }

  // Users & Master Data
  // getUsers is defined above

  static Future<bool> deleteUser(String familyId) async {
    try {
      // Menghapus familyId berarti menghapus semua user dalam keluarga tersebut
      final response = await _delete(
        Uri.parse('$baseUrl/master/users/family/$familyId'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  // Users & Master Mutations
  static Future<bool> updateUserStatus(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/master/users/$uid'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user status: $e');
      return false;
    }
  }

  static Future<bool> updateUserProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/auth/profile/$uid'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }

  static Future<bool> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/auth/register'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error registering user: $e');
      return false;
    }
  }

  static Future<bool> updateMenu(String id, Map<String, dynamic> data) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/master/menus/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating menu: $e');
      return false;
    }
  }

  static Future<bool> deleteMenu(String id) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/master/menus/$id'),
        headers: await _getHeaders(), // Amankan dengan token
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting menu: $e');
      return false;
    }
  }

  static Future<bool> createSlide(Map<String, dynamic> data) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/master/slides'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating slide: $e');
      return false;
    }
  }

  static Future<bool> updateSlide(String id, Map<String, dynamic> data) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/master/slides/$id'),
        headers: await _getHeaders(), // Amankan dengan token
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating slide: $e');
      return false;
    }
  }

  static Future<bool> deleteSlide(String id) async {
    try {
      final response = await _delete(Uri.parse('$baseUrl/master/slides/$id'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting slide: $e');
      return false;
    }
  }

  // [BARU] Metode untuk update FCM Token
  static Future<void> updateFcmToken(String uid, String token) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'fcmToken': token});
      final response = await _put(
        Uri.parse('$baseUrl/master/users/$uid/fcm-token'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        debugPrint('Gagal memperbarui FCM token di server: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error saat updateFcmToken: $e');
    }
  }

  // [BARU] Metode untuk menghapus FCM Token
  static Future<void> removeFcmToken(String uid) async {
    try {
      final headers = await _getHeaders();
      final response = await _delete(
        Uri.parse('$baseUrl/master/users/$uid/fcm-token'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        debugPrint('Gagal menghapus FCM token di server: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error saat removeFcmToken: $e');
    }
  }

  // Roles Management
  static Future<List<String>> getRoles(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/roles/$villageId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> roles = data['data'] ?? [];
          return roles.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting roles: $e');
      return [];
    }
  }

  static Future<bool> saveRoles(String villageId, List<String> roles) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/roles/$villageId'),
        headers: await _getHeaders(),
        body: json.encode({'roles': roles}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving roles: $e');
      return false;
    }
  }

  // Access Matrix
  static Future<Map<String, dynamic>?> getAccessMatrix(String villageId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/roles/matrix/$villageId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return {};
    } catch (e) {
      debugPrint('Error getting access matrix: $e');
      return {};
    }
  }

  static Future<bool> saveAccessMatrix(
    String villageId,
    Map<String, Map<String, Map<String, bool>>> permissions,
  ) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/roles/matrix/$villageId'),
        headers: await _getHeaders(),
        body: json.encode({'permissions': permissions}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving access matrix: $e');
      return false;
    }
  }

  // SaaS (Subscription & Invoice)
  static Future<Map<String, dynamic>?> getVillageSubscription(
    String villageId,
  ) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/saas/village-subscription/$villageId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting subscription: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getLatestInvoice(
    String villageId,
  ) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/saas/village/$villageId/invoices'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List invoices = data['data'];
          if (invoices.isNotEmpty) {
            return invoices[0]; // Return the latest invoice
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invoice: $e');
      return null;
    }
  }

  // --- NEW SAAS ENDPOINTS ---
  
  static Future<List<dynamic>> getPlans() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/saas/plans'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting plans: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> orderPlan(String villageId, int planId) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/saas/village/$villageId/invoices/order'),
        headers: await _getHeaders(),
        body: json.encode({'planId': planId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return data['data'];
        if (data['message'] != null) throw Exception(data['message']);
      } else {
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) throw Exception(data['message']);
        } catch (_) {}
        throw Exception('Status ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('Error ordering plan: $e');
      rethrow;
    }
  }

  static Future<bool> uploadPaymentProof(String invoiceId, String base64Proof) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/saas/invoices/$invoiceId/upload-proof'),
        headers: await _getHeaders(),
        body: json.encode({'paymentProof': base64Proof}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error uploading proof: $e');
      return false;
    }
  }

  static Future<String?> getSaasBankAccount() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/saas/settings'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final settings = data['data'] as List;
          final bankInfo = settings.firstWhere((s) => s['key'] == 'BANK_ACCOUNT_INFO', orElse: () => null);
          if (bankInfo != null) return bankInfo['value'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return null;
    }
  }

  static Future<num> getSaasTaxPercentage() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/saas/settings'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final settings = data['data'] as List;
          final taxInfo = settings.firstWhere((s) => s['key'] == 'TAX_PERCENTAGE', orElse: () => null);
          if (taxInfo != null && taxInfo['value'] != null) {
            return num.tryParse(taxInfo['value'].toString()) ?? 10;
          }
        }
      }
      return 10;
    } catch (e) {
      debugPrint('Error getting tax percentage: $e');
      return 10;
    }
  }
}
