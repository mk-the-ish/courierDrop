import "package:flutter/material.dart";

import "../../theme.dart";
import "../../widgets/dropcity_brand.dart";

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const DropCityLogoMark(size: 132),
              const SizedBox(height: 34),
              const Text(
                "Turn Your Daily Commute Into Income",
                textAlign: TextAlign.center,
                style: TextStyle(color: dropCitySafeSlate, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 12),
              const Text(
                "Carry parcels along your existing route - zero detour required.",
                textAlign: TextAlign.center,
                style: TextStyle(color: dropCitySlateGrey, fontSize: 14, height: 1.4),
              ),
              const Spacer(flex: 3),
              CourierPrimaryButton(label: "Join as a Courier", onPressed: () => Navigator.of(context).pushNamed("/signup")),
              const SizedBox(height: 10),
              TextButton(onPressed: () => Navigator.of(context).pushNamed("/login"), child: const Text("I already have an account - Sign In")),
              const SizedBox(height: 8),
              const Text(
                "By continuing you agree to the Courier Terms of Service.",
                textAlign: TextAlign.center,
                style: TextStyle(color: dropCitySlateGrey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
