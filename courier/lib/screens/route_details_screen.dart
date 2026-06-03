import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key, required this.route, required this.authState});

  final Map<String, dynamic> route;
  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route["name"]?.toString() ?? "Route Details"),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(route["start_location"]?.toString() ?? "Start")),
                  const Icon(Icons.arrow_forward, color: dropCityTransitTeal),
                  Chip(label: Text(route["end_location"]?.toString() ?? "End")),
                  const Chip(label: Text("12.4km")),
                  const Chip(label: Text("ETA 35m")),
                  Chip(
                    label: const Text("REUSABLE"),
                    backgroundColor: dropCityActiveMint.withOpacity(.12),
                    labelStyle: const TextStyle(color: dropCityActiveMint, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: dropCityTransitTeal.withOpacity(.08), borderRadius: BorderRadius.circular(18)),
            child: const Center(child: Icon(Icons.route, size: 72, color: dropCityTransitTeal)),
          ),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Text("Buffer: 500m"), Text("Waypoints: 23"), Text("Last used: Today")]),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: () {}, child: const Text("Use This Route Today")),
          OutlinedButton(onPressed: () {}, child: const Text("Edit Template")),
          const SizedBox(height: 18),
          const Text("Delivery History", style: TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
          const ListTile(title: Text("Today"), subtitle: Text("2 parcels - Score 78.4")),
          TextButton(onPressed: () {}, child: const Text("Delete Template", style: TextStyle(color: dropCityErrorRed))),
        ],
      ),
    );
  }
}
