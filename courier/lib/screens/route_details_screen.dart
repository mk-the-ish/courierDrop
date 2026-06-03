import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen(
      {super.key, required this.route, required this.authState});

  final Map<String, dynamic> route;
  final AuthState authState;

  Future<void> _useRouteTemplate(BuildContext context) async {
    final id = route["id"]?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    try {
      // Check if there is already an active route
      final state = await authState.apiClient.getCourierServiceState();
      if (state["current_route_id"] != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An active route already exists.")),
        );
        return;
      }
      final corridorId = await authState.apiClient.createCorridorFromTemplate(
        routeTemplateId: id,
        plannedStartAtIso: DateTime.now().toUtc().toIso8601String(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Route template activated. Corridor created: $corridorId")),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to use route template: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = route["notes"]?.toString().isNotEmpty == true
        ? route["notes"].toString()
        : "${route["start_location"] ?? "Start"} → ${route["end_location"] ?? "End"}";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                  Chip(
                      label:
                          Text(route["start_location"]?.toString() ?? "Start")),
                  const Icon(Icons.arrow_forward, color: dropCityTransitTeal),
                  Chip(label: Text(route["end_location"]?.toString() ?? "End")),
                  Chip(
                      label: Text(
                          "ETA ${route["declared_eta_minutes"]?.toString() ?? "--"}m")),
                  Chip(
                    label: Text(route["allow_multiple_parcels"] == true
                        ? "MULTI-PARCEL"
                        : "SINGLE PARCEL"),
                    backgroundColor: dropCityActiveMint.withOpacity(.12),
                    labelStyle: const TextStyle(
                        color: dropCityActiveMint, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: dropCityTransitTeal.withOpacity(.08),
                borderRadius: BorderRadius.circular(18)),
            child: const Center(
                child: Icon(Icons.route, size: 72, color: dropCityTransitTeal)),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => _useRouteTemplate(context),
            child: const Text("Use This Route Today"),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Template editing coming soon.")),
              );
            },
            child: const Text("Edit Template"),
          ),
          const SizedBox(height: 18),
          const Text("Route Template Details",
              style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(
              "Declared ETA: ${route["declared_eta_minutes"]?.toString() ?? "--"} minutes"),
          const SizedBox(height: 8),
          Text(
              "Multiple parcels allowed: ${route["allow_multiple_parcels"] == true ? "Yes" : "No"}"),
          const SizedBox(height: 8),
          Text("Notes: ${route["notes"]?.toString() ?? "No notes"}"),
          const SizedBox(height: 18),
          const Text("Delivery History",
              style: TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const ListTile(
              title: Text("Today"),
              subtitle: Text("No history available for templates.")),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Template deletion coming soon.")),
              );
            },
            child: const Text("Delete Template",
                style: TextStyle(color: dropCityErrorRed)),
          ),
        ],
      ),
    );
  }
}
