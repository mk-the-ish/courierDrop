import "package:flutter/material.dart";

import "../auth/auth_state.dart";

class ClientAccountScreen extends StatelessWidget {
  const ClientAccountScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    return Scaffold(
      appBar: AppBar(title: const Text("Account")),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Signed in"),
              subtitle: Text(user?.email ?? "Unknown account"),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text("Security"),
              subtitle: const Text("Use forgot password from login when needed."),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: authState.signOut,
            icon: const Icon(Icons.logout),
            label: const Text("Sign out"),
          ),
        ],
      ),
    );
  }
}

