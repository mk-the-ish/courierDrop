import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../auth/auth_state.dart";

class AssignedParcelsScreen extends StatefulWidget {
  const AssignedParcelsScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<AssignedParcelsScreen> createState() => _AssignedParcelsScreenState();
}

class _AssignedParcelsScreenState extends State<AssignedParcelsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _parcels = [];

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    try {
      final parcels = await widget.authState.apiClient.getAssignedParcels();
      if (!mounted) return;
      setState(() => _parcels = parcels);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assigned Parcels")),
      body: RefreshIndicator(
        onRefresh: _loadParcels,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading) const LinearProgressIndicator(),
            if (_parcels.isEmpty && !_isLoading)
              const Text("No assigned parcels."),
            ..._parcels.map((parcel) {
              final status = parcel["status"]?.toString() ?? "-";
              final canRespond = status == "ASSIGNED";
              return Card(
                child: ListTile(
                  title: Text(parcel["id"]?.toString() ?? "Parcel"),
                  subtitle: Text(
                    "${parcel["origin"] ?? "-"} → ${parcel["destination"] ?? "-"}\n"
                    "Status: $status",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Copy Parcel ID",
                        onPressed: () async {
                          final id = parcel["id"]?.toString() ?? "";
                          if (id.isEmpty) {
                            return;
                          }
                          await Clipboard.setData(ClipboardData(text: id));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Parcel ID copied.")),
                          );
                        },
                        icon: const Icon(Icons.copy),
                      ),
                      if (canRespond)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    await widget.authState.apiClient
                                        .acceptParcel(parcel["id"].toString());
                                    await _loadParcels();
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Accept error: $error")),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          child: const Text("Accept"),
                        ),
                      if (canRespond)
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    await widget.authState.apiClient
                                        .declineParcel(parcel["id"].toString());
                                    await _loadParcels();
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Decline error: $error")),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          child: const Text("Decline"),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
