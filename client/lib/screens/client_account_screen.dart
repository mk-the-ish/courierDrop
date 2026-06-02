import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class ClientAccountScreen extends StatelessWidget {
  const ClientAccountScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    final email = user?.email ?? "Unknown account";
    final initial = email.isNotEmpty ? email[0].toUpperCase() : "D";

    return Scaffold(
      appBar: AppBar(title: const Text("Account")),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 110),
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: dropCityTransitTeal,
                foregroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "DropCity Client",
                style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: dropCitySlateGrey, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: dropCityActiveMint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "Verified",
                  style: TextStyle(
                    color: dropCityActiveMint,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: "PROFILE",
            rows: const [
              _AccountRow(icon: Icons.edit_outlined, label: "Edit Profile"),
              _AccountRow(icon: Icons.lock_outline, label: "Change Password"),
            ],
          ),
          _Section(
            title: "DELIVERIES",
            rows: const [
              _AccountRow(icon: Icons.history, label: "Delivery History"),
              _AccountRow(icon: Icons.bookmark_border, label: "Saved Addresses"),
            ],
          ),
          _Section(
            title: "ACCOUNT",
            rows: const [
              _AccountRow(icon: Icons.notifications_none, label: "Notifications"),
              _AccountRow(icon: Icons.privacy_tip_outlined, label: "Privacy Settings"),
            ],
          ),
          _Section(
            title: "SUPPORT",
            rows: const [
              _AccountRow(icon: Icons.help_outline, label: "Help Center"),
              _AccountRow(icon: Icons.support_agent, label: "Contact Support"),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: dropCityErrorRed),
              title: const Text(
                "Sign Out",
                style: TextStyle(
                  color: dropCityErrorRed,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: authState.signOut,
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              "v1.0.0",
              style: TextStyle(color: dropCitySlateGrey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_AccountRow> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                color: dropCitySlateGrey,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(child: Column(children: rows)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: dropCityTransitTeal),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: dropCitySlateGrey),
      onTap: () {},
    );
  }
}
