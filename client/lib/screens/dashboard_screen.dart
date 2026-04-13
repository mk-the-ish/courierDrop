import "package:flutter/material.dart";
import "../auth/auth_state.dart";
import "parcel_request_screen.dart";
import "progress_screen.dart";
import "parcel_status_screen.dart";

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DropCity Client"),
        actions: [
          TextButton(
            onPressed: authState.signOut,
            child: const Text(
              "Sign out",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Parcel Delivery Management",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Select an action to continue",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Quick stats
                    Card(
                      color: Colors.teal.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.local_shipping,
                                    color: Colors.teal, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Pending",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Completed",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.location_on,
                                    color: Colors.orange, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "In Transit",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ParcelRequestScreen(authState: authState),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle),
              label: const Text("Request Parcel"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProgressScreen(authState: authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text("Progress"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ParcelStatusScreen(authState: authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text("Status"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
