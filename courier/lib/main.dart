import "dart:async";
import "dart:io";
import "dart:ui";

import "package:flutter/foundation.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "api/api_client.dart";
import "auth/auth_service.dart";
import "auth/auth_state.dart";
import "controllers/signup_controller.dart";
import "screens/auth/login_screen.dart";
import "screens/auth/signup_screen.dart";
import "screens/auth/splash_screen.dart";
import "screens/auth/welcome_screen.dart";
import "screens/home_screen.dart";
import "screens/navigation_hub_screen.dart";
import "services/courier_tracking_service.dart";
import "services/route_start_reminder_service.dart";
import "theme.dart";
import "utils/error_reporter.dart";
import "utils/offline_queue.dart";

Future<void> main() async {
  // Ensure zone-based uncaught errors are reported consistently
  BindingBase.debugZoneErrorsAreFatal = true;

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();

      final apiClient = ApiClient();

      final authState = AuthState(
        AuthService(apiClient: apiClient),
      );

      final errorReporter = ErrorReporter(
        apiClient: apiClient,
        authState: authState,
      );

      // Initialize the offline-first queue subsystem
      final offlineQueue = OfflineQueue.instance(apiClient);

      errorReporter.start();

      // Intercept and route flutter frameworks errors safely
      FlutterError.onError = (FlutterErrorDetails details) {
        errorReporter.reportFlutterError(details);
      };

      // Handle raw platform/native boundary thread errors 
      PlatformDispatcher.instance.onError = (error, stack) {
        errorReporter.report(
          error,
          stack,
          context: "platform",
        );
        return true;
      };

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthState>.value(
              value: authState,
            ),
          ],
          child: DropCityCourierApp(
            authState: authState,
            offlineQueue: offlineQueue,
          ),
        ),
      );
    },
    (error, stack) {
      debugPrint("Uncaught zone error encountered: $error");
      debugPrintStack(stackTrace: stack);
    },
  );
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
    
    // Start processing offline buffers asynchronously
    widget.offlineQueue.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreSession();
      _initPushNotifications();
      _syncTrackingService();

      // High-performance operational state checking (PDC Architecture)
      _trackingStateTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _syncTrackingService(),
      );
    });
  }

  /// Restores the cached user session with slow-network resilience triggers
  Future<void> _restoreSession() async {
    // Show manual continue assistance if connection takes more than 4 seconds
    _restoreHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _restoring) {
        setState(() {
          _restoreHint = "Syncing is taking longer than expected...";
          _showContinueOption = true;
        });
      }
    });

    final restoreFuture = widget.authState.restoreSession();
    
    restoreFuture.then((_) {
      _restoreHintTimer?.cancel();
      if (!mounted) return;
      setState(() => _restoring = false);
    }).catchError((error) {
      _restoreHintTimer?.cancel();
      debugPrint("Session recovery completed with failure state: $error");
    });

    try {
      // Force exit verification sequence after 8 seconds to prevent permanent lockups
      await restoreFuture.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _restoreHint = "Transitioned to Offline Workspace. You can still accept parcels.";
          _showContinueOption = true;
          _restoring = false;
        });
      }
      unawaited(restoreFuture);
    } catch (e) {
      if (mounted) {
        setState(() {
          _restoreHint = "Failed to synchronize profile. Please sign in again.";
          _showContinueOption = true;
          _restoring = false;
        });
      }
    }
  }

  void _continueWithoutWaiting() {
    _restoreHintTimer?.cancel();
    setState(() => _restoring = false);
  }

  /// Resilient Push Notification integration with safety triggers
  Future<void> _initPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      if (Platform.isIOS) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Foreground Push Received: ${message.notification?.title}");
      });

      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        _pendingPushToken = token;
        _tryRegisterPushToken();
      });

      final token = await messaging.getToken().timeout(const Duration(seconds: 5));
      if (token != null && token.isNotEmpty) {
        _pendingPushToken = token;
        _tryRegisterPushToken();
      }
    } catch (error) {
      // Graceful fallback for devices experiencing Google Play Services / FIS failures
      debugPrint("Firebase Messaging registration bypassed safely: $error");
    }
  }

  void _onAuthChanged() {
    _tryRegisterPushToken();
    _syncTrackingService();
  }

  /// Synchronizes background tracking telemetry states with the spatial engine
  Future<void> _syncTrackingService() async {
    if (!widget.authState.isAuthenticated) {
      _trackingExpected = false;
      await _trackingService.stop();
      return;
    }
    try {
      final state = await widget.authState.apiClient.getCourierServiceState();
      final routes = await widget.authState.apiClient.getCourierRoutes();
      await RouteStartReminderService.instance.notifyIfDue(routes);
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
      // Silent catch to prevent UI freeze during intermittent cell connections
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _syncTrackingService();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
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
      debugPrint("Push Token Registration skipped temporarily: $error");
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
                  ? NavigationHubScreen(authState: widget.authState)
                  : const SplashScreen(),
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => ChangeNotifierProvider(
                  create: (_) => CourierSignupController(widget.authState.apiClient),
                  child: const SignupScreen(),
                ),
            '/dashboard': (context) => HomeScreen(authState: widget.authState),
          },
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_shipping_rounded, 
                  size: 64, 
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  "DropCity Courier",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Structuring opportunistic corridors...",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (showContinueOption) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24, 
                        vertical: 12,
                      ),
                    ),
                    child: const Text("Enter Local Workspace"),
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
