import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaystackService {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final PaystackService _instance = PaystackService._internal();
  factory PaystackService() => _instance;
  PaystackService._internal();

  static const _publicKey = 'pk_live_d145dd30b0e40a54e3d2533dfc544e41ea63fe94';
  static const _channel   = MethodChannel('flowly/platform');
  static const _emailKey  = 'paystack_anon_email';

  final PaystackPlugin _plugin = PaystackPlugin();
  bool _initialized = false;
  bool? _isPlayStore;

  // ── NGN prices in kobo (NGN × 100) ──────────────────────────────────────────
  // Exchange basis: ≈ ₦1,600 / $1  (update periodically)
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

  // ── Init (called lazily) ──────────────────────────────────────────────────────
  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _plugin.initialize(publicKey: _publicKey);
    _initialized = true;
  }

  // ── Play Store detection ──────────────────────────────────────────────────────
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
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_emailKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final id    = Random.secure().nextInt(9999999);
    final email = 'player$id@flowly.app';
    await prefs.setString(_emailKey, email);
    return email;
  }

  // ── Reference generator ───────────────────────────────────────────────────────
  String _generateRef() {
    final ts   = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(99999);
    return 'FLY_${ts}_$rand';
  }

  // ── Checkout ──────────────────────────────────────────────────────────────────
  /// Returns true if the payment was confirmed successful by Paystack.
  Future<bool> checkout({
    required BuildContext context,
    required String productId,
  }) async {
    final amount = prices[productId];
    if (amount == null) return false;

    await _ensureInit();
    final email = await _getAnonEmail();

    final charge = Charge()
      ..amount    = amount
      ..email     = email
      ..currency  = 'NGN'
      ..reference = _generateRef()
      ..putMetaData('product_id', productId)
      ..putMetaData('app', 'com.chastechgroup.flowly');

    try {
      final response = await _plugin.checkout(
        context,
        charge: charge,
        method:     CheckoutMethod.card,
        fullscreen: false,
      );
      return response.status == true;
    } catch (_) {
      return false;
    }
  }
}
