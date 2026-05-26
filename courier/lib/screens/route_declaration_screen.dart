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
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _routes = [];
  String _serviceState = "OFFLINE";
  String? _selectedRouteId;
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
      final templatesFuture = widget.authState.apiClient.getRouteTemplates();
      final routesFuture = widget.authState.apiClient.getCourierRoutes();
      final serviceStateFuture = widget.authState.apiClient.getCourierServiceState();
      final templates = await templatesFuture;
      final routes = await routesFuture;
      final serviceState = await serviceStateFuture;
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _routes = routes;
        _serviceState = serviceState["state"]?.toString() ?? "OFFLINE";
        _selectedRouteId ??= _routes.isNotEmpty ? _routes.first["id"]?.toString() : null;
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

  Future<void> _selectRouteAsNext(Map<String, dynamic> routeTemplate) async {
    final routeTemplateId = routeTemplate["id"]?.toString();
    if (routeTemplateId == null) return;

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
          "Use This Route Template",
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
              "A new corridor will be created from this template.",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 8),
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
      // Create a new corridor from this route template
      try {
        final corridorId = await widget.authState.apiClient.createCorridorFromTemplate(
          routeTemplateId: routeTemplateId,
          plannedStartAtIso: plannedStartAt.toIso8601String(),
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Route scheduled. Corridor $corridorId created for ${plannedStartAt.toString().split('.')[0]}"),
          ),
        );
        // Reload routes to show updated status
        await _loadRoutes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to use route template: $e")),
        );
      }
    }
  }

  Future<void> _startSelectedRoute() async {
    final selectedRoute = _routes.firstWhere(
      (route) => route["id"]?.toString() == _selectedRouteId,
      orElse: () => const <String, dynamic>{},
    );
    final routeId = selectedRoute["id"]?.toString();
    final corridorId = selectedRoute["corridor_id"]?.toString();
    if (routeId == null || routeId.isEmpty || corridorId == null || corridorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a valid scheduled route first.")),
      );
      return;
    }
    try {
      await widget.authState.apiClient.updateCourierRouteStatus(
        routeId: routeId,
        action: "activate",
      );
      await widget.authState.apiClient.startCourierTravel(corridorId);
      await _loadRoutes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to start route: $e")),
      );
    }
  }

  Future<void> _endSelectedRoute() async {
    if (_selectedRouteId == null || _selectedRouteId!.isEmpty) return;
    try {
      await widget.authState.apiClient.updateCourierRouteStatus(
        routeId: _selectedRouteId!,
        action: "complete",
      );
      await widget.authState.apiClient.endCourierTravel();
      await _loadRoutes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to end route: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Route Templates"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  children: [
                    _buildRouteControlsCard(),
                    const SizedBox(height: 12),
                    ..._templates.map(_buildRouteCard),
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
            "No route templates yet",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Create a route template to reuse daily",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewRoute,
            icon: const Icon(Icons.add),
            label: const Text("Create Route Template"),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteControlsCard() {
    final travelling = _serviceState == "TRAVELLING";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Route Controls",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Current status: $_serviceState"),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedRouteId,
              decoration: const InputDecoration(
                labelText: "Scheduled route instance",
                border: OutlineInputBorder(),
              ),
              items: _routes
                  .map(
                    (route) => DropdownMenuItem<String>(
                      value: route["id"]?.toString(),
                      child: Text(
                        "${route["status"] ?? "PLANNED"} • ${(route["planned_start_at"]?.toString() ?? "-").replaceFirst("T", " ").split(".").first}",
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedRouteId = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: travelling ? null : _startSelectedRoute,
                    child: const Text("Start Route"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: travelling ? _endSelectedRoute : null,
                    child: const Text("End Route"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final id = route["id"]?.toString() ?? "-";
    // Route templates don't have status like ACTIVE/COMPLETED - they're always reusable
    final eta = route["declared_eta_minutes"]?.toString() ?? "-";
    final notes = route["notes"]?.toString() ?? "";

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
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "TEMPLATE",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Declared ETA: $eta min"),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Notes: $notes",
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _selectRouteAsNext(route),
                icon: const Icon(Icons.check_circle),
                label: const Text("Use This Route Template"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dropCityOrangeAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
