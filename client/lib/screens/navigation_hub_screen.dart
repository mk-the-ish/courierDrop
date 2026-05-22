import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "dashboard_screen.dart";
import "delivery_creation_flow_screen.dart";
import "parcel_status_screen.dart";

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
      DashboardScreen(authState: widget.authState),
      DeliveryCreationFlowScreen(authState: widget.authState),
      ParcelStatusScreen(authState: widget.authState),
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
              icon: Icon(Icons.local_shipping),
              label: "Deliveries",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Account",
            ),
          ],
        ),
      ),
    );
  }
}
