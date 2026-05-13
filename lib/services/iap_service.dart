import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class IapService extends ChangeNotifier {
  static final IapService _instance = IapService._internal();
  factory IapService() => _instance;
  IapService._internal();

  bool _available = false;
  bool get available => _available;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  DateTime? _removeAdsExpiry;
  DateTime? get removeAdsExpiry => _removeAdsExpiry;

  bool _purchasing = false;
  bool get purchasing => _purchasing;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<void> init() async {
    await _loadPersistedState();

    _available = await InAppPurchase.instance.isAvailable();
    if (!_available) return;

    _purchaseSubscription = InAppPurchase.instance.purchaseStream
        .listen(_handlePurchases, onError: (_) {});

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await InAppPurchase.instance
          .queryProductDetails(AppConstants.iapProductIds);
      if (!response.notFoundIDs.isEmpty) {
        // Some products not found — normal in sandbox
      }
      _products = response.productDetails;
      _products.sort((a, b) => _priceSort(a.id) - _priceSort(b.id));
      notifyListeners();
    } catch (_) {}
  }

  int _priceSort(String id) {
    switch (id) {
      case AppConstants.iapRemoveAds1Day:   return 0;
      case AppConstants.iapRemoveAds1Week:  return 1;
      case AppConstants.iapRemoveAds1Month: return 2;
      default: return 3;
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryMs = prefs.getInt(AppConstants.keyRemoveAdsExpiry);
      if (expiryMs != null) {
        _removeAdsExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        _adsRemoved = _removeAdsExpiry!.isAfter(DateTime.now());
        if (!_adsRemoved) {
          // Expired — clean up
          await prefs.remove(AppConstants.keyRemoveAdsExpiry);
          _removeAdsExpiry = null;
        }
      }
    } catch (_) {}
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _applyPurchase(purchase.productID);
        if (purchase.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _purchasing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _applyPurchase(String productId) async {
    Duration duration;
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:
        duration = const Duration(days: 1);
        break;
      case AppConstants.iapRemoveAds1Week:
        duration = const Duration(days: 7);
        break;
      case AppConstants.iapRemoveAds1Month:
        duration = const Duration(days: 30);
        break;
      default:
        return;
    }

    final expiry = DateTime.now().add(duration);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyRemoveAdsExpiry,
          expiry.millisecondsSinceEpoch);
    } catch (_) {}

    _removeAdsExpiry = expiry;
    _adsRemoved = true;
    _purchasing = false;
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails product) async {
    if (!_available || _purchasing) return;
    _purchasing = true;
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: product);
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      _purchasing = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  String? get removeAdsExpiryLabel {
    if (_removeAdsExpiry == null) return null;
    final diff = _removeAdsExpiry!.difference(DateTime.now());
    if (diff.inDays >= 1) return 'Ads removed for ${diff.inDays}d';
    if (diff.inHours >= 1) return 'Ads removed for ${diff.inHours}h';
    return 'Ads removed';
  }

  ProductDetails? productById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
