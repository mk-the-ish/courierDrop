import "package:flutter/material.dart";

import "../auth/auth_state.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignup = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email and password")),
      );
      return;
    }

    if (_isSignup) {
      await widget.authState.signUp(
        email,
        password,
        displayName: _nameController.text.trim(),
        role: "client",
      );
    } else {
      await widget.authState.signIn(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Client Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text("Login"),
                    selected: !_isSignup,
                    onSelected: widget.authState.isBusy
                        ? null
                        : (value) => setState(() => _isSignup = !value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text("Sign up"),
                    selected: _isSignup,
                    onSelected: widget.authState.isBusy
                        ? null
                        : (value) => setState(() => _isSignup = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isSignup)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Display name"),
              ),
            if (_isSignup) const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: widget.authState,
              builder: (context, _) {
                return ElevatedButton(
                  onPressed: widget.authState.isBusy ? null : _submit,
                  child: Text(
                    widget.authState.isBusy
                        ? "Working..."
                        : _isSignup
                            ? "Create account"
                            : "Sign in",
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              "Backend-driven Firebase auth.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
