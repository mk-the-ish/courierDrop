import "dart:async";
import "dart:ui";

import "package:flutter/material.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "dart:io";

import "api/api_client.dart";
import "auth/auth_service.dart";
import "auth/auth_state.dart";
import "screens/dashboard_screen.dart";
import "screens/login_screen.dart";
import "utils/error_reporter.dart";
import "utils/offline_queue.dart";
import "firebase_options.dart";
import "theme.dart";

final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Keep binding initialization and runApp in the same zone.
  await runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
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

      runApp(
          DropCityClientApp(authState: authState, offlineQueue: offlineQueue));
    } catch (e, stack) {
      debugPrint("Failed to initialize app: $e");
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }, (error, stack) {
    debugPrint("Uncaught error: $error");
    debugPrintStack(stackTrace: stack);
  });
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
  bool _showContinueOption = false;
  String? _restoreHint;
  String? _pendingPushToken;
  String? _registeredPushToken;
  StreamSubscription<String>? _tokenRefreshSub;
  Timer? _restoreHintTimer;

  @override
  void initState() {
    super.initState();
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
      await restoreFuture.timeout(
        const Duration(seconds: 8),
      );
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
      final type = message.data["type"]?.toString() ?? "";
      final title = message.notification?.title ?? "Update";
      final body = message.notification?.body ??
          (type == "tracking.sender_eta_update"
              ? "Courier ETA changed."
              : "You have a new update.");
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            type == "tracking.sender_eta_update" ? "ETA update: $body" : body,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
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
    _restoreHintTimer?.cancel();
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
          scaffoldMessengerKey: _scaffoldMessengerKey,
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
                  ? DashboardScreen(authState: widget.authState)
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
            colors: [Color(0xFFE0F7F4), Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, size: 56, color: Colors.teal),
                const SizedBox(height: 16),
                Text(
                  "DropCity",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Preparing your workspace...",
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
