import "dart:async";

import "package:flutter/material.dart";

import "../theme.dart";
import "../widgets/dropcity_brand.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onSplashComplete,
  });

  final VoidCallback onSplashComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onSplashComplete();
    });
  }

  @override
  void dispose() {
    _navigationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: dropCitySafeSlate,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: DropCityWordmark(
                logoSize: 112,
                textColor: dropCityCloudWhite,
                subtitle: true,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                color: dropCityTransitTeal,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
