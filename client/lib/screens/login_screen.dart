import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "auth/signup_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await widget.authState.signIn(email, password);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Client Login")),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (value) {
                  final email = (value ?? "").trim();
                  if (email.isEmpty) {
                    return "Email is required";
                  }
                  if (!email.contains("@")) {
                    return "Enter a valid email";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!widget.authState.isBusy) {
                    _submit();
                  }
                },
                decoration: InputDecoration(
                  labelText: "Password",
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  final password = value ?? "";
                  if (password.isEmpty) {
                    return "Password is required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.authState.isBusy ? null : _showForgotPasswordDialog,
                  child: const Text("Forgot password?"),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: widget.authState,
                builder: (context, _) {
                  return ElevatedButton(
                    onPressed: widget.authState.isBusy ? null : _submit,
                    child: Text(
                      widget.authState.isBusy
                          ? "Working..."
                          : "Sign in",
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.authState.isBusy
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ClientSignupScreen(authState: widget.authState),
                          ),
                        );
                      },
                child: const Text("Create account"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text.trim());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset password"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "Email"),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains("@")) {
                return;
              }
              try {
                await widget.authState.requestPasswordReset(email);
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reset email sent.")),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                );
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }
}
