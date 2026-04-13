import "package:flutter/material.dart";
import "../auth/auth_state.dart";
import "route_declaration_screen.dart";
import "pickup_mode_screen.dart";
import "assigned_parcels_screen.dart";

class CourierDashboardScreen extends StatelessWidget {
  const CourierDashboardScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DropCity Courier"),
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
                "Route Management",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Manage your delivery routes",
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
                      color: Colors.blue.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.route,
                                    color: Colors.blue, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  "0",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Active Routes",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.local_shipping,
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
                                  "Assigned",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.check_circle,
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
                                  "Completed",
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
                        RouteDeclarationScreen(authState: authState),
                  ),
                );
              },
              icon: const Icon(Icons.add_location),
              label: const Text("Declare Route"),
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
                              PickupModeScreen(authState: authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text("Pickup Mode"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AssignedParcelsScreen(authState: authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inventory),
                    label: const Text("Parcels"),
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
