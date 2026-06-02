import "package:flutter/material.dart";

import "../../theme.dart";
import "../../widgets/dropcity_brand.dart";

class CourierAppRedirectScreen extends StatelessWidget {
  const CourierAppRedirectScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text("Courier App Required"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const DropCityLogoMark(size: 96),
              const SizedBox(height: 24),
              const Text(
                "You need the courier version of DropCity",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "The courier app includes route setup, vehicle verification, capacity, and live delivery tools. Please download the DropCity Courier app to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dropCitySlateGrey,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dropCityTransitTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dropCityTransitTeal.withOpacity(0.22),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.directions_car_filled, color: dropCityTransitTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Search for “DropCity Courier” in your app store or ask support for the installer.",
                        style: TextStyle(color: dropCitySafeSlate),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              DropCityPrimaryButton(
                label: "Back to account options",
                icon: Icons.arrow_back,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



