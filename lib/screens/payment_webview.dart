import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

/// In-app payment page for Duitku.
///
/// Security (PV-1/PV-2): this screen is a *viewer only*. It MUST NOT decide
/// whether a payment succeeded. URLs (including Duitku `resultCode`/redirect
/// targets) can be manipulated by the user/network and are therefore never
/// trusted as proof of payment. When the user returns from the Duitku page
/// (redirect whose path contains `/ticket/{orderId}`) or closes the screen,
/// the caller is responsible for verifying the real status with the backend
/// (`OrderService.checkPaymentStatus`).
class PaymentWebView extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const PaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _returnDetected = false;

  /// Hosts the WebView is allowed to navigate to. Duitku payment pages live on
  /// these hosts. The backend return URL is allowed separately via a path
  /// match (see [_isReturnUrl]) so it works regardless of which environment /
  /// server the device is configured for (dev LAN, staging, production).
  static const List<String> _allowedDuitkuHosts = [
    'duitku.com',
    'sandbox.duitku.com',
    'passport.duitku.com',
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
            _handleUrl(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _handleUrl(url);
          },
          onNavigationRequest: (request) {
            if (_isAllowedNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// The backend redirects to a URL whose path is `/ticket/{orderId}` after the
  /// user leaves the Duitku payment page. We match on PATH only (host-agnostic)
  /// so it works across environments. This is ONLY a completion signal — it is
  /// never treated as proof of payment.
  bool _isReturnUrl(String url) {
    return url.contains('/ticket/${widget.orderId}');
  }

  bool _isAllowedNavigation(String url) {
    // Allow the backend return URL (path-based, any host/environment).
    if (_isReturnUrl(url)) return true;

    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return true; // about:blank, data:, etc. — let it through
    return _allowedDuitkuHosts.any(
      (d) => host == d || host.endsWith('.$d'),
    );
  }

  /// Detects that the user has returned from the Duitku payment page. This is
  /// only a *completion signal* to close the WebView so the caller can verify
  /// the real status server-side. It is NEVER treated as success.
  void _handleUrl(String url) {
    if (_returnDetected) return;
    if (_isReturnUrl(url)) {
      _returnDetected = true;
      if (mounted) Navigator.pop(context);
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
          onPressed: () => Navigator.pop(context),
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
