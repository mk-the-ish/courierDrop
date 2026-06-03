import "package:flutter/material.dart";
import "../auth/auth_state.dart";
import "../theme.dart";
import "map_route_declaration_screen.dart";
import "route_details_screen.dart";

class RouteDeclarationScreen extends StatefulWidget {
  const RouteDeclarationScreen({super.key, required this.authState});
  final AuthState authState;
  @override
  State<RouteDeclarationScreen> createState() => _State();
}

class _State extends State<RouteDeclarationScreen> {
  bool loading = true;
  List<Map<String, dynamic>> templates = [];
  Map<String, dynamic>? activeRoute;
  String courierState = "OFFLINE";
  String? _selectedTemplateId;
  bool isStartingRoute = false;
  bool isStoppingRoute = false;
  String filter = "All";

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final templates = await widget.authState.apiClient.getRouteTemplates();
      final state = await widget.authState.apiClient.getCourierServiceState();

      Map<String, dynamic>? active;
      if (state["current_route_id"] != null) {
        try {
          final corridors = await widget.authState.apiClient.getMyCorridors();
          active = corridors.firstWhere(
            (c) => c["id"] == state["current_route_id"],
            orElse: () => {},
          );
          if (active.isEmpty) active = null;
        } catch (_) {
          active = null;
        }
      }

      if (mounted) {
        setState(() {
          this.templates = templates;
          activeRoute = active;
          courierState = state["state"]?.toString() ?? "OFFLINE";
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _startRoute() async {
    if (activeRoute == null) return;
    setState(() => isStartingRoute = true);
    try {
      await widget.authState.apiClient.startCourierTravel(activeRoute!["id"]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route started")),
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start route: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isStartingRoute = false);
    }
  }

  Future<void> _stopRoute() async {
    setState(() => isStoppingRoute = true);
    try {
      await widget.authState.apiClient.endCourierTravel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route ended")),
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to end route: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isStoppingRoute = false);
    }
  }

  Future<void> _addNewRoute() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            MapRouteDeclarationScreen(authState: widget.authState)));
    if (result != null && mounted) {
      await load();
    }
  }

  Future<void> _showScheduleModal(String templateId) async {
    // Offer Start Now or pick date/time
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Start Now'),
            onTap: () => Navigator.of(ctx).pop('now'),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Pick date & time'),
            onTap: () => Navigator.of(ctx).pop('pick'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null) return;

    DateTime planned;
    if (choice == 'now') {
      planned = DateTime.now().toUtc();
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null) return;
      planned =
          DateTime(date.year, date.month, date.day, time.hour, time.minute)
              .toUtc();
    }

    try {
      setState(() => isStartingRoute = true);
      final corridorId =
          await widget.authState.apiClient.createCorridorFromTemplate(
        routeTemplateId: templateId,
        plannedStartAtIso: planned.toIso8601String(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheduled route. Corridor: $corridorId')),
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to schedule: $e')));
    } finally {
      if (mounted) setState(() => isStartingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text("My Routes"), actions: [
        Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FloatingActionButton.small(
                heroTag: "addRoute",
                backgroundColor: dropCityTransitTeal,
                onPressed: _addNewRoute,
                child: const Icon(Icons.add, color: Colors.white)))
      ]),
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // Active route card at top
                if (activeRoute != null)
                  _ActiveRouteCard(
                    route: activeRoute!,
                    state: courierState,
                    onStart: isStartingRoute ? null : _startRoute,
                    onStop: isStoppingRoute ? null : _stopRoute,
                    isStarting: isStartingRoute,
                    isStopping: isStoppingRoute,
                  ),
                if (activeRoute != null) const SizedBox(height: 16),

                // Template selector
                if (templates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedTemplateId,
                          hint: const Text('Select route to schedule'),
                          items: templates
                              .map((t) => DropdownMenuItem(
                                    value: t['id']?.toString(),
                                    child: Text(t['notes']
                                                ?.toString()
                                                .isNotEmpty ==
                                            true
                                        ? t['notes'].toString()
                                        : '${t['start_location'] ?? 'Start'} → ${t['end_location'] ?? 'End'}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedTemplateId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _selectedTemplateId == null
                              ? null
                              : () => _showScheduleModal(_selectedTemplateId!),
                          child: const Text('Schedule'))
                    ]),
                  ),
                if (loading) const LinearProgressIndicator(),
                if (templates.isEmpty && !loading) _Empty(onAdd: _addNewRoute),
                ...templates.map((template) => _RouteCard(
                    route: template,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RouteDetailsScreen(
                            route: template, authState: widget.authState)))))
              ])));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(children: [
        const Icon(Icons.route, size: 72, color: dropCitySlateGrey),
        const SizedBox(height: 14),
        const Text("No routes yet",
            style: TextStyle(
                color: dropCitySafeSlate,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        const Text("Declare your first commute route",
            style: TextStyle(color: dropCitySlateGrey)),
        const SizedBox(height: 18),
        ElevatedButton(onPressed: onAdd, child: const Text("Add Route"))
      ]));
}

