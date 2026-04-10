import "dart:async";
import "dart:ui";

import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "dart:io";

import "api/api_client.dart";
import "auth/auth_service.dart";
import "auth/auth_state.dart";
import "screens/home_screen.dart";
import "screens/login_screen.dart";
import "utils/error_reporter.dart";
import "utils/offline_queue.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final apiClient = ApiClient();
  final authState = AuthState(AuthService(apiClient: apiClient));
  final errorReporter = ErrorReporter(apiClient: apiClient, authState: authState);
  final offlineQueue = OfflineQueue.instance(apiClient);
  errorReporter.start();

  FlutterError.onError = errorReporter.reportFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    errorReporter.report(error, stack, context: "platform");
    return true;
  };

  runZonedGuarded(
    () =>
        runApp(DropCityClientApp(authState: authState, offlineQueue: offlineQueue)),
    (error, stack) => errorReporter.report(error, stack, context: "zone"),
  );
}

class DropCityClientApp extends StatefulWidget {
  const DropCityClientApp({
    super.key,
    required this.authState,
    required this.offlineQueue,
  });

  final AuthState authState;
  final OfflineQueue offlineQueue;

  @override
  State<DropCityClientApp> createState() => _DropCityClientAppState();
}

class _DropCityClientAppState extends State<DropCityClientApp> {
  bool _restoring = true;
  String? _pendingPushToken;
  String? _registeredPushToken;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    widget.authState.addListener(_onAuthChanged);
    _restoreSession();
    _initPushNotifications();
  }

  Future<void> _restoreSession() async {
    await widget.authState.restoreSession();
    widget.offlineQueue.start();
    setState(() => _restoring = false);
  }

  Future<void> _initPushNotifications() async {
    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      await messaging.requestPermission();
    }
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint("Push received: ${message.notification?.title}");
    });
    _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      _pendingPushToken = token;
      _tryRegisterPushToken();
    });
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      _pendingPushToken = token;
      _tryRegisterPushToken();
    }
  }

  void _onAuthChanged() {
    _tryRegisterPushToken();
  }

  Future<void> _tryRegisterPushToken() async {
    if (!widget.authState.isAuthenticated) {
      return;
    }
    final token = _pendingPushToken;
    if (token == null || token.isEmpty || token == _registeredPushToken) {
      return;
    }
    try {
      await widget.authState.apiClient.registerDeviceToken(
        token: token,
        platform: Platform.operatingSystem,
      );
      _registeredPushToken = token;
    } catch (error) {
      debugPrint("Push token register failed: $error");
    }
  }

  @override
  void dispose() {
    widget.authState.removeListener(_onAuthChanged);
    _tokenRefreshSub?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authState,
      builder: (context, _) {
        return MaterialApp(
          title: "DropCity Client",
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: _restoring
              ? const _SplashScreen()
              : widget.authState.isAuthenticated
                  ? HomeScreen(authState: widget.authState)
                  : LoginScreen(authState: widget.authState),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text("Restoring session..."),
          ],
        ),
      ),
    );
  }
}
