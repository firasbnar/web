import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/boutique.dart';

class BoutiqueProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  List<Boutique> _boutiques = [];
  Boutique? _activeBoutique;
  BoutiqueStats? _stats;
  bool _loading = false;
  String? _error;
  String? _activeBoutiqueId;

  // Settings-related state
  List<Map<String, dynamic>> _sliders = [];
  List<Map<String, dynamic>> _videos = [];
  List<String> _countries = [];
  Map<String, String> _language = {};

  List<Boutique> get boutiques => _boutiques;
  Boutique? get activeBoutique => _activeBoutique;
  Boutique? get currentBoutique => _activeBoutique;
  BoutiqueStats? get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;
  String? get activeBoutiqueId => _activeBoutiqueId;
  List<Map<String, dynamic>> get sliders => _sliders;
  List<Map<String, dynamic>> get videos => _videos;
  List<String> get countries => _countries;
  Map<String, String> get language => _language;

  String get _boutiqueId {
    if (_activeBoutique == null) throw Exception('No active boutique');
    return _activeBoutique!.id;
  }

  Future<void> loadBoutiques() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get('/boutiques/mine');
      final List data = res['data'];
      _boutiques = data.map((e) => Boutique.fromJson(e)).toList();

      final savedId = await AppStorage.getActiveBoutiqueId();
      if (savedId != null && _boutiques.any((b) => b.id == savedId)) {
        _activeBoutique = _boutiques.firstWhere((b) => b.id == savedId);
      } else if (_boutiques.isNotEmpty) {
        _activeBoutique = _boutiques.first;
        await AppStorage.saveActiveBoutiqueId(_activeBoutique!.id);
      }
      _activeBoutiqueId = _activeBoutique?.id;
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> switchBoutique(String boutiqueId) async {
    final boutique = _boutiques.firstWhere((b) => b.id == boutiqueId);
    _activeBoutique = boutique;
    _activeBoutiqueId = boutiqueId;
    await AppStorage.saveActiveBoutiqueId(boutiqueId);
    try {
      await _api
          .put('/users/active-boutique', data: {'boutiqueId': boutiqueId});
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadStats() async {
    if (_activeBoutique == null) return;
    try {
      final res = await _api.get('/boutiques/${_activeBoutique!.id}/stats');
      _stats = BoutiqueStats.fromJson(res['data']);
      notifyListeners();
    } catch (_) {}
  }

  // ========== BASIC BOUTIQUE ==========

  Future<bool> updateBoutique(Map<String, dynamic> data) async {
    if (_activeBoutique == null) return false;
    try {
      final res =
          await _api.put('/boutiques/${_activeBoutique!.id}', data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTheme(Map<String, dynamic> data) async {
    if (_activeBoutique == null) return false;
    try {
      final res =
          await _api.put('/boutiques/${_activeBoutique!.id}/theme', data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveStoreTheme(Map<String, String> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/store-theme', data: data);
      if (_activeBoutique != null) {
        _activeBoutique =
            Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSeo(Map<String, dynamic> data) async {
    if (_activeBoutique == null) return false;
    try {
      final res =
          await _api.put('/boutiques/${_activeBoutique!.id}/seo', data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSocial(Map<String, dynamic> data) async {
    if (_activeBoutique == null) return false;
    try {
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/social',
          data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePayments(Map<String, dynamic> data) async {
    if (_activeBoutique == null) return false;
    try {
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/payments',
          data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> createBoutique(Map<String, dynamic> data) async {
    final res = await _api.post('/boutiques', data: data);
    final newBoutique = Boutique.fromJson(res['data']);
    _boutiques.add(newBoutique);
    await switchBoutique(newBoutique.id);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> loadDashboard() async {
    if (_activeBoutique == null) return null;
    try {
      return await _api.get('/boutiques/${_activeBoutique!.id}/dashboard');
    } catch (_) {
      return null;
    }
  }

  // ========== BOUTIQUE SETTINGS CONTROLLER METHODS ==========

  Future<bool> saveConfig(Map<String, dynamic> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/config', data: data);
      if (_activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({
          ..._activeBoutique!.toJson(),
          'seoTitle': data['email'] ?? _activeBoutique!.seoTitle,
          'description': data['address'] ?? _activeBoutique!.description,
          'name': data['companyName'] ?? _activeBoutique!.name,
          'announcementText':
              data['topBarText'] ?? _activeBoutique!.announcementText,
          'whatsappNumber': data['phone'] ?? _activeBoutique!.whatsappNumber,
          'tva': double.tryParse(data['tva']?.toString() ?? '') ??
              _activeBoutique!.tva,
          'deliveryFees':
              double.tryParse(data['deliveryFees']?.toString() ?? '') ??
                  _activeBoutique!.deliveryFees,
          'cashOnDelivery': data['cashDelivery'] == null
              ? _activeBoutique!.cashOnDelivery
              : data['cashDelivery'] == 'yes',
          'konnectMerchantId':
              data['konnectMerchantId'] ?? _activeBoutique!.konnectMerchantId,
          'konnectApiKey':
              data['konnectApiKey'] ?? _activeBoutique!.konnectApiKey,
          'konnectStatus':
              data['konnectStatus'] ?? _activeBoutique!.konnectStatus,
          'd17MerchantNumber':
              data['d17MerchantNumber'] ?? _activeBoutique!.d17MerchantNumber,
          'd17QrCodeUrl': data['d17QrCodeUrl'] ?? _activeBoutique!.d17QrCodeUrl,
          'd17Status': data['d17Status'] ?? _activeBoutique!.d17Status,
          'simpleCheckout': data['simpleCheckout'] == null
              ? _activeBoutique!.simpleCheckout
              : data['simpleCheckout'] == 'yes',
        });
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadLogo(XFile file) async {
    try {
      final res = await _api.uploadFile('/boutiques/$_boutiqueId/logo', file);
      final logoUrl = res['data']?['logoUrl']?.toString();
      if (logoUrl != null && _activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({
          ..._activeBoutique!.toJson(),
          'logoUrl': logoUrl,
        });
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveCurrency(String currency) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/currency',
          data: {'currency': currency});
      if (_activeBoutique != null) {
        _activeBoutique = Boutique.fromJson(
            {..._activeBoutique!.toJson(), 'currency': currency});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveCustomCode(Map<String, String> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/custom-code', data: data);
      if (_activeBoutique != null) {
        _activeBoutique =
            Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadSliders() async {
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/sliders');
      _sliders = List<Map<String, dynamic>>.from(res['data'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addSlider(String imageUrl) async {
    try {
      await _api.post('/boutiques/$_boutiqueId/sliders',
          data: {'imageUrl': imageUrl});
      await loadSliders();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSlider(String sliderId) async {
    try {
      await _api.delete('/boutiques/$_boutiqueId/sliders/$sliderId');
      await loadSliders();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadVideos() async {
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/videos');
      _videos = List<Map<String, dynamic>>.from(res['data'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addVideo(XFile file) async {
    try {
      await _api.uploadFile('/boutiques/$_boutiqueId/videos', file);
      await loadVideos();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVideo(String videoId) async {
    try {
      await _api.delete('/boutiques/$_boutiqueId/videos/$videoId');
      await loadVideos();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCountries() async {
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/countries');
      _countries = List<String>.from(res['data'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addCountry(String countryName) async {
    try {
      await _api.post('/boutiques/$_boutiqueId/countries',
          data: {'countryName': countryName});
      await loadCountries();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCountry(String countryName) async {
    try {
      await _api.delete('/boutiques/$_boutiqueId/countries/$countryName');
      await loadCountries();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadLanguage() async {
    try {
      final res = await _api.get('/boutiques/$_boutiqueId/language');
      final data = res['data'];
      if (data is Map) {
        _language = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> saveLanguage(Map<String, String> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/language', data: data);
      _language = data;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveStoreSocial(Map<String, dynamic> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/store-social', data: data);
      if (_activeBoutique != null) {
        _activeBoutique =
            Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveFacebookConfig(Map<String, String> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/facebook', data: data);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> checkName(String name,
      {String? currentId}) async {
    try {
      return await _api.post('/boutiques/$_boutiqueId/check-name', data: {
        'name': name,
        if (currentId != null) 'currentBoutiqueId': currentId,
      });
    } catch (e) {
      return {
        'data': {'available': false}
      };
    }
  }
}
