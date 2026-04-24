import "package:flutter/material.dart";

import "../auth/auth_state.dart";

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
  final _nameController = TextEditingController();

  bool _isSignup = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignup) {
        await widget.authState.signUp(
          email,
          password,
          displayName: _nameController.text.trim(),
          role: "courier",
        );
      } else {
        await widget.authState.signIn(email, password);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _testHealthCheck() async {
    try {
      final result = await widget.authState.apiClient.healthCheck();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Backend connected. Status: ${result["status"] ?? "ok"}"),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Backend connection failed: $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Courier Login")),
      body: Form(
        key: _formKey,
        child: Padding(
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
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: "Display name"),
                  validator: (value) {
                    if (!_isSignup) {
                      return null;
                    }
                    if ((value ?? "").trim().isEmpty) {
                      return "Display name is required";
                    }
                    return null;
                  },
                ),
              if (_isSignup) const SizedBox(height: 12),
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
                  if (_isSignup && password.length < 6) {
                    return "Use at least 6 characters";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testHealthCheck,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Test Backend Connection"),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: widget.authState,
                builder: (context, _, __) {
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
      ),
    );
  }
}
