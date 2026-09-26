import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/flat/presentation/pages/create_flat_page.dart';
import 'features/flat/presentation/pages/join_flat_page.dart';
import 'features/flat/data/flat_repository.dart';
import 'core/firebase/firebase_options.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) => runApp(const HisabMilauApp()));
}

class HisabMilauApp extends StatelessWidget {
  const HisabMilauApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
        Provider<FlatRepository>(
          create: (_) => FlatRepository(),
        ),
      ],
      child: MaterialApp(
        title: 'Hisab Milau',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.primary,
            primary: AppTheme.primary,
            surface: AppTheme.white,
          ),
          scaffoldBackgroundColor: AppTheme.background,
          fontFamily: AppTheme.fontName,
          textTheme: AppTheme.textTheme,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// AuthGate — the routing brain of the app
///
/// Flow:
///   Not signed in → LoginPage
///   Signed in → read users/{uid} from Firestore:
///     role == 'admin' && flatId exists → AdminPage(flatId)
///     role == 'admin' && no flatId     → CreateFlatPage
///     role == 'user'  && flatId exists → HomePage(flatId)
///     role == 'user'  && no flatId     → JoinFlatPage
///     no profile yet                   → LoginPage (sign out)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _flatRepo = FlatRepository();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  User? _currentUser;
  bool _isLoading = true;
  String? _flatId;
  String? _role;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _listenToAuth();
  }

  void _listenToAuth() {
    // 1. Let authStateChanges handle the initial load to prevent race conditions.
    // FirebaseAuth.instance.authStateChanges() immediately emits the initial state.

    // 2. Auth state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final prevUser = _currentUser;
      setState(() {
        _currentUser = user;
      });

      if (user != null) {
        if (prevUser?.uid != user.uid || !_profileLoaded) {
          _loadProfileForUser(user.uid);
        }
      } else {
        _flatRepo.clearLocalProfile();
        _profileSubscription?.cancel();
        setState(() {
          _flatId = null;
          _role = null;
          _isLoading = false;
          _profileLoaded = false;
        });
      }
    });
  }

  Future<void> _loadProfileForUser(String uid) async {
    // 1. FAST PATH: Check local cache first for instant zero-latency UI
    final local = await _flatRepo.getLocalProfile();
    final cachedFlatId = local['flatId'];
    final cachedRole = local['role'];
    final userEmail = _currentUser?.email?.toLowerCase().trim() ?? '';
    final isMasterAdmin = userEmail == 'aadarshapandit17@gmail.com' ||
        userEmail == 'aadarshapandit@gmail.com';

    if (mounted) {
      setState(() {
        if (isMasterAdmin) {
          _role = 'admin';
        } else if (cachedRole != null && cachedRole.isNotEmpty) {
          _role = cachedRole;
        } else {
          _role = 'user';
        }

        if (cachedFlatId != null && cachedFlatId.isNotEmpty) {
          _flatId = cachedFlatId;
          _isLoading = false;
          _profileLoaded = true;
        }
      });
    }

    // 2. NETWORK PATH: Fetch from Firestore with an 8-second timeout
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (mounted) {
        String? flatId;
        String? flatName;
        String role = isMasterAdmin ? 'admin' : (_role ?? 'user');

        if (doc.exists) {
          final data = doc.data() ?? {};
          flatId = data['flatId'] as String?;
          flatName = data['flatName'] as String?;
          final docRole = data['role'] as String?;
          if (!isMasterAdmin && docRole != null && docRole.isNotEmpty) {
            role = docRole;
          }
        }

        // Auto-discover if user created a flat or has admin privileges
        final discovery = await _flatRepo.discoverFlatAndRole(
          uid: uid,
          email: _currentUser?.email,
          fallbackRole: role,
          currentFlatId: flatId,
        );

        if (discovery.flatId != null && discovery.flatId!.isNotEmpty) {
          flatId = discovery.flatId;
          role = isMasterAdmin ? 'admin' : discovery.role;
          if (discovery.flatName != null && discovery.flatName!.isNotEmpty) {
            flatName = discovery.flatName;
          }
        } else if (discovery.role == 'admin' || isMasterAdmin) {
          role = 'admin';
        }

        // Self-heal: save discovered flatId, flatName & role back to users/{uid} in Firestore
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          if (flatId != null && flatId.isNotEmpty) 'flatId': flatId,
          if (flatName != null && flatName.isNotEmpty) 'flatName': flatName,
          'role': role,
          'email': userEmail,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 5)).catchError((_) {});

        if (flatId != null && flatId.isNotEmpty) {
          await _flatRepo.saveLocalProfile(flatId: flatId, role: role, flatName: flatName);
        } else {
          await _flatRepo.saveLocalRole(role);
        }

        setState(() {
          _flatId = flatId;
          _role = role;
          _isLoading = false;
          _profileLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profileLoaded = true;
        });
      }
    }

    // 3. REAL-TIME SYNC: Listen for updates in the background
    _profileSubscription?.cancel();
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() ?? {};
        final flatId = data['flatId'] as String?;
        final flatName = data['flatName'] as String?;
        String streamRole = isMasterAdmin ? 'admin' : (data['role'] as String? ?? _role ?? 'user');

        if (flatId != _flatId || streamRole != _role) {
          if (flatId != null && flatId.isNotEmpty) {
            _flatRepo.saveLocalProfile(flatId: flatId, role: streamRole, flatName: flatName);
          } else {
            _flatRepo.saveLocalRole(streamRole);
          }
          setState(() {
            _flatId = flatId;
            _role = streamRole;
            _isLoading = false;
            _profileLoaded = true;
          });
        }
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const WelcomePage();
    }

    if (_isLoading && !_profileLoaded) {
      return const _LoadingScreen();
    }

    // 1. If user already has a flat (or discovered existing flat) -> App Dashboard!
    if (_flatId != null && _flatId!.isNotEmpty) {
      return HomePage(flatId: _flatId!, isAdmin: _role == 'admin');
    }

    // 2. No flat yet:
    // Admin without a flat -> Create Flat screen directly
    if (_role == 'admin') {
      return const CreateFlatPage();
    }

    // User/Flatmate without a flat -> Join Flat screen directly
    return const JoinFlatPage();
  }
}

/// Themed loading screen with fallback sign out option
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9E7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF164E3D)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading your flat...',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF164E3D),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await FlatRepository().clearLocalProfile();
                await FirebaseAuth.instance.signOut();
              },
              child: const Text(
                'Taking too long? Sign out',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 13,
                  color: Color(0xFF164E3D),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}