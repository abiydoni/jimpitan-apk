import 'package:jimpitan/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'dart:convert';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'package:jimpitan/models/menu_item.dart';
import 'package:jimpitan/pages/users_page.dart';
import 'package:jimpitan/pages/villages_page.dart';
import 'package:jimpitan/pages/manage_roles_page.dart';
import 'package:jimpitan/pages/roles_page.dart';
import 'package:jimpitan/pages/login_page.dart';
import 'package:jimpitan/pages/menus_page.dart';
import 'package:jimpitan/pages/profile_page.dart';
import 'package:jimpitan/pages/scan_page.dart';
import 'package:jimpitan/widgets/subscription_banner.dart';
import 'package:jimpitan/widgets/user_avatar.dart';
import 'package:jimpitan/pages/tariffs_page.dart';
import 'package:jimpitan/pages/dues_page.dart';
import 'package:jimpitan/pages/financial_journals_page.dart';
import 'package:jimpitan/pages/settings_page.dart';
import 'package:jimpitan/pages/bill_detail_page.dart';
import 'package:jimpitan/pages/scan_report_page.dart';
import 'package:jimpitan/pages/manual_scan_page.dart';
import 'package:jimpitan/pages/reports_page.dart';
import 'package:jimpitan/widgets/pulse_badge.dart';
import 'package:jimpitan/pages/chat_room_page.dart';
import 'package:jimpitan/pages/village_registration_page.dart';
import 'package:jimpitan/pages/join_village_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:jimpitan/utils/menu_helper.dart';
import 'package:jimpitan/pages/jadwal_page.dart';
import 'package:jimpitan/pages/slides_page.dart';
import 'package:jimpitan/pages/help_page.dart';
import 'package:jimpitan/pages/about_page.dart';
import 'package:jimpitan/pages/exemptions_page.dart';
import 'package:jimpitan/pages/chat_page.dart';
import 'package:jimpitan/pages/inventory_page.dart';
import 'package:jimpitan/pages/setor_jimpitan_page.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jimpitan/utils/fcm_sdk.dart';
import 'package:jimpitan/pages/subscription_suspended_page.dart';

import 'package:jimpitan/utils/api_service.dart';
import 'package:jimpitan/utils/custom_toast.dart';
import 'package:jimpitan/utils/update_checker.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } else {
      // Coba silent login Google jika session Firebase hilang di Android (bug cache)
      if (FirebaseAuth.instance.currentUser == null) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(
            serverClientId:
                '230006065254-4qbk0vee5limtfve7lajnbmpdunvmjpg.apps.googleusercontent.com',
          );
          if (await googleSignIn.isSignedIn()) {
            final GoogleSignInAccount? googleUser = await googleSignIn
                .signInSilently();
            if (googleUser != null) {
              final GoogleSignInAuthentication googleAuth =
                  await googleUser.authentication;
              final AuthCredential credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await FirebaseAuth.instance.signInWithCredential(credential);
            }
          }
        } catch (e) {
          debugPrint('Silent login failed: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Konfigurasi global EasyLoading
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.cubeGrid
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..progressColor = AppTheme.primaryColor
    ..backgroundColor = Colors.transparent
    ..boxShadow = <BoxShadow>[]
    ..indicatorColor = AppTheme.primaryColor
    ..textColor = AppTheme.primaryColor
    ..maskColor = Colors.white.withValues(alpha: 0.7)
    ..userInteractions = false
    ..dismissOnTap = false;

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('DateFormatting init failed: $e');
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            "ERROR:\n${details.exceptionAsString()}\n\nSTACK:\n${details.stack?.toString() ?? ''}",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  };

  runApp(const AplikasiJimpitan());
}

class AplikasiJimpitan extends StatefulWidget {
  const AplikasiJimpitan({super.key});

  @override
  State<AplikasiJimpitan> createState() => _AplikasiJimpitanState();
}

class _AplikasiJimpitanState extends State<AplikasiJimpitan> {
  @override
  void initState() {
    super.initState();
    ApiService.isSuspendedNotifier.addListener(() {
      if (ApiService.isSuspendedNotifier.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const SubscriptionSuspendedPage(),
            ),
            (route) => false,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.primaryColorNotifier,
      builder: (context, themeColor, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [routeObserver],
          title: 'Jimpitan Digital',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeColor,
              primary: themeColor,
            ),
            scaffoldBackgroundColor: const Color(
              0xFFF5F7FA,
            ), // Background abu-abu premium
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF1E293B),
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              titleTextStyle: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: IconThemeData(color: Color(0xFF1E293B)),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              titleTextStyle: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: Color(0xFF475569),
                fontSize: 16,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
              },
            ),
          ),
          builder: EasyLoading.init(),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData && snapshot.data != null) {
                return AuthWrapper(user: snapshot.data!);
              }
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final User user;
  const AuthWrapper({super.key, required this.user});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<Map<String, dynamic>?> _userFuture;
  late Future<SharedPreferences> _prefsFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = ApiService.getUser(widget.user.uid);
    _prefsFuture = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          // Error jaringan / server — tampilkan opsi keluar
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal terhubung ke server.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _userFuture = ApiService.getUser(widget.user.uid);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        final status = data?['status']?.toString();

        // Jika data null (user baru / belum ada di database), perlakukan sebagai INCOMPLETE
        if (data == null || status == 'INCOMPLETE') {
          return FutureBuilder<SharedPreferences>(
            future: _prefsFuture,
            builder: (context, prefsSnapshot) {
              if (prefsSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final intent =
                  prefsSnapshot.data?.getString('auth_intent') ?? 'LOGIN';
              if (intent == 'REGISTER_VILLAGE') {
                return const VillageRegistrationPage();
              } else {
                // LOGIN atau REGISTER_CITIZEN → arahkan ke form gabung desa
                return const JoinVillagePage();
              }
            },
          );
        } else if (status == 'PENDING') {
          return const PendingApprovalPage();
        } else {
          data['docId'] = data['uid'];
          final villageId = data['villageId'] as String?;
          if (villageId == null || villageId.isEmpty) {
            return DashboardPage(userData: data);
          }
          return VillageStatusChecker(villageId: villageId, userData: data);
        }
      },
    );
  }
}

class VillageStatusChecker extends StatefulWidget {
  final String villageId;
  final Map<String, dynamic> userData;

  const VillageStatusChecker({
    super.key,
    required this.villageId,
    required this.userData,
  });

  @override
  State<VillageStatusChecker> createState() => _VillageStatusCheckerState();
}

class _VillageStatusCheckerState extends State<VillageStatusChecker> {
  late Future<Map<String, dynamic>?> _villageFuture;

  @override
  void initState() {
    super.initState();
    _villageFuture = ApiService.getVillage(widget.villageId);
  }

