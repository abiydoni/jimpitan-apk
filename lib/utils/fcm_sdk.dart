import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/main.dart'; // Import navigatorKey
import 'package:jimpitan/pages/chat_room_page.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class FCMSDK {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static StreamSubscription? _tokenSubscription;
  static bool _hasRequestedPermission = false;

  /// Inisialisasi FCM dan mendengarkan pesan masuk
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint("FCM Push Notifications diabaikan di Web.");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _hasRequestedPermission =
          prefs.getBool('fcm_permission_requested') ?? false;

      if (!_hasRequestedPermission) {
        await _requestPermission();
        await prefs.setBool('fcm_permission_requested', true);
      }

      // Inisialisasi local notifications untuk Android Heads-up
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
          );
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final data = json.decode(response.payload!);
              _handleNotificationClick(data);
            } catch (e) {
              debugPrint("Error parsing notification payload: $e");
            }
          }
        },
      );

      // Konfigurasi channel untuk Android agar notifikasi muncul popup saat foreground DAN background
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', // id - harus sama dengan yang di FCM backend
        'Notifikasi Jimpitan',
        description:
            'Notifikasi chat dan aktivitas penting dari aplikasi Jimpitan.',
        importance: Importance.max, // MAX agar muncul popup (heads-up)
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF6366F1),
      );

      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        try {
          await androidPlugin.deleteNotificationChannel('high_importance_channel');
        } catch (_) {}
        await androidPlugin.createNotificationChannel(channel);
      }

      // Subscribe to 'all' topic for group chat broadcasts
      await FirebaseMessaging.instance.subscribeToTopic('all');

      // Set foreground presentation options untuk iOS
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // Dengarkan pesan masuk saat aplikasi berada di foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;

        if (notification != null) {
          _flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'Notifikasi Jimpitan',
                channelDescription:
                    'Notifikasi chat dan aktivitas penting dari aplikasi Jimpitan.',
                icon: 'ic_notification',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
                fullScreenIntent: false,
                ticker: notification.title,
              ),
            ),
            payload: json.encode(message.data),
          );
        }
      });

      // Dengarkan klik notifikasi saat aplikasi berjalan di background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message.data);
      });

      // Cek apakah aplikasi dibuka melalui notifikasi dari status TERMINATED
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          // Delay sedikit memastikan navigatorKey siap
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationClick(message.data);
          });
        }
      });
    } catch (e) {
      debugPrint("Gagal menginisialisasi FCM: $e");
    }
  }

  static void _handleNotificationClick(Map<String, dynamic> data) async {
    if (data['action'] == 'OPEN_CHAT') {
      // Tunggu sampai FirebaseAuth siap (jika dibuka dari terminated state)
      User? currentUser = FirebaseAuth.instance.currentUser;
      int retries = 0;
      while (currentUser == null && retries < 15) {
        await Future.delayed(const Duration(milliseconds: 200));
        currentUser = FirebaseAuth.instance.currentUser;
      }

      final String? senderUid = data['senderUid'];
      final String? senderName = data['senderName'];
      final String villageId = data['villageId'] ?? '';
      final String roomId = data['roomId'] ?? '';
      final String roomName = data['roomName'] ?? senderName ?? 'Chat';

      // Untuk personal chat, senderUid wajib ada. Untuk grup, roomId wajib ada.
      if (villageId.isNotEmpty &&
          (senderUid != null || roomId.isNotEmpty) &&
          navigatorKey.currentState != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        String resolvedRoomId = roomId;

        if (resolvedRoomId.isEmpty && currentUser != null) {
          final uids = [currentUser.uid, senderUid];
          uids.sort();
          resolvedRoomId = 'PERSONAL_${uids[0]}_${uids[1]}';
        }

        if (resolvedRoomId.isNotEmpty) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(
                villageId: villageId,
                roomId: resolvedRoomId, // Akan berisi ID personal atau grup
                roomName: roomName,
                targetUid: resolvedRoomId.startsWith('PERSONAL_')
                    ? senderUid
                    : null,
              ),
            ),
          );
        }
      }
    }
  }

  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  /// Mendapatkan token FCM dan menyimpannya di dokumen user
  static Future<void> saveTokenToDatabase(String uid) async {
    if (kIsWeb) return;

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        // Panggil API untuk menyimpan token ke database MySQL
        await ApiService.updateFcmToken(uid, token);
      }

      // Batalkan listener token sebelumnya jika ada
      await _tokenSubscription?.cancel();

      // Dengarkan refresh token
      _tokenSubscription = _firebaseMessaging.onTokenRefresh.listen(
        (newToken) {
          // Panggil API untuk memperbarui token di database MySQL
          ApiService.updateFcmToken(uid, newToken);
        },
        onError: (err) {
          debugPrint("Error on token refresh: $err");
        },
      );
    } catch (e) {
      debugPrint("Gagal menyimpan FCM token: $e");
    }
  }

  /// Menghapus token saat user logout
  static Future<void> logout(String uid) async {
    if (kIsWeb) return;
    // Berhenti mendengarkan pembaruan token saat logout
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    try {
      // Panggil API untuk menghapus token dari database MySQL
      await ApiService.removeFcmToken(uid);
    } catch (e) {
      debugPrint("Gagal menghapus FCM token: $e");
    }
  }
}
