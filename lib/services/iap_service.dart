import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) return;
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () => _subscription?.cancel(), onError: (e) => debugPrint('IAP error: ' + e.toString()));
  }

  Future<void> loadProducts(List<String> ids) async {
    if (!_isAvailable || ids.isEmpty) return;
    final response = await _iap.queryProductDetails(ids.toSet());
    _products = response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    if (!_isAvailable) return;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        debugPrint('Purchased: ' + purchase.productID);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() => _subscription?.cancel();
}