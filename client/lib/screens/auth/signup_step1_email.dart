import "package:flutter/material.dart";

import "../../theme.dart";
import "../../widgets/dropcity_brand.dart";
import "../terms_webview_screen.dart";

class ClientSignupStep1Email extends StatefulWidget {
  const ClientSignupStep1Email({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  final Future<void> Function(String email, String password) onNext;
  final VoidCallback onBack;

  @override
  State<ClientSignupStep1Email> createState() => _ClientSignupStep1EmailState();
}

class _ClientSignupStep1EmailState extends State<ClientSignupStep1Email> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_acceptedTerms) {
      if (!_acceptedTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please agree to the Terms of Service.")),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.onNext(_emailController.text.trim(), _passwordController.text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text("Create Account"),
        actions: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text("Step 1 of 2", style: TextStyle(color: dropCitySlateGrey)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              "Your email and password",
              style: TextStyle(
                color: dropCitySafeSlate,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: "your@email.com",
                      labelText: "Email",
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = (value ?? "").trim();
                      if (email.isEmpty) return "Email is required";
                      if (!email.contains("@")) return "Please enter a valid email";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: "Create a password",
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      final password = value ?? "";
                      if (password.isEmpty) return "Password is required";
                      if (password.length < 8) return "Use at least 8 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      hintText: "Confirm your password",
                      labelText: "Confirm Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if ((value ?? "").isEmpty) return "Please confirm your password";
                      if (value != _passwordController.text) return "Passwords do not match";
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  activeColor: dropCityTransitTeal,
                  onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "I agree to the ",
                        style: TextStyle(color: dropCitySlateGrey, fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TermsWebViewScreen()),
                        ),
                        child: const Text(
                          "Terms of Service",
                          style: TextStyle(
                            color: dropCityTransitTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            DropCityPrimaryButton(
              label: "Continue",
              loading: _isLoading,
              onPressed: _acceptedTerms ? _handleNext : null,
            ),
          ],
        ),
      ),
    );
  }
}
