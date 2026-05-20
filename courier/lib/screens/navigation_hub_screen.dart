import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "assigned_parcels_screen.dart";
import "courier_dashboard_screen.dart";
import "route_declaration_screen.dart";
import "settings_screen.dart";

class NavigationHubScreen extends StatefulWidget {
  const NavigationHubScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<NavigationHubScreen> createState() => _NavigationHubScreenState();
}

class _NavigationHubScreenState extends State<NavigationHubScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      CourierDashboardScreen(authState: widget.authState),
      RouteDeclarationScreen(authState: widget.authState),
      AssignedParcelsScreen(authState: widget.authState),
      SettingsScreen(authState: widget.authState),
    ];
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.grey[900],
          elevation: 8,
          selectedItemColor: dropCityOrangeAccent,
          unselectedItemColor: dropCityTextGrey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.route),
              label: "Routes",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: "Parcels",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
