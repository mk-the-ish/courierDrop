import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class SenderHandoffFallbackScreen extends StatefulWidget {
  const SenderHandoffFallbackScreen({
    super.key,
    required this.authState,
    required this.parcelId,
  });

  final AuthState authState;
  final String parcelId;

  @override
  State<SenderHandoffFallbackScreen> createState() => _SenderHandoffFallbackScreenState();
}

class _SenderHandoffFallbackScreenState extends State<SenderHandoffFallbackScreen> {
  final _notesController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  String _issueType = "recipient_unreachable";
  String _resolution = "reschedule";
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitIssue() async {
    setState(() => _submitting = true);
    try {
      await widget.authState.apiClient.reportHandoffIssue(
        parcelId: widget.parcelId,
        issueType: _issueType,
        notes: _notesController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        preferredResolution: _resolution,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue reported. Admin review pending.")),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not report issue: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("External Recipient Fallback")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "No in-app recipient detected",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Use this workflow when recipient cannot complete in-app handoff. You can log a dispute event for admin resolution.",
            style: TextStyle(color: dropCitySlateGrey),
          ),
          const SizedBox(height: 16),
          const Text("Recommended quick checklist", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("1. Confirm recipient phone is reachable."),
          const Text("2. Ask courier to request manual SMS OTP."),
          const Text("3. Ensure recipient is at destination gate."),
          const Text("4. If handoff fails, submit issue below."),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _issueType,
            decoration: const InputDecoration(
              labelText: "Issue type",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: "recipient_unreachable", child: Text("Recipient unreachable")),
              DropdownMenuItem(value: "recipient_not_at_location", child: Text("Recipient not at location")),
              DropdownMenuItem(value: "otp_failed", child: Text("OTP / verification failed")),
              DropdownMenuItem(value: "courier_delay", child: Text("Courier delay / no-show")),
              DropdownMenuItem(value: "other", child: Text("Other")),
            ],
            onChanged: (v) => setState(() => _issueType = v ?? "other"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipientPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Recipient phone (optional)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _resolution,
            decoration: const InputDecoration(
              labelText: "Preferred resolution",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: "reschedule", child: Text("Reschedule delivery")),
              DropdownMenuItem(value: "reassign", child: Text("Reassign courier")),
              DropdownMenuItem(value: "refund", child: Text("Refund")),
              DropdownMenuItem(value: "manual_review", child: Text("Manual admin review")),
            ],
            onChanged: (v) => setState(() => _resolution = v ?? "manual_review"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "Details",
              hintText: "Describe what happened and any attempted resolution.",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submitIssue,
            child: Text(_submitting ? "Submitting..." : "Submit handoff issue"),
          ),
        ],
      ),
    );
  }
}
