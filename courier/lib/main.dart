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
import "services/courier_tracking_service.dart";
import "utils/error_reporter.dart";
import "utils/offline_queue.dart";
import "theme.dart";

void main() {
  // MUST be the first call - before any async/zone operations
  WidgetsFlutterBinding.ensureInitialized();

  // Run everything in the same async zone
  runZonedGuarded(
    () => _runApp(),
    (error, stack) {
      // Fallback error handling if app fails
      debugPrint("Uncaught zone error: $error");
      debugPrintStack(stackTrace: stack);
    },
  );
}

Future<void> _runApp() async {
  try {
    await Firebase.initializeApp();
    final apiClient = ApiClient();
    final authState = AuthState(AuthService(apiClient: apiClient));
    final errorReporter =
        ErrorReporter(apiClient: apiClient, authState: authState);
    final offlineQueue = OfflineQueue.instance(apiClient);
    errorReporter.start();

    FlutterError.onError = errorReporter.reportFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      errorReporter.report(error, stack, context: "platform");
      return true;
    };

    runApp(DropCityCourierApp(authState: authState, offlineQueue: offlineQueue));
  } catch (e, stack) {
    debugPrint("Failed to initialize app: $e");
    debugPrintStack(stackTrace: stack);
    rethrow;
  }
}

class DropCityCourierApp extends StatefulWidget {
  const DropCityCourierApp({
    super.key,
    required this.authState,
    required this.offlineQueue,
  });

  final AuthState authState;
  final OfflineQueue offlineQueue;

  @override
  State<DropCityCourierApp> createState() => _DropCityCourierAppState();
}

class _DropCityCourierAppState extends State<DropCityCourierApp>
    with WidgetsBindingObserver {
  bool _restoring = true;
  bool _showContinueOption = false;
  String? _restoreHint;
  String? _pendingPushToken;
  String? _registeredPushToken;
  StreamSubscription<String>? _tokenRefreshSub;
  Timer? _restoreHintTimer;
  Timer? _trackingStateTimer;
  late final CourierTrackingService _trackingService;
  bool _trackingExpected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingService = CourierTrackingService(
      apiClient: widget.authState.apiClient,
    );
    widget.authState.addListener(_onAuthChanged);
    widget.offlineQueue.start();
    _restoreHintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_restoring) {
        return;
      }
      setState(() => _showContinueOption = true);
    });
    _restoreSession();
    _initPushNotifications();
    _trackingStateTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _syncTrackingService(),
    );
  }

  Future<void> _restoreSession() async {
    final restoreFuture = widget.authState.restoreSession();
    restoreFuture.then((_) {
      if (!mounted || !_restoring) {
        return;
      }
      setState(() => _restoring = false);
    }).catchError((_) {
      // Errors are handled by the timeout/try-catch path below.
    });

    try {
      await restoreFuture.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _restoreHint =
              "We are taking longer than expected. You can continue now.";
          _showContinueOption = true;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoreHint = "Could not refresh the session. Please sign in again.";
          _showContinueOption = true;
        });
      }
      return;
    }
  }

  void _continueWithoutWaiting() {
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
    _syncTrackingService();
  }

  Future<void> _syncTrackingService() async {
    if (!widget.authState.isAuthenticated) {
      _trackingExpected = false;
      await _trackingService.stop();
      return;
    }
    try {
      final state = await widget.authState.apiClient.getCourierServiceState();
      final shouldRun = (state["state"]?.toString() ?? "") == "TRAVELLING";
      if (shouldRun == _trackingExpected) {
        return;
      }
      _trackingExpected = shouldRun;
      if (shouldRun) {
        await _trackingService.start(widget.authState);
      } else {
        await _trackingService.stop();
      }
    } catch (_) {
      // Keep app usable on intermittent state fetch failures.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTrackingService();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    widget.authState.removeListener(_onAuthChanged);
    _tokenRefreshSub?.cancel();
    _restoreHintTimer?.cancel();
    _trackingStateTimer?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authState,
      builder: (context, _) {
        return MaterialApp(
          title: "DropCity Courier",
          debugShowCheckedModeBanner: false,
          theme: dropCityLightTheme,
          darkTheme: dropCityDarkTheme,
          themeMode: ThemeMode.system,
          home: _restoring
              ? _LaunchScreen(
                  hint: _restoreHint,
                  showContinueOption: _showContinueOption,
                  onContinue: _continueWithoutWaiting,
                )
              : widget.authState.isAuthenticated
                  ? HomeScreen(authState: widget.authState)
                  : LoginScreen(authState: widget.authState),
        );
      },
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen({
    required this.hint,
    required this.showContinueOption,
    required this.onContinue,
  });

  final String? hint;
  final bool showContinueOption;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8EBFF), Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, size: 56, color: Colors.indigo),
                const SizedBox(height: 16),
                Text(
                  "DropCity Courier",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Preparing your route workspace...",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                if (hint != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ],
                if (showContinueOption) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: onContinue,
                    child: const Text("Continue to sign in"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
