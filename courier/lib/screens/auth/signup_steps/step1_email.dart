import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../controllers/signup_controller.dart";
import "../../../theme.dart";
import "../../../widgets/dropcity_brand.dart";

class CourierSignupStep1Email extends StatefulWidget {
  const CourierSignupStep1Email({super.key});

  @override
  State<CourierSignupStep1Email> createState() => _CourierSignupStep1EmailState();
}

class _CourierSignupStep1EmailState extends State<CourierSignupStep1Email> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _terms = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _next() async {
    final email = _email.text.trim();
    if (!email.contains("@") || _password.text.length < 8 || _password.text != _confirm.text || !_terms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete valid credentials and accept terms.")));
      return;
    }
    final c = context.read<CourierSignupController>();
    await c.submitStep1(email: email, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<CourierSignupController>().isLoading;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Email and Password", style: TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.mail_outline))),
      const SizedBox(height: 14),
      TextField(controller: _password, obscureText: _obscure, decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)))),
      const SizedBox(height: 14),
      TextField(controller: _confirm, obscureText: _obscureConfirm, decoration: InputDecoration(labelText: "Confirm Password", prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)))),
      const SizedBox(height: 10),
      CheckboxListTile(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), activeColor: dropCityTransitTeal, controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text("I agree to the Courier Terms of Service", style: TextStyle(color: dropCitySlateGrey, fontSize: 12))),
      const Row(children: [Icon(Icons.info_outline, size: 16, color: dropCitySlateGrey), SizedBox(width: 6), Expanded(child: Text("You will need your driver's licence and vehicle details in later steps.", style: TextStyle(color: dropCitySlateGrey, fontSize: 12, fontStyle: FontStyle.italic)))]),
      const SizedBox(height: 26),
      CourierPrimaryButton(label: "Continue ?", loading: loading, onPressed: _next),
    ]);
  }
}
