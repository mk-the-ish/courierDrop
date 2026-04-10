import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "route_declaration_screen.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return RouteDeclarationScreen(authState: authState);
  }
}
