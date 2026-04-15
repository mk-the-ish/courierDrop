import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "courier_dashboard_screen.dart";
import "courier_info_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedVehicleInfo = false;
  bool _hasVehicleInfo = false;

  @override
  void initState() {
    super.initState();
    _checkVehicleInfo();
  }

  Future<void> _checkVehicleInfo() async {
    try {
      // Try to fetch vehicle info for current courier
      await widget.authState.apiClient.getMyVehicle();
      // If successful, user has vehicle info
      setState(() {
        _hasVehicleInfo = true;
        _checkedVehicleInfo = true;
      });
    } catch (e) {
      // User doesn't have vehicle info yet
      setState(() {
        _hasVehicleInfo = false;
        _checkedVehicleInfo = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking vehicle info
    if (!_checkedVehicleInfo) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // User has vehicle info - show dashboard
    if (_hasVehicleInfo) {
      return CourierDashboardScreen(authState: widget.authState);
    }

    // User needs to complete vehicle info
    return CourierInfoScreen(authState: widget.authState);
  }
}
