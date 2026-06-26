import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final String returnUrl;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    required this.returnUrl,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentHandled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            _checkUrl(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkUrl(url);
          },
          onNavigationRequest: (request) {
            _checkUrl(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkUrl(String url) {
    if (_paymentHandled) return;

    // Duitku redirects to returnUrl after payment
    // returnUrl format: https://domain.com/ticket/{orderId}
    // Check path only (ignore domain) because dev/prod URLs differ
    if (url.contains('/ticket/${widget.orderId}')) {
      _paymentHandled = true;
      Navigator.pop(context, true); // Return success
    }

    // Duitku success callback patterns
    if (url.contains('status=success') || url.contains('result=00')) {
      _paymentHandled = true;
      Navigator.pop(context, true);
    }

    // Duitku cancel/close patterns
    if (url.contains('cancel') || url.contains('status=failed')) {
      _paymentHandled = true;
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran #${widget.orderId}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: AppColors.accent,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}
