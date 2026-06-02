import "package:flutter/material.dart";
import "package:webview_flutter/webview_flutter.dart";

import "../theme.dart";

class TermsWebViewScreen extends StatefulWidget {
  const TermsWebViewScreen({super.key});

  @override
  State<TermsWebViewScreen> createState() => _TermsWebViewScreenState();
}

class _TermsWebViewScreenState extends State<TermsWebViewScreen> {
  static const _termsUrl = String.fromEnvironment(
    "DROPCITY_TERMS_URL",
    defaultValue: "https://dropcity-admin.vercel.app/terms",
  );

  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(_termsUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Terms of Service")),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              color: dropCityTransitTeal,
              backgroundColor: dropCityCloudWhite,
            ),
        ],
      ),
    );
  }
}