  @override
  void didUpdateWidget(VillageStatusChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.villageId != widget.villageId) {
      _villageFuture = ApiService.getVillage(widget.villageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _villageFuture,
      builder: (context, villageSnapshot) {
        if (villageSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (villageSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal memuat status desa.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${villageSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (villageSnapshot.hasData && villageSnapshot.data != null) {
          final villageData = villageSnapshot.data!;
          final villageStatus = villageData['status'] as String?;

          if (villageStatus == 'EXPIRED') {
            return Scaffold(
              body: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Akses Terkunci',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Masa Uji Coba (Trial) Desa Anda telah habis atau akses telah ditangguhkan. Silakan hubungi Ketua RT atau Admin Pusat untuk memperpanjang lisensi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Keluar Aplikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
        return DashboardPage(userData: widget.userData);
      },
    );
  }
}

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    // Polling otomatis setiap 10 detik untuk cek status persetujuan
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkApprovalStatus();
    });
    // Langsung cek status saat halaman dibuka
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      final userData = await ApiService.getUser(user.uid);
      if (!mounted) return;
      final status = userData?['status']?.toString();
      // Jika sudah disetujui (bukan PENDING lagi), navigasi ke dashboard
      if (status != null && status != 'PENDING' && status != 'INCOMPLETE') {
        _pollingTimer?.cancel();
        CustomToast.show(context, 'Selamat! Akun Anda sudah diverifikasi.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthWrapper(user: user)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildInfoStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.maps_home_work_rounded,
                                size: 60,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Selamat Datang!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Anda selangkah lagi untuk bergabung dengan Jimpitan Digital',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 40),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _buildInfoStep(
                                    Icons.admin_panel_settings_rounded,
                                    'Verifikasi Admin',
                                    'Akun Anda saat ini sedang dicocokkan dengan data warga oleh Ketua RT atau Admin.',
                                  ),
                                  _buildInfoStep(
                                    Icons.check_circle_outline_rounded,
                                    'Akses Penuh',
                                    'Setelah disetujui, Anda dapat mulai membayar jimpitan, melihat kas, dan info lainnya.',
                                  ),
                                  _buildInfoStep(
                                    Icons.access_time_rounded,
                                    'Harap Menunggu',
                                    'Mohon tunggu maksimal 1x24 jam atau hubungi pengurus RT Anda secara langsung.',
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        EasyLoading.show(
                                          status: 'Merefresh status...',
                                        );
                                        try {
                                          final user =
                                              FirebaseAuth.instance.currentUser;
                                          if (user != null) {
                                            final userData =
                                                await ApiService.getUser(
                                                  user.uid,
                                                );
                                            if (!context.mounted) {
                                              EasyLoading.dismiss();
                                              return;
                                            }
                                            final status = userData?['status']
                                                ?.toString();
                                            if (status != null &&
                                                status != 'PENDING' &&
                                                status != 'INCOMPLETE') {
                                              EasyLoading.dismiss();
                                              _pollingTimer?.cancel();
                                              CustomToast.show(
                                                context,
                                                'Selamat! Akun Anda sudah diverifikasi.',
                                              );
                                              Navigator.of(
                                                context,
                                              ).pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AuthWrapper(user: user),
                                                ),
                                                (route) => false,
                                              );
                                              return;
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint('Refresh error: $e');
                                        } finally {
                                          EasyLoading.dismiss();
                                        }
                                        if (context.mounted) {
                                          CustomToast.show(
                                            context,
                                            'Akun Anda masih dalam proses verifikasi.',
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text(
                                        'Refresh Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Batal Bergabung',
                                            ),
                                            content: const Text(
                                              'Anda yakin ingin membatalkan pengajuan ini? Data pendaftaran Anda akan dihapus.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Tutup'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Ya, Batalkan',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          EasyLoading.show(
                                            status: 'Membatalkan...',
                                          );
                                          try {
                                            final user = FirebaseAuth
                                                .instance
                                                .currentUser!;
                                            await ApiService.saveUserFamily({
                                              'familyId': '',
                                              'uniqueCode': '',
                                              'villageId': '',
                                              'familyMembers': [],
                                              'deletedDocIds': [user.uid],
                                            });

                                            if (context.mounted) {
                                              Navigator.of(
                                                context,
                                              ).pushAndRemoveUntil(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AuthWrapper(user: user),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              CustomToast.show(
                                                context,
                                                'Gagal membatalkan: $e',
                                                isError: true,
                                              );
                                            }
                                          } finally {
                                            EasyLoading.dismiss();
                                          }
                                        }
                                      },
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: Colors.red.shade400,
                                      ),
                                      label: Text(
                                        'Batal Bergabung',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardPage({super.key, required this.userData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver, RouteAware {
  final Map<String, Uint8List> _slideImageCache = {};
  final Map<String, Future<int>> _cachedBillFutures = {}; // Cache gambar slide
  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  late Future<List<dynamic>> _slidesFuture;
  late Future<Map<String, dynamic>?> _villagesFuture;
  late Future<List<dynamic>> _menusFuture;
  Future<Map<String, dynamic>?>? _subscriptionFuture;

  int _totalUnreadCount = 0;
  List<dynamic> _unreadDetails = [];
  Timer? _unreadTimer;

  List<String> _currentUserRoles = ['WARGA'];
  String _currentTabId = 'home';
  String? _currentVillageId;
  List<Map<String, dynamic>> _availableVillages = [];
  String _userName = '';
  DateTime? currentBackPressTime;

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<int> _calculateOverallBill(
    String familyId,
    String villageId,
    DateTime startDate, {
    String? specificTariffId,
  }) async {
    try {
      final responses = await Future.wait([
        ApiService.getTariffs(villageId),
        ApiService.getUsers(villageId),
        ApiService.getExemptions(villageId),
        ApiService.getDuesJournals(villageId),
        ApiService.getJimpitanHistory(villageId),
        ApiService.getVillages(),
      ]);

      final tariffsRaw = responses[0];
      final usersRaw = responses[1];
      final exemptRaw = responses[2];
      final journalRaw = responses[3];
      final historyRaw = responses[4];
      final villagesRaw = responses[5];

      final tariffs = tariffsRaw.where((t) => t['isActive'] == true).toList();

      DateTime villageStart = startDate;
      final myVillage = villagesRaw.firstWhere(
        (v) => v['id'] == villageId,
        orElse: () => {},
      );
      final config = myVillage['config'] as Map<String, dynamic>? ?? {};
      if (config['startDate'] != null) {
        final sDate = config['startDate'];
        if (sDate is String) {
          final parsed = DateTime.tryParse(sDate)?.toLocal();
          if (parsed != null) villageStart = parsed;
        } else if (sDate is int) {
          villageStart = DateTime.fromMillisecondsSinceEpoch(sDate);
        }
      }

      final now = DateTime.now();
      final myUser = usersRaw.firstWhere(
        (u) =>
            (u['uid']?.toString() == widget.userData['uid']?.toString()) ||
            (u['familyId']?.toString() == familyId),
        orElse: () => widget.userData,
      );
      String code =
          myUser['uniqueCode']?.toString() ??
          myUser['code']?.toString() ??
          familyId;
      String noKk = myUser['noKK']?.toString() ?? familyId;
      final uid = myUser['uid']?.toString() ?? '';

      final List<Map<String, dynamic>> myExemptions = [];
      final Set<String> exemptedTariffIds = {};
      for (var item in exemptRaw) {
        final exData = Map<String, dynamic>.from(item as Map? ?? {});
        final exKkId = exData['kkId']?.toString() ?? '';

        if (exKkId == familyId ||
            exKkId == code ||
            exKkId == noKk ||
            (uid.isNotEmpty && exKkId == uid)) {
          myExemptions.add(exData);
          DateTime? startTs;
          if (exData['startDate'] is String) {
            startTs = DateTime.tryParse(exData['startDate'])?.toLocal();
          } else if (exData['startDate'] is int) {
            startTs = DateTime.fromMillisecondsSinceEpoch(exData['startDate']);
          }

          DateTime? endTs;
          if (exData['endDate'] is String) {
            endTs = DateTime.tryParse(exData['endDate'])?.toLocal();
          } else if (exData['endDate'] is int) {
            endTs = DateTime.fromMillisecondsSinceEpoch(exData['endDate']);
          }

          if (startTs == null) continue;
          if (startTs.compareTo(now) > 0) continue; // belum mulai
          if (endTs != null && endTs.compareTo(now) < 0) continue; // sudah berakhir
          exemptedTariffIds.add(exData['tariffId']?.toString() ?? '');
        }
      }

      Map<String, int> payments = {};

      // Fetch payments dari dues_journals (bulanan/tahunan/sekali bayar)
      for (var data in journalRaw) {
        final k = data['kkId']?.toString() ?? '';
        if (k != familyId && k != code && k != noKk && (uid.isEmpty || k != uid)) continue;
        final tariffId = data['tariffId']?.toString() ?? '';
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        if (tariffId.isNotEmpty) {
          payments[tariffId] = (payments[tariffId] ?? 0) + amount;
        }
      }

      // Fetch jimpitan harian
      for (var data in historyRaw) {
        if (data['villageId'] != villageId) continue;
        final k = data['kkId']?.toString() ?? '';
        if (k != familyId && k != code && k != noKk && (uid.isEmpty || k != uid)) continue;

        // Pembayaran tipe TAGIHAN sudah dicatat di dues_journals (journalRaw)
        if (data['type']?.toString() == 'TAGIHAN') {
          continue;
        }

        for (var tariff in tariffs) {
          if (tariff['type']?.toString() == 'Harian') {
            final tariffId = tariff['id']?.toString() ?? '';
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            payments[tariffId] = (payments[tariffId] ?? 0) + amount;
          }
        }
      }

      DateTime getEffectiveStartDate(Map<String, dynamic> tariff) {
        DateTime effective = villageStart;

        if (myUser['createdAt'] != null) {
          final uCreated = myUser['createdAt'];
          DateTime? uDate;
          if (uCreated is String) {
            uDate = DateTime.tryParse(uCreated)?.toLocal();
          } else if (uCreated is int) {
            uDate = DateTime.fromMillisecondsSinceEpoch(uCreated);
          }
          if (uDate != null && uDate.isAfter(effective)) {
            effective = uDate;
          }
        }

        if (tariff['createdAt'] != null) {
          final tCreated = tariff['createdAt'];
          DateTime? tDate;
          if (tCreated is String) {
            tDate = DateTime.tryParse(tCreated)?.toLocal();
          } else if (tCreated is int) {
            tDate = DateTime.fromMillisecondsSinceEpoch(tCreated);
          }
          if (tDate != null && tDate.isAfter(effective)) {
            effective = tDate;
          }
        }
        return effective;
      }

      int calculateExpectedTotal(
        String type,
        int nominal,
        Map<String, dynamic> tariff,
      ) {
        final start = getEffectiveStartDate(tariff);

        if (type == 'Harian') {
          final startMidnight = DateTime(start.year, start.month, start.day);
          final endOfMonthMidnight = DateTime(now.year, now.month + 1, 0);

          Set<String> exemptedDates = {};
          for (var ex in myExemptions) {
            if (ex['tariffId'] == tariff['id']) {
              DateTime? s = ex['startDate'] != null
                  ? (ex['startDate'] is int
                      ? DateTime.fromMillisecondsSinceEpoch(ex['startDate'])
                      : DateTime.tryParse(ex['startDate'].toString())?.toLocal())
                  : null;
              DateTime? e = ex['endDate'] != null
                  ? (ex['endDate'] is int
                      ? DateTime.fromMillisecondsSinceEpoch(ex['endDate'])
                      : DateTime.tryParse(ex['endDate'].toString())?.toLocal())
                  : null;
              if (s != null) {
                DateTime c = DateTime(s.year, s.month, s.day);
                DateTime end = e != null
                    ? DateTime(e.year, e.month, e.day)
                    : endOfMonthMidnight;
                while (!c.isAfter(end)) {
                  exemptedDates.add(
                    '${c.year}-${c.month.toString().padLeft(2, '0')}-${c.day.toString().padLeft(2, '0')}',
                  );
                  c = c.add(const Duration(days: 1));
                }
              }
            }
          }

          int validDays = 0;
          DateTime current = startMidnight;
          while (!current.isAfter(endOfMonthMidnight)) {
            final dStr =
                '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
            if (!exemptedDates.contains(dStr)) {
              validDays++;
            }
            current = current.add(const Duration(days: 1));
          }

          return validDays * nominal;
        } else if (type == 'Bulanan') {
          int validMonths = 0;
          DateTime current = DateTime(start.year, start.month, 1);
          final endOfYearMonth = DateTime(now.year, 12, 1);

          while (!current.isAfter(endOfYearMonth)) {
            final monthStart = DateTime(current.year, current.month, 1);
            final monthEnd =
                DateTime(current.year, current.month + 1, 0, 23, 59, 59);

            bool isMonthExempted = false;
            for (var ex in myExemptions) {
              if (ex['tariffId'] == tariff['id']) {
                DateTime? s = ex['startDate'] != null
                    ? (ex['startDate'] is int
                        ? DateTime.fromMillisecondsSinceEpoch(ex['startDate'])
                        : DateTime.tryParse(ex['startDate'].toString())?.toLocal())
                    : null;
                DateTime? e = ex['endDate'] != null
                    ? (ex['endDate'] is int
                        ? DateTime.fromMillisecondsSinceEpoch(ex['endDate'])
                        : DateTime.tryParse(ex['endDate'].toString())?.toLocal())
                    : null;
                if (s != null) {
                  final sStart = DateTime(s.year, s.month, s.day);
                  final eEnd = e != null
                      ? DateTime(e.year, e.month, e.day, 23, 59, 59)
                      : null;

                  if (!sStart.isAfter(monthEnd) &&
                      (eEnd == null || !eEnd.isBefore(monthStart))) {
                    isMonthExempted = true;
                    break;
                  }
                }
              }
            }

            if (!isMonthExempted) {
              validMonths++;
            }
            current = DateTime(current.year, current.month + 1, 1);
          }

          return validMonths * nominal;
        } else if (type == 'Tahunan') {
          int validYears = 0;
          for (int y = start.year; y <= now.year; y++) {
            final yearStart = DateTime(y, 1, 1);
            final yearEnd = DateTime(y, 12, 31, 23, 59, 59);

            bool isYearExempted = false;
            for (var ex in myExemptions) {
              if (ex['tariffId'] == tariff['id']) {
                DateTime? s = ex['startDate'] != null
                    ? (ex['startDate'] is int
                        ? DateTime.fromMillisecondsSinceEpoch(ex['startDate'])
                        : DateTime.tryParse(ex['startDate'].toString())?.toLocal())
                    : null;
                DateTime? e = ex['endDate'] != null
                    ? (ex['endDate'] is int
                        ? DateTime.fromMillisecondsSinceEpoch(ex['endDate'])
                        : DateTime.tryParse(ex['endDate'].toString())?.toLocal())
                    : null;
                if (s != null) {
                  final sStart = DateTime(s.year, s.month, s.day);
                  final eEnd = e != null
                      ? DateTime(e.year, e.month, e.day, 23, 59, 59)
                      : null;

                  if (!sStart.isAfter(yearEnd) &&
                      (eEnd == null || !eEnd.isBefore(yearStart))) {
                    isYearExempted = true;
                    break;
                  }
                }
              }
            }

            if (!isYearExempted) {
              validYears++;
            }
          }

          return validYears * nominal;
        } else if (type == 'Sekali Bayar' ||
            type == 'Insidentil' ||
            type == 'Lainnya') {
          bool isExempted = false;
          for (var ex in myExemptions) {
            if (ex['tariffId'] == tariff['id']) {
              isExempted = true;
              break;
            }
          }
          return isExempted ? 0 : nominal;
        }
        return 0;
      }

      int overallExpected = 0;
      int overallPaid = 0;

      final bool hasMatchingTariff = specificTariffId != null &&
          specificTariffId.isNotEmpty &&
          tariffs.any((t) => t['id']?.toString() == specificTariffId);

      for (var tariff in tariffs) {
        final tariffId = tariff['id']?.toString() ?? '';
        if (hasMatchingTariff && tariffId != specificTariffId) {
          continue;
        }
        if (exemptedTariffIds.contains(tariffId)) continue; // dibebaskan

        final type = tariff['type']?.toString() ?? 'Harian';
        final nominal = (tariff['amount'] as num?)?.toInt() ?? 0;

        overallExpected += calculateExpectedTotal(type, nominal, tariff);
        overallPaid += payments[tariffId] ?? 0;
      }

      return (overallExpected - overallPaid).clamp(0, double.maxFinite.toInt());
    } catch (e) {
      debugPrint('Error calculate slide bill: $e');
      return 0;
    }
  }

  Timer? _presenceHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userName = widget.userData['name'] ?? 'Pengguna';
    _updatePresence(true);
    _fetchMyProfile();

    // Set villageId awal
    _currentVillageId = widget.userData['villageId'];

    // Load saved theme if any
    final savedThemeColor = widget.userData['themeColor'];
    if (savedThemeColor != null && savedThemeColor is int) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTheme.changeTheme(Color(savedThemeColor));
      });
    }

    _fetchTotalUnreadCount();
    _unreadTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchTotalUnreadCount();
    });

    // Heartbeat online status setiap 45 detik selama app aktif
    _presenceHeartbeatTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) _updatePresence(true);
    });

    // Inisialisasi OneSignal dan Login setelah frame pertama agar widget sudah siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FCMSDK.initialize();
      final uid = widget.userData['uid'] as String?;
      if (uid != null) {
        FCMSDK.saveTokenToDatabase(uid);
      }
      // Cek update app dari server (delay sedikit agar UI sudah stabil)
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) checkAndShowUpdateDialog(context);
      });
    });

    // Inisialisasi secara sinkron untuk menghindari LateInitializationError
    if (_currentVillageId != null) {
      _villagesFuture = ApiService.getVillage(_currentVillageId!);
    } else {
      _villagesFuture = ApiService.getVillage('village_001');
    }

    _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
    _menusFuture = ApiService.getMenus();

    _loadVillages();

    if (widget.userData['roles'] != null) {
      final rawRoles = widget.userData['roles'];
      if (rawRoles is List) {
        _currentUserRoles = rawRoles
            .map((r) {
              if (r is String) return r;
              if (r is Map) return r['name']?.toString() ?? '';
              return '';
            })
            .where((r) => r.isNotEmpty)
            .toList();
      }
    }

    // Hapus pewarisan peran WARGA jika user memiliki jabatan khusus (misal: ADMIN_DESA, BENDAHARA, SATPAM, dll).
    // Ini memastikan acuan otoritas menu yang ditampilkan mengikuti matriks akses jabatan khususnya.
    if (_currentUserRoles.contains('SUPER_ADMIN') ||
        _currentUserRoles.contains('SUPERADMIN')) {
      _currentUserRoles = ['SUPER_ADMIN'];
    } else if (_currentUserRoles.length > 1 &&
        _currentUserRoles.contains('WARGA')) {
      _currentUserRoles.removeWhere((r) => r == 'WARGA');
    } else if (_currentUserRoles.isEmpty) {
      _currentUserRoles = ['WARGA'];
    }

    // Jalankan sinkronisasi menu di latar belakang tanpa memutus alur aplikasi
    Future.microtask(() async {
      try {
        await MenuHelper.checkAndMigrateMenus();
      } catch (e, stack) {
        debugPrint('Menu migration failed: $e');
        debugPrintStack(stackTrace: stack);
      }
    });
  }

  void _loadVillages() async {
    try {
      final query = await ApiService.getVillages();

      if (mounted) {
        setState(() {
          _availableVillages = query.map((d) {
            final map = Map<String, dynamic>.from(d as Map);
            return {'id': map['id'], ...map};
          }).toList();
          if (_currentVillageId == null && _availableVillages.isNotEmpty) {
            if (!_currentUserRoles.contains('SUPER_ADMIN')) {
              _currentVillageId = _availableVillages.first['id'];
            }
          }
          _updateVillagesStream();
        });
      }
    } catch (e, stack) {
      debugPrint('Village load failed: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() {
          _availableVillages = [];
          _updateVillagesStream();
        });
      }
    }
  }

  void _updateVillagesStream() {
    if (_currentVillageId != null) {
      _villagesFuture = ApiService.getVillage(_currentVillageId!);
      _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
      _subscriptionFuture = ApiService.getVillageSubscription(
        _currentVillageId!,
      );
    } else {
      _villagesFuture = ApiService.getVillage('village_001');
      _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
      _subscriptionFuture = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _presenceHeartbeatTimer?.cancel();
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() {
      _cachedBillFutures.clear();
      _updateVillagesStream();
      _fetchTotalUnreadCount();
    });
  }

  Future<void> _fetchTotalUnreadCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentVillageId == null) return;
    try {
      final data = await ApiService.getUnreadCountsAndDetails(
        _currentVillageId!,
        uid,
      );
      final counts = data['counts'] as Map<String, int>;
      final details = data['details'] as List<dynamic>;

      int total = 0;
      counts.forEach((key, value) {
        total += value;
      });
      if (mounted) {
        setState(() {
          _totalUnreadCount = total;
          _unreadDetails = details;
        });
      }
    } catch (e) {
      debugPrint('Error getting unread count: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _updatePresence(false);
    }
  }

  Future<void> _fetchMyProfile() async {
    final uid = widget.userData['uid']?.toString();
    if (uid == null) return;
    try {
      final updatedUser = await ApiService.getUser(uid);
      if (updatedUser != null && mounted) {
        setState(() {
          _userName =
              updatedUser['name'] ?? widget.userData['name'] ?? 'Pengguna';
        });
      }
    } catch (_) {}
  }

  Future<void> _updatePresence(bool isOnline) async {
    final uid = widget.userData['docId'] ?? widget.userData['uid'];
    if (uid != null) {
      try {
        await ApiService.updateOnlineStatus(uid, isOnline: isOnline);
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _villagesFuture,
      builder: (context, villageSnapshot) {
        Map<dynamic, dynamic> menuPermissions = {};
        if (villageSnapshot.hasData && villageSnapshot.data != null) {
          final data = villageSnapshot.data!;
          final config = Map<String, dynamic>.from(
            data['config'] as Map? ?? {},
          );
          final raw = config['menuPermissions'];
          if (raw is Map) {
            menuPermissions = Map<dynamic, dynamic>.from(raw);
          }
          final vTheme = config['themeColor'];
          if (vTheme != null && vTheme is int) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (AppTheme.primaryColor.toARGB32() != vTheme) {
                AppTheme.changeTheme(Color(vTheme));
              }
            });
          }
        }

        return FutureBuilder<List<dynamic>>(
          future: _menusFuture,
          builder: (context, menuSnapshot) {
            List<AppMenuItem> dynamicMenus = [];
            if (menuSnapshot.hasData && menuSnapshot.data!.isNotEmpty) {
              for (var doc in menuSnapshot.data!) {
                final d = Map<String, dynamic>.from(doc as Map? ?? {});
                if (d['isActive'] != false) {
                  dynamicMenus.add(MenuHelper.fromJson(d));
                }
              }
            } else {
              dynamicMenus = List<AppMenuItem>.from(appMenus);
            }

            List<AppMenuItem> gridMenus = dynamicMenus
                .where(
                  (m) =>
                      m.position == 'grid' &&
                      m.id != 'scan' &&
                      _checkAccess(m, menuPermissions),
                )
                .toList();
            List<AppMenuItem> footerMenus = dynamicMenus
                .where(
                  (m) =>
                      m.position == 'footer' &&
                      _checkAccess(m, menuPermissions),
                )
                .toList();

            // Pastikan Home selalu di ujung kiri dan Profile selalu di ujung kanan
            AppMenuItem? homeMenu;
            AppMenuItem? profileMenu;
            List<AppMenuItem> otherFooterMenus = [];

            for (var m in footerMenus) {
              if (m.id == 'home') {
                homeMenu = m;
              } else if (m.id == 'profile') {
                profileMenu = m;
              } else if (m.id == 'scan') {
                // Abaikan scan dari daftar footer biasa, karena ditampilkan sebagai tombol FAB melayang di tengah
              } else {
                otherFooterMenus.add(m);
              }
            }

            List<AppMenuItem> sortedFooterMenus = [];
            if (homeMenu != null) sortedFooterMenus.add(homeMenu);
            sortedFooterMenus.addAll(otherFooterMenus);
            if (profileMenu != null) sortedFooterMenus.add(profileMenu);

            AppMenuItem? scanMenu;
            try {
              scanMenu = dynamicMenus.firstWhere((m) => m.id == 'scan');
            } catch (e) {
              // Not found, scanMenu remains null
            }
            bool hasScanAccess = scanMenu != null
                ? _checkAccess(scanMenu, menuPermissions)
                : false;

            Widget activeBody;
            if (_currentTabId == 'home') {
              activeBody = _buildHomeTab(gridMenus, menuPermissions, context);
            } else if (_currentTabId == 'profile') {
              activeBody = const ProfilePage();
            } else if (_currentTabId == 'report') {
              if (_currentVillageId == null) {
                activeBody = const Center(
                  child: Text(
                    'Silakan pilih Desa terlebih dahulu di bagian atas.',
                  ),
                );
              } else {
                activeBody = ReportsPage(
                  villageId: _currentVillageId!,
                  permissions: Map<String, dynamic>.from(menuPermissions),
                  currentUserRoles: _currentUserRoles,
                );
              }
            } else if (_currentTabId == 'history') {
              if (_currentVillageId == null) {
                activeBody = const Center(
                  child: Text(
                    'Silakan pilih Desa terlebih dahulu di bagian atas.',
                  ),
                );
              } else {
                activeBody = ScanReportPage(villageId: _currentVillageId!);
              }
            } else {
              activeBody = const Center(child: Text("Halaman belum tersedia"));
            }

            final bool isDarkHeader = _currentTabId == 'home';
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDarkHeader ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDarkHeader ? Brightness.dark : Brightness.light,
              ),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (bool didPop, Object? result) {
                  if (didPop) return;
                  DateTime now = DateTime.now();
                  if (currentBackPressTime == null ||
                      now.difference(currentBackPressTime!) >
                          const Duration(seconds: 2)) {
                    currentBackPressTime = now;
                    CustomToast.show(
                      context,
                      'Tekan kembali sekali lagi untuk keluar',
                    );
                  } else {
                    SystemNavigator.pop();
                  }
                },
                child: Scaffold(
                  backgroundColor: const Color(0xFFF8FAFC),
                  body: activeBody,
                  bottomNavigationBar: BottomAppBar(
                    height: 64, // Diperbesar agar lebih lega
                    padding: EdgeInsets.zero,
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: const CircularNotchedRectangle(),
                    notchMargin:
                        8, // Diperlebar agar celah lengkung lebih tegas
                    elevation: 20, // Tambahkan bayangan (shadow) tinggi
                    shadowColor: Colors.black, // Warna shadow tegas
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _buildFooterItems(
                        sortedFooterMenus,
                        menuPermissions,
                        context,
                      ),
                    ),
                  ),
                  floatingActionButton: !hasScanAccess
                      ? null
                      : _currentVillageId == null
                      ? SizedBox(
                          height: 64,
                          width: 64,
                          child: FloatingActionButton(
                            onPressed: hasScanAccess
                                ? () {
                                    CustomToast.show(
                                      context,
                                      'Silakan pilih Desa terlebih dahulu untuk melakukan scan.',
                                      type: ToastType.warning,
                                    );
                                  }
                                : null,
                            backgroundColor: hasScanAccess
                                ? AppTheme.primaryColor
                                : Colors.grey.shade400,
                            shape: const CircleBorder(),
                            elevation: hasScanAccess ? 4 : 0,
                            child: const Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFFFFD700), // Gold color
                              size: 30,
                            ),
                          ),
                        )
                      : FutureBuilder<List<dynamic>>(
                          future: ApiService.getSchedules(
                            _currentVillageId ?? '',
                          ),
                          builder: (context, scheduleSnapshot) {
                            bool isScheduleMatch = false;
                            bool hasAdminScanAccess =
                                hasScanAccess &&
                                (_currentUserRoles.contains('SUPER_ADMIN') ||
                                    _currentUserRoles.contains('ADMIN_DESA'));

                            if (hasAdminScanAccess) {
                              isScheduleMatch = true;
                            } else {
                              Map<String, dynamic>? data;
                              if (scheduleSnapshot.hasData) {
                                final list = scheduleSnapshot.data!;
                                final nik =
                                    widget.userData['nik']?.toString() ?? '';
                                for (var item in list) {
                                  if (item['nik']?.toString() == nik) {
                                    data = item as Map<String, dynamic>;
                                    break;
                                  }
                                }
                              }
                              if (data != null) {
                                final hari = data['hari'] as String?;
                                final todayNum = DateTime.now().weekday;
                                const mapHari = {
                                  1: 'Senin',
                                  2: 'Selasa',
                                  3: 'Rabu',
                                  4: 'Kamis',
                                  5: 'Jumat',
                                  6: 'Sabtu',
                                  7: 'Minggu',
                                };
                                if (hari == mapHari[todayNum]) {
                                  isScheduleMatch = true;
                                }
                              }
                            }

                            bool finalAccess = hasScanAccess && isScheduleMatch;

                            return SizedBox(
                              height: 64,
                              width: 64,
                              child: FloatingActionButton(
                                onPressed: () {
                                  if (!finalAccess && hasScanAccess) {
                                    CustomToast.show(
                                      context,
                                      'Hari ini bukan jadwal jaga Anda.',
                                      type: ToastType.warning,
                                    );
                                  } else if (finalAccess) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ScanPage(
                                          villageId: _currentVillageId!,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                backgroundColor: finalAccess
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade400,
                                shape: const CircleBorder(),
                                elevation: finalAccess ? 4 : 0,
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Color(0xFFFFD700), // Gold color
                                  size: 30,
                                ),
                              ),
                            );
                          },
                        ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildFooterItems(
    List<AppMenuItem> menus,
    Map<dynamic, dynamic> menuPermissions,
    BuildContext context,
  ) {
    List<Widget> items = [];
    int half = (menus.length / 2).ceil();

    for (int i = 0; i < menus.length; i++) {
      if (i == half) {
        // Masukkan spacer kosong di tengah untuk FAB
        items.add(const SizedBox(width: 56));
      }

      final menu = menus[i];
      // Cari tahu perms
      Map<String, bool> perms = {
        'view': true,
        'create': false,
        'edit': false,
        'delete': false,
      };

      if (menuPermissions.containsKey(menu.id)) {
        var rawRoleMap = menuPermissions[menu.id];
        if (rawRoleMap is Map) {
          for (var role in _currentUserRoles) {
            if (rawRoleMap.containsKey(role)) {
              var actions = rawRoleMap[role];
              if (actions is Map) {
                var rawView = actions['view'];
                var rawCreate = actions['create'];
                var rawEdit = actions['edit'];
                var rawDelete = actions['delete'];

                perms['view'] =
                    rawView == true || rawView == 1 || rawView == 'true';
                perms['create'] =
                    rawCreate == true || rawCreate == 1 || rawCreate == 'true';
                perms['edit'] =
                    rawEdit == true || rawEdit == 1 || rawEdit == 'true';
                perms['delete'] =
                    rawDelete == true || rawDelete == 1 || rawDelete == 'true';
              }
            } else {
              List<String> defRoles = menu.defaultRoles.isNotEmpty
                  ? menu.defaultRoles
                  : appMenus
                        .firstWhere(
                          (am) => am.id == menu.id,
                          orElse: () => menu,
                        )
                        .defaultRoles;
              if (defRoles.contains(role)) {
                perms['view'] = true;
              }
            }
          }
        } else if (rawRoleMap is List) {
          if (_currentUserRoles.contains('SUPER_ADMIN')) {
            perms['create'] = true;
            perms['edit'] = true;
            perms['delete'] = true;
          } else if (_currentUserRoles.contains('ADMIN_DESA')) {
            perms['create'] = true;
            perms['edit'] = true;
          }
        }
      } else {
        // Fallback jika database belum disetup / terhapus
        if (_currentUserRoles.contains('SUPER_ADMIN')) {
          perms['create'] = true;
          perms['edit'] = true;
          perms['delete'] = true;
        } else if (_currentUserRoles.contains('ADMIN_DESA')) {
          perms['create'] = true;
          perms['edit'] = true;
        }
      }

      items.add(
        InkWell(
          onTap: () {
            if (_currentVillageId == null &&
                menu.id != 'villages' &&
                menu.id != 'menu_master') {
              CustomToast.show(
                context,
                'Silakan pilih Desa terlebih dahulu di bagian atas.',
              );
              return;
            }

            if (menu.id == 'villages') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VillagesPage(permissions: perms),
                ),
              );
            } else if (menu.id == 'menus') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RolesPage(
                    permissions: perms,
                    villageId: _currentVillageId!,
                    currentUserRoles: _currentUserRoles,
                  ),
                ),
              ).then((_) {
                _updateVillagesStream();
              });
            } else if (menu.id == 'menu_master') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenusPage(permissions: perms),
                ),
              );
            } else if (menu.id == 'manage_roles') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageRolesPage(
                    permissions: perms,
                    villageId: _currentVillageId!,
                    currentUserRoles: _currentUserRoles,
                  ),
                ),
              );
            } else if (menu.id == 'jadwal') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JadwalPage(
                    villageId: _currentVillageId!,
                    permissions: perms,
                  ),
                ),
              );
            } else if (menu.id == 'users') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UsersPage(
                    permissions: perms,
                    villageId: _currentVillageId!,
                    currentUserRoles: _currentUserRoles,
                  ),
                ),
              );
            } else if (menu.id == 'iuran') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DuesPage(
                    villageId: _currentVillageId!,
                    currentUserRoles: _currentUserRoles,
                    permissions: perms,
                  ),
                ),
              );
            } else {
              // Pindah tab secara mulus
              setState(() {
                _currentTabId = menu.id;
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                menu.icon,
                color: _currentTabId == menu.id
                    ? AppTheme.primaryColor
                    : Colors.black45,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                menu.label,
                style: TextStyle(
                  color: _currentTabId == menu.id
                      ? AppTheme
                            .primaryColor // Biru Semula
                      : Colors.black45,
                  fontSize: 10,
                  fontWeight: _currentTabId == menu.id
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildHomeTab(
    List<AppMenuItem> gridMenus,
    Map<dynamic, dynamic> menuPermissions,
    BuildContext context,
  ) {
    return Column(
      children: [
        // HEADER dengan Gradient, Lengkungan, dan DEKORASI
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 180 + MediaQuery.of(context).padding.top,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ], // Biru Semula
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),
            // Dekorasi Lingkaran Kanan Atas
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            // Dekorasi Lingkaran Kiri Bawah
            Positioned(
              left: -30,
              bottom: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Konten Header
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 16),
                // Top Bar (Profile, Dropdown, Icons)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () =>
                                setState(() => _currentTabId = 'profile'),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: UserAvatar(
                                userData: widget.userData,
                                radius: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentUserRoles.contains('SUPER_ADMIN'))
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value:
                                        _availableVillages.any(
                                          (v) => v['id'] == _currentVillageId,
                                        )
                                        ? _currentVillageId
                                        : null,
                                    isDense: true,
                                    dropdownColor: AppTheme.primaryColor,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('General Desa'),
                                      ),
                                      ..._availableVillages.map((v) {
                                        return DropdownMenuItem<String?>(
                                          value: v['id'],
                                          child: Text(
                                            v['name'] ?? 'Desa Tanpa Nama',
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _currentVillageId = val;
                                        _updateVillagesStream();
                                        _fetchTotalUnreadCount();
                                      });
                                    },
                                  ),
                                )
                              else
                                Text(
                                  _availableVillages.isNotEmpty &&
                                          _availableVillages.any(
                                            (v) => v['id'] == _currentVillageId,
                                          )
                                      ? (_availableVillages.firstWhere(
                                              (v) =>
                                                  v['id'] == _currentVillageId,
                                            )['name'] ??
                                            'Desa Tanpa Nama')
                                      : 'General Desa',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              int unreadCount = _totalUnreadCount;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  PopupMenuButton<String>(
                                    offset: const Offset(0, 45),
                                    constraints: const BoxConstraints(
                                      minWidth: 320,
                                      maxWidth: 350,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    color: Colors.white,
                                    elevation: 8,
                                    tooltip: 'Notifikasi Pesan',
                                    onSelected: (value) {
                                      if (value.startsWith('open_chat_room:')) {
                                        final parts = value.split(':');
                                        if (parts.length >= 4) {
                                          final roomId = parts[1];
                                          final rawSenderId = parts[2];
                                          final senderName = parts
                                              .sublist(3)
                                              .join(':');
                                          final targetUid = (rawSenderId.isEmpty ||
                                                  rawSenderId == 'null' ||
                                                  roomId.startsWith('GROUP_'))
                                              ? null
                                              : rawSenderId;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ChatRoomPage(
                                                    villageId:
                                                        _currentVillageId ?? '',
                                                    roomId: roomId,
                                                    roomName: senderName,
                                                    targetUid: targetUid,
                                                  ),
                                            ),
                                          ).then((_) => _fetchTotalUnreadCount());
                                        }
                                      } else if (value == 'open_chat' &&
                                          _currentVillageId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              villageId: _currentVillageId!,
                                              permissions:
                                                  menuPermissions['chat'] ?? {},
                                            ),
                                          ),
                                        ).then((_) => _fetchTotalUnreadCount());
                                      }
                                    },
                                    itemBuilder: (context) {
                                      List<PopupMenuEntry<String>> items = [];
                                      if (unreadCount == 0) {
                                        items.add(
                                          const PopupMenuItem<String>(
                                            enabled: false,
                                            height: 48,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.notifications_off_outlined,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Tidak ada pesan baru',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else {
                                        items.add(
                                          PopupMenuItem<String>(
                                            enabled: false,
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Pesan Baru',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '$unreadCount baru',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        items.add(const PopupMenuDivider(height: 4));

                                        for (var detail in _unreadDetails) {
                                          final senderName =
                                              detail['senderName']
                                                  ?.toString() ??
                                              'Seseorang';
                                          final message =
                                              detail['message']?.toString() ??
                                              '';
                                          final senderUid =
                                              detail['senderUid']?.toString() ??
                                              '';
                                          final roomId =
                                              detail['roomId']?.toString() ??
                                              senderUid;
                                          final isGroup =
                                              roomId.startsWith('GROUP_') ||
                                              detail['type'] == 'GROUP';
                                          final count =
                                              (detail['unreadCount'] as num?)
                                                  ?.toInt() ??
                                              1;

                                          String timeText = '';
                                          final rawDate = detail['createdAt'];
                                          if (rawDate != null) {
                                            final dt = DateTime.tryParse(
                                              rawDate.toString(),
                                            )?.toLocal();
                                            if (dt != null) {
                                              final diff =
                                                  DateTime.now().difference(dt);
                                              if (diff.inMinutes < 1) {
                                                timeText = 'Baru saja';
                                              } else if (diff.inMinutes < 60) {
                                                timeText = '${diff.inMinutes}m';
                                              } else if (diff.inHours < 24) {
                                                timeText =
                                                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                              } else {
                                                timeText = '${dt.day}/${dt.month}';
                                              }
                                            }
                                          }

                                          items.add(
                                            PopupMenuItem<String>(
                                              value:
                                                  'open_chat_room:$roomId:$senderUid:$senderName',
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: isGroup
                                                        ? AppTheme.primaryColor
                                                            .withValues(alpha: 0.15)
                                                        : Colors.grey.shade200,
                                                    child: Icon(
                                                      isGroup
                                                          ? Icons.groups
                                                          : Icons.person,
                                                      size: 20,
                                                      color: isGroup
                                                          ? AppTheme.primaryColor
                                                          : Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                senderName,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize: 12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .black87,
                                                                    ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            if (timeText.isNotEmpty)
                                                              Text(
                                                                timeText,
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade500,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                message,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade700,
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                            if (count > 1) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                      horizontal: 5,
                                                                      vertical: 1,
                                                                    ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                      color: Colors
                                                                          .red
                                                                          .shade500,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            10,
                                                                          ),
                                                                    ),
                                                                child: Text(
                                                                  count.toString(),
                                                                  style:
                                                                      const TextStyle(
                                                                        fontSize: 9,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      items.add(
                                        const PopupMenuDivider(height: 8),
                                      );
                                      items.add(
                                        PopupMenuItem<String>(
                                          value: 'open_chat',
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Lihat Semua Pesan',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                      return items;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.notifications_none,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    PulseBadge(
                                      count: unreadCount,
                                      top: -5,
                                      right: -5,
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          if (_checkAccess(
                            appMenus.firstWhere((m) => m.id == 'settings'),
                            menuPermissions,
                          ))
                            _buildHeaderIcon(
                              Icons.settings,
                              onTap: () {
                                if (_currentVillageId != null) {
                                  // Cari permission terbaik dari semua role user
                                  bool canView = false;
                                  bool canEdit = false;

                                  var s = menuPermissions['settings'];
                                  if (s is Map) {
                                    for (var role in _currentUserRoles) {
                                      if (s[role]?['view'] == true) {
                                        canView = true;
                                      }
                                      if (s[role]?['edit'] == true) {
                                        canEdit = true;
                                      }
                                    }
                                  } else if (s is List) {
                                    if (s.any(
                                      (r) => _currentUserRoles.contains(r),
                                    )) {
                                      canView = true;
                                      if (_currentUserRoles.contains(
                                            'SUPER_ADMIN',
                                          ) ||
                                          _currentUserRoles.contains(
                                            'ADMIN_DESA',
                                          )) {
                                        canEdit = true;
                                      }
                                    }
                                  }

                                  final perms = {
                                    'view': canView,
                                    'edit': canEdit,
                                  };

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SettingsPage(
                                        villageId: _currentVillageId!,
                                        permissions: perms,
                                        userDocId:
                                            widget.userData['docId'] as String?,
                                      ),
                                    ),
                                  ).then((_) {
                                    _updateVillagesStream();
                                  });
                                }
                              },
                            ),

                          const SizedBox(width: 8),
                          _buildHeaderIcon(
                            Icons.power_settings_new,
                            onTap: _showLogoutDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Carousel Slider (dengan Tagihan Otomatis)
                _buildCarouselSlider(),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),

        // BODY (Menu Layanan & Info) dengan Dekorasi Latar Belakang
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _fetchMyProfile();
              setState(() {
                _cachedBillFutures.clear();
                _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
                _updateVillagesStream();
              });
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Stack(
                children: [
                  // Dekorasi Latar Belakang Body (Watermark/Pola Halus)
                  Positioned(
                    right: -40,
                    top: 40,
                    child: Icon(
                      Icons.widgets_outlined,
                      size: 200,
                      color: AppTheme.primaryColor.withValues(alpha: 0.03),
                    ),
                  ),
                  Positioned(
                    left: -80,
                    bottom: 50,
                    child: Icon(
                      Icons.business_outlined,
                      size: 300,
                      color: AppTheme.primaryColor.withValues(alpha: 0.03),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSubscriptionReminder(),
                        const SizedBox(height: 16),
                        // Grid Menu Dinamis
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.8,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: gridMenus.length,
                          itemBuilder: (context, index) {
                            final menu = gridMenus[index];
                            Map<String, bool> perms = {
                              'view': true,
                              'create': false,
                              'edit': false,
                              'delete': false,
                            };

                            if (menuPermissions.containsKey(menu.id)) {
                              var rawRoleMap = menuPermissions[menu.id];
                              if (rawRoleMap is Map) {
                                for (var role in _currentUserRoles) {
                                  if (rawRoleMap.containsKey(role)) {
                                    var actions = rawRoleMap[role];
                                    if (actions is Map) {
                                      var rawView = actions['view'];
                                      var rawCreate = actions['create'];
                                      var rawEdit = actions['edit'];
                                      var rawDelete = actions['delete'];

                                      perms['view'] =
                                          rawView == true ||
                                          rawView == 1 ||
                                          rawView == 'true';
                                      perms['create'] =
                                          rawCreate == true ||
                                          rawCreate == 1 ||
                                          rawCreate == 'true';
                                      perms['edit'] =
                                          rawEdit == true ||
                                          rawEdit == 1 ||
                                          rawEdit == 'true';
                                      perms['delete'] =
                                          rawDelete == true ||
                                          rawDelete == 1 ||
                                          rawDelete == 'true';
                                    }
                                  } else {
                                    List<String> defRoles =
                                        menu.defaultRoles.isNotEmpty
                                        ? menu.defaultRoles
                                        : appMenus
                                              .firstWhere(
                                                (am) => am.id == menu.id,
                                                orElse: () => menu,
                                              )
                                              .defaultRoles;
                                    if (defRoles.contains(role)) {
                                      perms['view'] = true;
                                    }
                                  }
                                }
                              } else if (rawRoleMap is List) {
                                if (_currentUserRoles.contains('SUPER_ADMIN')) {
                                  perms['create'] = true;
                                  perms['edit'] = true;
                                  perms['delete'] = true;
                                } else if (_currentUserRoles.contains(
                                  'ADMIN_DESA',
                                )) {
                                  perms['create'] = true;
                                  perms['edit'] = true;
                                }
                              }
                            } else {
                              // Fallback jika database belum disetup / terhapus
                              if (_currentUserRoles.contains('SUPER_ADMIN')) {
                                perms['create'] = true;
                                perms['edit'] = true;
                                perms['delete'] = true;
                              } else if (_currentUserRoles.contains(
                                'ADMIN_DESA',
                              )) {
                                perms['create'] = true;
                                perms['edit'] = true;
                              }
                            }
                            return _buildMenuItem(menu, perms, context);
                          },
                        ),
                        const SizedBox(height: 100), // Spasi untuk FAB di bawah
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx, rootNavigator: true).pop();
                try {
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Keluar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubscriptionReminder() {
    return SubscriptionBanner(
      future: _subscriptionFuture,
      villageId: _currentVillageId,
      showButton: false,
    );
  }

  Widget _buildCarouselSlider() {
    final familyId = widget.userData['familyId'] ?? widget.userData['code'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: _villagesFuture,
      builder: (context, villageSnap) {
        final villageConfig = villageSnap.data;
        final config = villageConfig?['config'] as Map<String, dynamic>? ?? {};
        DateTime? startDateStamp;
        if (config['startDate'] != null) {
          final sDate = config['startDate'];
          if (sDate is String) {
            startDateStamp = DateTime.tryParse(sDate)?.toLocal();
          } else if (sDate is int) {
            startDateStamp = DateTime.fromMillisecondsSinceEpoch(sDate);
          }
        }

        return FutureBuilder<List<dynamic>>(
          future: _slidesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            final List<Map<String, dynamic>> slidesData = [];

            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              slidesData.addAll(
                snapshot.data!
                    .where((doc) {
                      final data = Map<String, dynamic>.from(doc as Map? ?? {});
                      final vid = data['villageId'];
                      return vid == null ||
                          vid == '' ||
                          vid == _currentVillageId;
                    })
                    .map((doc) {
                      final data = Map<String, dynamic>.from(doc as Map? ?? {});
                      // The backend already includes 'id', but let's make sure
                      return data;
                    })
                    .toList(),
              );
            }

            if (slidesData.isNotEmpty) {
              final defaultBillId = '${_currentVillageId}_bill';
              final defaultBillIndex = slidesData.indexWhere(
                (s) => s['id'] == defaultBillId,
              );
              if (defaultBillIndex > 0) {
                final defaultBill = slidesData.removeAt(defaultBillIndex);
                slidesData.insert(0, defaultBill);
              }
            }

            if (slidesData.isEmpty) {
              return const SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    "Tidak ada info terbaru",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            return Column(
              children: [
                CarouselSlider(
                  items: slidesData.map((slide) {
                    return _buildSlideItem(
                      slide,
                      familyId: familyId,
                      villageId: _currentVillageId,
                      startDate: startDateStamp,
                      onTap: () {
                        if (familyId != null &&
                            _currentVillageId != null &&
                            startDateStamp != null) {
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => BillDetailPage(
                                familyId: familyId,
                                villageId: _currentVillageId!,
                                startDate: startDateStamp!,
                                userData: widget.userData,
                              ),
                            ),
                          ).then((_) {
                            setState(() {
                              _cachedBillFutures.clear();
                              _slidesFuture = ApiService.getSlides(
                                _currentVillageId ?? '',
                              );
                              _updateVillagesStream();
                            });
                          });
                        } else if (startDateStamp == null) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Silakan atur Tanggal Mulai di menu Pengaturan (ikon gerigi) terlebih dahulu.',
                              ),
                            ),
                          );
                        } else if (familyId == null &&
                            _currentVillageId != null) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Anda belum tergabung di dalam Kartu Keluarga (sebagai Warga), sehingga tidak memiliki tagihan.',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Gagal membuka detail: familyId=$familyId, village=$_currentVillageId',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                  carouselController: _carouselController,
                  options: CarouselOptions(
                    height: 140,
                    viewportFraction: 0.9,
                    enlargeCenterPage: true,
                    autoPlay: slidesData.length > 1,
                    autoPlayInterval: const Duration(seconds: 5),
                    onPageChanged: (index, reason) {
                      if (_currentSlide != index) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _currentSlide = index;
                            });
                          }
                        });
                      }
                    },
                  ),
                ),
                if (slidesData.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: slidesData.asMap().entries.map((entry) {
                      return Container(
                        width: _currentSlide == entry.key ? 16.0 : 6.0,
                        height: 6.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(
                            alpha: _currentSlide == entry.key ? 1.0 : 0.4,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  bool _checkAccess(AppMenuItem menu, Map<dynamic, dynamic> menuPermissions) {
    if (_currentUserRoles.contains('SUPER_ADMIN')) return true;
    bool hasViewAccess = false;
    if (menuPermissions.containsKey(menu.id)) {
      var rawRoleMap = menuPermissions[menu.id];
      if (rawRoleMap is Map) {
        for (var role in _currentUserRoles) {
          if (rawRoleMap.containsKey(role)) {
            var actions = rawRoleMap[role];
            var rawView = actions['view'];
            if (actions is Map &&
                (rawView == true || rawView == 1 || rawView == 'true')) {
              hasViewAccess = true;
              break;
            }
          }
        }
      } else if (rawRoleMap is List) {
        hasViewAccess = rawRoleMap.any((r) => _currentUserRoles.contains(r));
      }
    } else {
      if (menu.defaultRoles.isEmpty) {
        final fallbackMenu = appMenus.firstWhere(
          (am) => am.id == menu.id,
          orElse: () => menu,
        );
        hasViewAccess = fallbackMenu.defaultRoles.any(
          (r) => _currentUserRoles.contains(r),
        );
      } else {
        hasViewAccess = menu.defaultRoles.any(
          (r) => _currentUserRoles.contains(r),
        );
      }
    }
    return hasViewAccess;
  }

  Widget _buildHeaderIcon(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSlideItem(
    Map<String, dynamic> slide, {
    VoidCallback? onTap,
    String? familyId,
    String? villageId,
    DateTime? startDate,
  }) {
    String cacheKey =
        '${familyId}_${villageId}_${startDate?.toIso8601String()}_${slide['value']}';
    if (familyId != null &&
        villageId != null &&
        startDate != null &&
        !_cachedBillFutures.containsKey(cacheKey)) {
      _cachedBillFutures[cacheKey] = _calculateOverallBill(
        familyId,
        villageId,
        startDate,
        specificTariffId: slide['value']?.toString(),
      );
    }
    bool isBill = slide['type'] == 'BILL';
    bool hasImage =
        slide['imageBase64'] != null &&
        slide['imageBase64'].toString().isNotEmpty;

    final docId = slide['id'] ?? slide['title'] ?? 'unknown';

    String? textColorHex = slide['textColor'];
    Color? customTextColor;
    if (textColorHex != null && textColorHex.isNotEmpty) {
      customTextColor = Color(
        int.parse(textColorHex.replaceFirst('#', '0xFF')),
      );
    }

    Color titleColor =
        customTextColor ??
        (isBill || hasImage ? Colors.white : const Color(0xFF1E293B));
    Color subtitleColor =
        customTextColor?.withValues(alpha: 0.9) ??
        (isBill || hasImage
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.grey.shade600);

    Uint8List? imageBytes;
    if (hasImage) {
      final cacheKey = '${docId}_${slide['imageBase64'].hashCode}';
      if (_slideImageCache.containsKey(cacheKey)) {
        imageBytes = _slideImageCache[cacheKey];
      } else {
        try {
          // Remove old cached images for this slide to prevent memory leaks
          _slideImageCache.removeWhere(
            (key, value) => key.startsWith('${docId}_'),
          );

          imageBytes = base64Decode(slide['imageBase64']);
          _slideImageCache[cacheKey] = imageBytes;
        } catch (e) {
          debugPrint('Error decoding slide image: $e');
        }
      }
    }

    return Container(
      key: ValueKey(docId),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: hasImage
            ? Colors.transparent
            : (isBill ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        gradient: (isBill && !hasImage)
            ? const LinearGradient(
                colors: [
                  Color(0xFF1E293B), // Slate 800
                  Color(0xFF0F172A), // Slate 900
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: (isBill ? const Color(0xFF0F172A) : Colors.black).withValues(
              alpha: 0.15,
            ),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage && imageBytes != null)
              Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            if (isBill)
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            if (isBill)
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: isBill
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        color: titleColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          slide['title'] ?? "",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: titleColor,
                                            shadows: hasImage
                                                ? const [
                                                    Shadow(
                                                      color: Colors.black45,
                                                      blurRadius: 2,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slide['subtitle'] ?? "",
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                      shadows: hasImage
                                          ? const [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                slide['status'] ?? "",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Tagihan",
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                (isBill &&
                                        familyId != null &&
                                        villageId != null &&
                                        startDate != null)
                                    ? FutureBuilder<int>(
                                        future: _cachedBillFutures[cacheKey],
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                                  ConnectionState.waiting &&
                                              !snapshot.hasData) {
                                            return Text(
                                              "...",
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 28,
                                                shadows: (isBill || hasImage)
                                                    ? const [
                                                        Shadow(
                                                          color: Colors.black54,
                                                          blurRadius: 3,
                                                          offset: Offset(1, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            );
                                          }
                                          final amount = snapshot.data ?? 0;
                                          return FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              amount == 0
                                                  ? "Lunas"
                                                  : _formatCurrency(amount),
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 28,
                                                letterSpacing: 0.5,
                                                shadows: (isBill || hasImage)
                                                    ? const [
                                                        Shadow(
                                                          color: Colors.black54,
                                                          blurRadius: 3,
                                                          offset: Offset(1, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          slide['value'] != null &&
                                                  slide['value']
                                                      .toString()
                                                      .isNotEmpty
                                              ? slide['value'].toString()
                                              : (startDate == null
                                                    ? "Atur Tanggal Mulai"
                                                    : (familyId == null
                                                          ? "Belum Terdaftar"
                                                          : "Lunas")),
                                          style: TextStyle(
                                            color: startDate == null
                                                ? Colors.amber
                                                : titleColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: startDate == null
                                                ? 14
                                                : 28,
                                            letterSpacing: 0.5,
                                            shadows: (isBill || hasImage)
                                                ? const [
                                                    Shadow(
                                                      color: Colors.black54,
                                                      blurRadius: 3,
                                                      offset: Offset(1, 1),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                            AnimatedDetailButton(
                              onPressed: isBill ? onTap : null,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (!hasImage)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              slide['image'] is IconData
                                  ? slide['image']
                                  : Icons.info_outline,
                              size: 32,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        if (!hasImage) const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                slide['title'] ?? "",
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  shadows: hasImage
                                      ? const [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                slide['subtitle'] ?? "",
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                  shadows: hasImage
                                      ? const [
                                          Shadow(
                                            color: Colors.black45,
                                            blurRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    AppMenuItem menu,
    Map<String, bool> perms,
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_currentVillageId == null &&
              menu.id != 'villages' &&
              menu.id != 'menu_master') {
            CustomToast.show(
              context,
              'Silakan pilih Desa terlebih dahulu di bagian atas.',
            );
            return;
          }

          if (menu.id == 'villages') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VillagesPage(permissions: perms),
              ),
            );
          } else if (menu.id == 'menus') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RolesPage(
                  permissions: perms,
                  villageId: _currentVillageId!,
                  currentUserRoles: _currentUserRoles,
                ),
              ),
            ).then((_) {
              setState(() {
                _cachedBillFutures.clear();
                _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
                _updateVillagesStream();
              });
            });
          } else if (menu.id == 'menu_master') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenusPage(permissions: perms),
              ),
            );
          } else if (menu.id == 'chat') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatPage(villageId: _currentVillageId!, permissions: perms),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'inventory') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryPage(
                  villageId: _currentVillageId!,
                  permissions: perms,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'settings') {
            Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      villageId: _currentVillageId!,
                      permissions: perms,
                    ),
                  ),
                )
                .then((_) {
                  _updateVillagesStream();
                })
                .then((_) {
                  _fetchTotalUnreadCount();
                  _updateVillagesStream();
                });
          } else if (menu.id == 'manage_roles') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageRolesPage(
                  permissions: perms,
                  villageId: _currentVillageId!,
                  currentUserRoles: _currentUserRoles,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'jadwal') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JadwalPage(
                  villageId: _currentVillageId!,
                  permissions: perms,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'users') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UsersPage(
                  permissions: perms,
                  villageId: _currentVillageId!,
                  currentUserRoles: _currentUserRoles,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'tariffs') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TariffsPage(
                  permissions: perms,
                  villageId: _currentVillageId!,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'iuran') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DuesPage(
                  villageId: _currentVillageId!,
                  currentUserRoles: _currentUserRoles,
                  permissions: perms,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              setState(() {
                _cachedBillFutures.clear();
                _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
                _updateVillagesStream();
              });
            });
          } else if (menu.id == 'journals') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FinancialJournalsPage(
                  villageId: _currentVillageId!,
                  currentUserRoles: _currentUserRoles,
                  permissions: perms,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              setState(() {
                _cachedBillFutures.clear();
                _slidesFuture = ApiService.getSlides(_currentVillageId ?? '');
                _updateVillagesStream();
              });
            });
          } else if (menu.id == 'scan') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScanPage(villageId: _currentVillageId!),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'scan_manual') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ManualScanPage(villageId: _currentVillageId!),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'setor_jimpitan') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SetorJimpitanPage(villageId: _currentVillageId!),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'slides') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SlidesPage(
                  permissions: perms,
                  villageId: _currentVillageId ?? '',
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'exemptions') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExemptionsPage(
                  permissions: perms,
                  villageId: _currentVillageId!,
                ),
              ),
            ).then((_) {
              _fetchTotalUnreadCount();
              _updateVillagesStream();
            });
          } else if (menu.id == 'help') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HelpPage(villageId: _currentVillageId),
              ),
            );
          } else if (menu.id == 'about') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            );
          } else {
            CustomToast.show(
              context,
              'Menu ini belum tersedia atau dalam pengembangan.',
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF6F4E37,
                        ).withValues(alpha: 0.1), // Biru Semula
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    menu.icon,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
                if (menu.id == 'chat' && _totalUnreadCount > 0)
                  PulseBadge(
                    count: _totalUnreadCount,
                    top: -5,
                    right: -5,
                    fontSize: 12,
                    padding: 6,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              menu.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedDetailButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const AnimatedDetailButton({super.key, this.onPressed});

  @override
  State<AnimatedDetailButton> createState() => _AnimatedDetailButtonState();
}

class _AnimatedDetailButtonState extends State<AnimatedDetailButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B), // Dark slate text
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Detail",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_animation.value, 0),
                  child: const Icon(Icons.arrow_forward_ios, size: 10),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
