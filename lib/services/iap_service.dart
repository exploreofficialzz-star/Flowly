import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import 'paystack_service.dart';

/// Purchase state exposed to the UI layer.
enum IapPurchaseState { idle, pending, processing, error }

class IapService extends ChangeNotifier {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  // ── Public state ────────────────────────────────────────────────────────────
  bool get available     => _available;
  bool get adsRemoved    => _adsRemoved;
  bool get purchasing    => _purchaseState != IapPurchaseState.idle;
  String? get purchaseError => _purchaseError;
  String? get removeAdsExpiryLabel => _expiryLabel();

  IapPurchaseState get purchaseState => _purchaseState;

  /// Store products in display order (day → week → month).
  List<ProductDetails> get products => List.unmodifiable(_products);

  // ── Private ─────────────────────────────────────────────────────────────────
  bool _available = false;
  bool _adsRemoved = false;
  bool _isPlayStore = true;        // false = sideloaded → use Paystack
  DateTime? _removeAdsExpiry;
  List<ProductDetails> _products = [];
  IapPurchaseState _purchaseState = IapPurchaseState.idle;
  String? _purchaseError;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool get isPlayStore => _isPlayStore;

  ProductDetails? productById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadExpiry();

    // Detect install source before IAP init
    _isPlayStore = await PaystackService().isPlayStoreInstall();

    _available = await InAppPurchase.instance.isAvailable();
    if (!_available) return;

    // Listen to ALL purchase updates (new purchases + pending + restored)
    _purchaseSub = InAppPurchase.instance.purchaseStream
        .listen(_onPurchaseUpdates, onError: _onPurchaseStreamError);

