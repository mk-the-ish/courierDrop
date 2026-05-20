import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "map_route_declaration_screen.dart";
import "route_details_screen.dart";

class RouteDeclarationScreen extends StatefulWidget {
  const RouteDeclarationScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<RouteDeclarationScreen> createState() => _RouteDeclarationScreenState();
}

class _RouteDeclarationScreenState extends State<RouteDeclarationScreen> {
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final routes = await widget.authState.apiClient.getCourierRoutes();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load routes: $e")),
      );
    }
  }

  Future<void> _createNewRoute() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapRouteDeclarationScreen(authState: widget.authState),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      // result contains { 'startPoint': LatLng, 'endPoint': LatLng, 'polyline': List<LatLng> }
      if (!mounted) return;
      final routeDetails = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteDetailsScreen(
            authState: widget.authState,
            startPoint: result['startPoint'],
            endPoint: result['endPoint'],
            polyline: result['polyline'],
          ),
        ),
      );
      if (routeDetails != null) {
        await _loadRoutes();
      }
    }
  }

  Future<void> _updateRouteStatus(String routeId, String action) async {
    try {
      await widget.authState.apiClient.updateCourierRouteStatus(
        routeId: routeId,
        action: action,
      );
      await _loadRoutes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route ${action}d.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route update failed: $e")),
      );
    }
  }

  Future<void> _selectRouteAsNext(Map<String, dynamic> route) async {
    final routeId = route["id"]?.toString();
    if (routeId == null) return;

    // First, show date/time picker for start time
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    final plannedStartAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // Show confirmation dialog with selected time
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Use This Route",
          style: TextStyle(color: dropCityTextLight),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Start time: ${plannedStartAt.toString().split('.')[0]}",
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Text(
              "Ready to go?",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dropCityOrangeAccent,
            ),
            child: const Text("Confirm & Use"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Update route with start time and activate
      try {
        // Call API to set start time and activate
        await _updateRouteStatus(routeId, "activate");
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Route active! Starting at ${plannedStartAt.toString().split('.')[0]}"),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to set route: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Routes"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  children: [
                    ..._routes.map(_buildRouteCard),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewRoute,
        backgroundColor: dropCityOrangeAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run,
            size: 64,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 16),
          Text(
            "No routes declared yet",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Create a route to get started",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewRoute,
            icon: const Icon(Icons.add),
            label: const Text("Create Route"),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final id = route["id"]?.toString() ?? "-";
    final status = route["status"]?.toString() ?? "PLANNED";
    final start = route["planned_start_at"]?.toString() ?? "-";
    final eta = route["declared_eta_minutes"]?.toString() ?? "-";
    final canActivate = status == "PLANNED";
    final canComplete = status == "ACTIVE";
    final canCancel = status == "PLANNED";
    final canSelect = status == "ACTIVE" || status == "PLANNED";

    Color badgeColor;
    switch (status) {
      case "ACTIVE":
        badgeColor = Colors.green;
        break;
      case "COMPLETED":
        badgeColor = Colors.blueGrey;
        break;
      case "CANCELLED":
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Route $id",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Planned start: $start"),
            Text("Declared ETA: $eta min"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canActivate ? () => _updateRouteStatus(id, "activate") : null,
                    child: const Text("Activate"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canComplete ? () => _updateRouteStatus(id, "complete") : null,
                    child: const Text("Complete"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canCancel ? () => _updateRouteStatus(id, "cancel") : null,
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
            if (canSelect) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectRouteAsNext(route),
                  icon: const Icon(Icons.check_circle),
                  label: const Text("Use This Route"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dropCityOrangeAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
