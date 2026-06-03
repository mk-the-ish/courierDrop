import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class SenderHandoffFallbackScreen extends StatelessWidget {
  const SenderHandoffFallbackScreen({
    super.key,
    required this.authState,
    required this.parcelId,
  });

  final AuthState authState;
  final String parcelId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      appBar: AppBar(
        backgroundColor: dropCityCloudWhite,
        foregroundColor: dropCitySafeSlate,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Delivery Help",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _WarningBanner(parcelId: parcelId),
          const SizedBox(height: 18),
          _ActionCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green.shade600,
            iconBackground: Colors.green.shade50,
            title: "I received my parcel",
            subtitle: "Confirm manual delivery",
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.cancel_outlined,
            iconColor: Colors.red.shade600,
            iconBackground: Colors.red.shade50,
            title: "I did NOT receive my parcel",
            subtitle: "Flag as issue",
            onTap: () async {
              await authState.apiClient.reportHandoffIssue(
                parcelId: parcelId,
                issueType: "recipient_disputed_delivery",
                notes: "Recipient reported non-receipt from handoff fallback screen.",
                preferredResolution: "manual_review",
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Issue reported to DropCity Support.")),
              );
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.call_outlined,
            iconColor: dropCityTransitTeal,
            iconBackground: dropCityTransitTeal.withOpacity(0.10),
            title: "Contact the courier",
            subtitle: "Call or message your courier",
            onTap: () {},
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: const [
                  Icon(Icons.headset_mic_outlined, color: dropCityTransitTeal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Report to DropCity Support",
                      style: TextStyle(
                        color: dropCityTransitTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: dropCityTransitTeal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          const Text(
            "PARCEL EVIDENCE",
            style: TextStyle(
              color: dropCitySlateGrey,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pickup photo and time for your reference.",
            style: TextStyle(color: dropCitySafeSlate, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: dropCitySlateGrey.withOpacity(0.14),
                  ),
                  child: const Icon(Icons.photo_outlined, size: 44, color: dropCitySlateGrey),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pickup photo",
                        style: TextStyle(
                          color: dropCitySafeSlate,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "10 May 2025 at 09:32 AM",
                        style: TextStyle(color: dropCitySlateGrey, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Proof reference: DC12345678",
                        style: TextStyle(color: dropCitySlateGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.parcelId});

  final String parcelId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dropCityAlertAmber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dropCityAlertAmber.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: dropCityAlertAmber.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Handoff not completed",
                  style: TextStyle(
                    color: Color(0xFFB96D00),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your courier reported an issue at the dropoff point.",
                  style: TextStyle(
                    color: dropCitySafeSlate.withOpacity(0.84),
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Parcel ID: $parcelId",
                  style: const TextStyle(color: dropCitySlateGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dropCitySlateGrey.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 38),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: dropCitySafeSlate,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: dropCitySlateGrey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: dropCitySlateGrey, size: 32),
          ],
        ),
      ),
    );
  }
}