    await _loadProducts();
  }

  // ── Load products ────────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    try {
      final response = await InAppPurchase.instance
          .queryProductDetails(AppConstants.iapProductIds);

      _products = response.productDetails
        ..sort((a, b) => _sortOrder(a.id) - _sortOrder(b.id));

      notifyListeners();
    } catch (_) {}
  }

  int _sortOrder(String id) {
    switch (id) {
      case AppConstants.iapRemoveAds1Day:   return 0;
      case AppConstants.iapRemoveAds1Week:  return 1;
      case AppConstants.iapRemoveAds1Month: return 2;
      default:                              return 3;
    }
  }

  // ── Purchase flow ────────────────────────────────────────────────────────────
  Future<void> buyProduct(ProductDetails product) async {
    if (!_available || purchasing) return;

    _setPurchaseState(IapPurchaseState.processing);
    _purchaseError = null;

    try {
      final param = PurchaseParam(productDetails: product);

      // ⚠️  CONSUMABLE — time-limited plans MUST be consumable so the user
      //     can re-purchase after their plan expires. Non-consumable products
      //     can only ever be bought once per Google account.
      await InAppPurchase.instance.buyConsumable(purchaseParam: param);
    } catch (e) {
      _setError('Purchase failed. Please try again.');
    }
  }

  // ── Purchase stream handler ──────────────────────────────────────────────────
  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Payment is being processed by the user's bank / payment method.
          // Do NOT grant entitlement yet. Show pending UI.
          _setPurchaseState(IapPurchaseState.pending);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Payment confirmed — grant the entitlement.
          _applyPurchase(purchase.productID);
          // Always complete the purchase to tell Play Billing the transaction
          // is acknowledged. Unacknowledged purchases are auto-refunded after 3 days.
          InAppPurchase.instance.completePurchase(purchase);
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Purchase failed.';
          _setError(_friendlyError(msg));
          if (purchase.pendingCompletePurchase) {
            InAppPurchase.instance.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _setPurchaseState(IapPurchaseState.idle);
          break;
      }
    }
  }

  void _onPurchaseStreamError(Object error) {
    _setError('Store connection error. Please try again.');
  }

  // ── Apply entitlement ────────────────────────────────────────────────────────
  Future<void> _applyPurchase(String productId) async {
    Duration? duration;
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:   duration = const Duration(days: 1);   break;
      case AppConstants.iapRemoveAds1Week:  duration = const Duration(days: 7);   break;
      case AppConstants.iapRemoveAds1Month: duration = const Duration(days: 30);  break;
      default: break;
    }
    if (duration == null) return;

    // If an existing plan hasn't expired, stack on top of it
    final base = (_removeAdsExpiry != null && _removeAdsExpiry!.isAfter(DateTime.now()))
        ? _removeAdsExpiry!
        : DateTime.now();
    _removeAdsExpiry = base.add(duration);
    _adsRemoved = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyRemoveAdsExpiry,
          _removeAdsExpiry!.millisecondsSinceEpoch);
    } catch (_) {}

    _setPurchaseState(IapPurchaseState.idle);
    _purchaseError = null;
    notifyListeners();
  }

  // ── Restore ──────────────────────────────────────────────────────────────────
  /// Consumable purchases cannot be restored from the Play Store (by design).
  /// We restore from local SharedPreferences (still valid if not expired).
  Future<void> restorePurchases() async {
    await _loadExpiry(); // re-read from disk in case another device wrote it
    notifyListeners();
  }

  // ── Paystack grant (called after successful Paystack checkout) ───────────────
  Future<void> grantPaystackPurchase(String productId) async {
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:
        await _grantDuration(const Duration(days: 1));
        break;
      case AppConstants.iapRemoveAds1Week:
        await _grantDuration(const Duration(days: 7));
        break;
      case AppConstants.iapRemoveAds1Month:
        await _grantDuration(const Duration(days: 30));
        break;
      case 'remove_ads_perm':
        // Permanent: set a 10-year expiry as a practical "forever"
        await _grantDuration(const Duration(days: 3650));
        break;
      default:
        break;
    }
  }

  // ── Streak reward grant (called from GameProvider on milestone) ──────────────
  Future<void> grantStreakAdFree(int hours) async {
    if (hours <= 0) return;
    await _grantDuration(Duration(hours: hours));
  }

  Future<void> _grantDuration(Duration d) async {
    final base = (_removeAdsExpiry != null && _removeAdsExpiry!.isAfter(DateTime.now()))
        ? _removeAdsExpiry!
        : DateTime.now();
    _removeAdsExpiry = base.add(d);
    _adsRemoved      = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyRemoveAdsExpiry,
          _removeAdsExpiry!.millisecondsSinceEpoch);
    } catch (_) {}
    notifyListeners();
  }

  // ── Expiry ───────────────────────────────────────────────────────────────────
  Future<void> _loadExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms    = prefs.getInt(AppConstants.keyRemoveAdsExpiry);
      if (ms == null) return;
      _removeAdsExpiry = DateTime.fromMillisecondsSinceEpoch(ms);
      _adsRemoved = _removeAdsExpiry!.isAfter(DateTime.now());
      if (!_adsRemoved) {
        // Expired — clean up
        _removeAdsExpiry = null;
        await prefs.remove(AppConstants.keyRemoveAdsExpiry);
      }
    } catch (_) {}
  }

  String? _expiryLabel() {
    if (_removeAdsExpiry == null) return null;
    final diff = _removeAdsExpiry!.difference(DateTime.now());
    if (diff.inDays >= 1)  return 'Ad-free for ${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours >= 1) return 'Ad-free for ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return 'Ad-free for ${diff.inMinutes}m';
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _setPurchaseState(IapPurchaseState state) {
    if (_purchaseState == state) return;
    _purchaseState = state;
    notifyListeners();
  }

  void _setError(String message) {
    _purchaseError = message;
    _purchaseState = IapPurchaseState.error;
    notifyListeners();
  }

  void clearError() {
    _purchaseError = null;
    _purchaseState = IapPurchaseState.idle;
    notifyListeners();
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('cancel'))   return 'Purchase cancelled.';
    if (lower.contains('network'))  return 'Network error. Check your connection.';
    if (lower.contains('billing'))  return 'Billing unavailable. Try again later.';
    if (lower.contains('already'))  return 'You already own this item.';
    return 'Purchase failed. Please try again.';
  }

  ProductDetails? productById(String id) {
    try { return _products.firstWhere((p) => p.id == id); }
    catch (_) { return null; }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
