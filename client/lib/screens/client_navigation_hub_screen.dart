import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "client_account_screen.dart";
import "dashboard_screen.dart";
import "parcel_status_screen.dart";

class ClientNavigationHubScreen extends StatefulWidget {
  const ClientNavigationHubScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<ClientNavigationHubScreen> createState() => _ClientNavigationHubScreenState();
}

class _ClientNavigationHubScreenState extends State<ClientNavigationHubScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(authState: widget.authState),
      ParcelStatusScreen(authState: widget.authState),
      ClientAccountScreen(authState: widget.authState),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x224B5563))),
            color: Colors.white,
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: dropCityTransitTeal,
              unselectedItemColor: dropCityTextGrey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Home",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2_outlined),
                  label: "Deliveries",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Account",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