class _ActiveRouteCard extends StatelessWidget {
  const _ActiveRouteCard({
    required this.route,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.isStarting,
    required this.isStopping,
  });

  final Map<String, dynamic> route;
  final String state;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final bool isStarting;
  final bool isStopping;

  @override
  Widget build(BuildContext context) {
    final startName = route["start_place_name"]?.toString().isNotEmpty == true
        ? route["start_place_name"].toString()
        : route["start_location"]?.toString() ?? "Start";
    final endName = route["end_place_name"]?.toString().isNotEmpty == true
        ? route["end_place_name"].toString()
        : route["end_location"]?.toString() ?? "End";
    final statusText = state == "TRAVELLING" ? "ACTIVE ROUTE" : "SCHEDULED ROUTE";
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: dropCityTransitTeal.withOpacity(.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(statusText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dropCitySafeSlate)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state == "TRAVELLING" ? dropCityActiveMint : dropCitySlateGrey.withOpacity(.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(state, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(startName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dropCitySafeSlate)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.arrow_forward, size: 18, color: dropCitySlateGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(endName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dropCitySafeSlate), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text("ETA ${route["declared_eta_minutes"]?.toString() ?? "--"}m")),
                if (route["notes"]?.toString().isNotEmpty == true)
                  Chip(
                    label: Text(route["notes"].toString()),
                    backgroundColor: dropCityActiveMint.withOpacity(.12),
                    labelStyle: const TextStyle(color: dropCityActiveMint, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state == "TRAVELLING" || isStarting ? null : onStart,
                    icon: isStarting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(isStarting ? "Starting..." : "Start Route"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state == "TRAVELLING" && !isStopping ? onStop : null,
                    icon: isStopping
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.stop),
                    label: Text(isStopping ? "Stopping..." : "End Route"),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onTap});
  final Map<String, dynamic> route;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location display: use place name if available, else coordinates
                    Text(
                      route["start_place_name"]?.toString().isNotEmpty == true
                          ? route["start_place_name"].toString()
                          : route["start_location"]?.toString() ?? "Start",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: dropCitySafeSlate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward,
                            size: 18, color: dropCitySlateGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route["end_place_name"]?.toString().isNotEmpty ==
                                    true
                                ? route["end_place_name"].toString()
                                : route["end_location"]?.toString() ?? "End",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: dropCitySafeSlate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Route metadata
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      Chip(
                        label: Text(
                            "ETA ${route["declared_eta_minutes"]?.toString() ?? "--"}m"),
                      ),
                      Chip(
                        label: const Text("REUSABLE"),
                        backgroundColor: dropCityActiveMint.withOpacity(.12),
                        labelStyle: const TextStyle(
                            color: dropCityActiveMint,
                            fontWeight: FontWeight.w800),
                      ),
                      if (route["notes"]?.toString().isNotEmpty == true)
                        Chip(
                          label: Text(
                            route["notes"].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ])
                  ]))));
}
