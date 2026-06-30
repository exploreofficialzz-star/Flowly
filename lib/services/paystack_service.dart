import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paystack checkout, implemented directly against Paystack's own
/// "Inline.js" popup (https://js.paystack.co/v1/inline.js) inside a
/// WebView — no third-party Paystack wrapper package involved.
///
/// Why build it this way instead of using a community package:
///  • Every actively-maintained Flutter Paystack wrapper we found requires
///    either (a) embedding the Paystack SECRET key directly in the app, or
///    (b) a backend that exchanges the secret key for an authorization URL.
///    Embedding the secret key client-side is unsafe — it can be pulled
///    straight out of the APK and used to read/manipulate the whole
///    Paystack account.
///  • Inline.js is the one Paystack-official flow designed to run with the
///    PUBLIC key only, no backend required. That matches exactly what this
///    app needs.
///  • webview_flutter is maintained directly by the Flutter team and has
///    zero dependency on the `http` package, so it can't collide with
///    other plugins (like google_fonts) the way the old flutter_paystack
///    package did.
class PaystackService {
  static final PaystackService _instance = PaystackService._internal();
  factory PaystackService() => _instance;
  PaystackService._internal();

  static const _publicKey = 'pk_live_d145dd30b0e40a54e3d2533dfc544e41ea63fe94';
  static const _channel   = MethodChannel('flowly/platform');
  static const _emailKey  = 'paystack_anon_email';

  bool? _isPlayStore;

  // ── NGN prices in kobo (NGN × 100) ──────────────────────────────────────────
  // Exchange basis: ≈ ₦1,600 / $1 — update periodically.
  static const Map<String, int> prices = {
    'remove_ads_1day':     150000,   // ₦1,500
    'remove_ads_1week':    459900,   // ₦4,599
    'remove_ads_1month':  1349900,   // ₦13,499
    'remove_ads_perm':     749900,   // ₦7,499
    'hints_5':             149900,   // ₦1,499
    'hints_15':            299900,   // ₦2,999
  };

  static const Map<String, String> labels = {
    'remove_ads_1day':   '₦1,500',
    'remove_ads_1week':  '₦4,599',
    'remove_ads_1month': '₦13,499',
    'remove_ads_perm':   '₦7,499',
    'hints_5':           '₦1,499',
    'hints_15':          '₦2,999',
  };

  // ── Play Store detection ──────────────────────────────────────────────────
  Future<bool> isPlayStoreInstall() async {
    if (_isPlayStore != null) return _isPlayStore!;
    try {
      final result = await _channel.invokeMethod<bool>('isPlayStoreInstall');
      _isPlayStore = result ?? true;
    } catch (_) {
      _isPlayStore = true; // safe default
    }
    return _isPlayStore!;
  }

  // ── Anonymous email for Paystack receipt (generated once, reused) ────────────
  Future<String> _getAnonEmail() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_emailKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final id    = Random.secure().nextInt(9999999);
    final email = 'player$id@flowly.app';
    await prefs.setString(_emailKey, email);
    return email;
  }

  String _generateRef() {
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(99999);
    return 'FLY_${ts}_$rand';
  }

  // ── Checkout ──────────────────────────────────────────────────────────────────
  /// Opens the Paystack Inline popup in a full-screen WebView.
  /// Returns true only when Paystack itself confirms the charge succeeded.
  Future<bool> checkout({
    required BuildContext context,
    required String productId,
  }) async {
    final amount = prices[productId];
    if (amount == null) return false;

    final email = await _getAnonEmail();
    final ref   = _generateRef();

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PaystackCheckoutPage(
          publicKey: _publicKey,
          email:     email,
          amountKobo: amount,
          reference: ref,
        ),
      ),
    );
    return result ?? false;
  }
}

// ── Checkout WebView page ───────────────────────────────────────────────────────
class _PaystackCheckoutPage extends StatefulWidget {
  final String publicKey;
  final String email;
  final int    amountKobo;
  final String reference;

  const _PaystackCheckoutPage({
    required this.publicKey,
    required this.email,
    required this.amountKobo,
    required this.reference,
  });

  @override
  State<_PaystackCheckoutPage> createState() => _PaystackCheckoutPageState();
}

class _PaystackCheckoutPageState extends State<_PaystackCheckoutPage> {
  late final WebViewController _controller;
  bool _loading  = true;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A1A))
      ..addJavaScriptChannel(
        'FlowlyPaystack',
        onMessageReceived: (JavaScriptMessage msg) => _handleMessage(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  void _handleMessage(String raw) {
    if (_resolved) return;
    try {
      final data   = jsonDecode(raw) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status == 'success') {
        _resolve(true);
      } else if (status == 'closed') {
        _resolve(false);
      }
    } catch (_) {
      // Ignore malformed messages
    }
  }

  void _resolve(bool success) {
    if (_resolved || !mounted) return;
    _resolved = true;
    Navigator.of(context).pop(success);
  }

  String _buildHtml() {
    final amountKobo = widget.amountKobo;
    final email      = widget.email;
    final ref        = widget.reference;
    final key        = widget.publicKey;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0; padding: 0; height: 100%;
      background: #0A0A1A;
      display: flex; align-items: center; justify-content: center;
      font-family: -apple-system, Roboto, sans-serif;
    }
    #status { color: #ffffff66; font-size: 14px; }
  </style>
</head>
<body>
  <div id="status">Loading secure checkout…</div>
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <script>
    function post(obj) {
      if (window.FlowlyPaystack) {
        window.FlowlyPaystack.postMessage(JSON.stringify(obj));
      }
    }
    window.onload = function () {
      try {
        var handler = PaystackPop.setup({
          key: '$key',
          email: '$email',
          amount: $amountKobo,
          currency: 'NGN',
          ref: '$ref',
          callback: function (response) {
            post({ status: 'success', reference: response.reference });
          },
          onClose: function () {
            post({ status: 'closed' });
          }
        });
        handler.openIframe();
      } catch (e) {
        post({ status: 'closed' });
      }
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => _resolve(false),
        ),
        title: const Text('Secure Checkout',
            style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
      ]),
    );
  }
}
