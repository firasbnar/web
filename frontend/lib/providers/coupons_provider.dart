import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/coupon.dart';

class CouponsProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Coupon> _coupons = [];
  bool _loading = false;
  String? _error;

  List<Coupon> get coupons => _coupons;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadCoupons(String boutiqueId) async {
    _loading = true; notifyListeners();
    try {
      final res = await _api.get('/coupons', queryParameters: {'boutiqueId': boutiqueId});
      _coupons = (res['data'] as List).map((e) => Coupon.fromJson(e)).toList();
      _loading = false; notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); _loading = false; notifyListeners();
    }
  }

  Future<Coupon?> createCoupon(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/coupons', data: data);
      final coupon = Coupon.fromJson(res['data']);
      _coupons.add(coupon);
      notifyListeners();
      return coupon;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return null;
    }
  }

  Future<bool> deleteCoupon(String id) async {
    try {
      await _api.delete('/coupons/$id');
      _coupons.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e); notifyListeners();
      return false;
    }
  }
}
