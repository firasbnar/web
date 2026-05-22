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
  bool _countriesLoading = false;
  bool _savingCountries = false;
  Map<String, String> _language = {};

  void clear() {
    _boutiques = [];
    _activeBoutique = null;
    _activeBoutiqueId = null;
    _stats = null;
    _sliders = [];
    _videos = [];
    _countries = [];
    _language = {};
    _loading = false;
    _error = null;
    notifyListeners();
  }

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
  bool get countriesLoading => _countriesLoading;
  bool get savingCountries => _savingCountries;
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

      // Only restore saved boutique if it belongs to current user's list
      final savedId = await AppStorage.getActiveBoutiqueId();
      if (savedId != null && _boutiques.any((b) => b.id == savedId)) {
        _activeBoutique = _boutiques.firstWhere((b) => b.id == savedId);
        _activeBoutiqueId = savedId;
      } else {
        // Don't auto-select — let user choose via store selector
        _activeBoutique = null;
        _activeBoutiqueId = null;
        await AppStorage.clearActiveBoutiqueId();
      }
      if (_activeBoutique != null) {
        await loadCountries();
      }
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
      await _api.put('/users/active-boutique', data: {'boutiqueId': boutiqueId});
    } catch (_) {}
    await loadCountries();
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
      final res = await _api.put('/boutiques/${_activeBoutique!.id}', data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishBoutique() async {
    if (_activeBoutique == null) return false;
    try {
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/publish');
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> unpublishBoutique() async {
    if (_activeBoutique == null) return false;
    try {
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/unpublish');
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
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/theme', data: data);
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveStoreTheme(Map<String, dynamic> data) async {
    try {
      await _api.put('/stores/$_boutiqueId/settings/branding', data: data);
      if (_activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
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
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/seo', data: data);
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
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/social', data: data);
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
      final res = await _api.put('/boutiques/${_activeBoutique!.id}/payments', data: data);
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

  /// Fetches the boutique KPI summary from GET /api/dashboard/boutique-summary.
  /// Returns the inner [data] map (fields: boutiqueId, boutiqueName, publicUrl,
  /// views, products, remainingDays, planName, subscriptionStatus, publicationStatus).
  Future<Map<String, dynamic>?> loadBoutiqueSummary() async {
    if (_activeBoutiqueId == null) return null;
    try {
      final res = await _api.get('/dashboard/boutique-summary',
          queryParameters: {'boutiqueId': _activeBoutiqueId});
      print('[BoutiqueSummary] response=$res');
      return res['data'] as Map<String, dynamic>?;
    } catch (e) {
      print('[BoutiqueSummary] error=$e');
      return null;
    }
  }

  // ========== BOUTIQUE SETTINGS CONTROLLER METHODS ==========

  Future<bool> saveConfig(Map<String, dynamic> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/config', data: data);
      // Reload boutique to get fresh data with correct field mapping
      final updated = await _api.get('/boutiques/$_boutiqueId');
      _activeBoutique = Boutique.fromJson(updated['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveDeliverySettings(Map<String, dynamic> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/delivery-settings', data: data);
      final updated = await _api.get('/boutiques/$_boutiqueId');
      _activeBoutique = Boutique.fromJson(updated['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveNotificationSettings(Map<String, dynamic> data) async {
    try {
      await _api.put('/boutiques/$_boutiqueId/notification-settings', data: data);
      final updated = await _api.get('/boutiques/$_boutiqueId');
      _activeBoutique = Boutique.fromJson(updated['data']);
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
      final res = await _api.uploadFile('/stores/$_boutiqueId/settings/logo', file);
      final logoUrl = res['data']?['logoUrl']?.toString();
      if (logoUrl != null && _activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), 'logoUrl': logoUrl});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadBanner(XFile file) async {
    try {
      final res = await _api.uploadFile('/boutiques/$_boutiqueId/banner', file);
      final bannerUrl = res['data']?['bannerUrl']?.toString();
      if (bannerUrl != null && _activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), 'bannerUrl': bannerUrl});
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadFavicon(XFile file) async {
    try {
      final res = await _api.uploadFile('/boutiques/$_boutiqueId/favicon', file);
      final faviconUrl = res['data']?['faviconUrl']?.toString();
      if (faviconUrl != null && _activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), 'faviconUrl': faviconUrl});
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
      await _api.put('/stores/$_boutiqueId/settings/currency', data: {'currency': currency});
      if (_activeBoutique != null) {
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), 'currency': currency});
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
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
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
      await _api.post('/boutiques/$_boutiqueId/sliders', data: {'imageUrl': imageUrl});
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
    if (_activeBoutique == null) return;
    _countriesLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/stores/$_boutiqueId/settings/countries');
      _countries = List<String>.from(res['data'] ?? []);
      _error = null;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    } finally {
      _countriesLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCountries(List<String> countries) async {
    if (_activeBoutique == null) return false;
    final previous = List<String>.from(_countries);
    final normalized = countries
        .map((country) => country.trim().toUpperCase())
        .where((country) => country.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _countries = normalized;
    _savingCountries = true;
    notifyListeners();
    try {
      final res = await _api.put('/stores/$_boutiqueId/settings/countries', data: {'countries': normalized});
      _countries = List<String>.from(res['data'] ?? normalized);
      _error = null;
      _savingCountries = false;
      notifyListeners();
      return true;
    } catch (e) {
      _countries = previous;
      _error = ApiClient.extractErrorMessage(e);
      _savingCountries = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCountry(String countryName) async {
    return saveCountries([..._countries, countryName]);
  }

  Future<bool> deleteCountry(String countryName) async {
    return saveCountries(_countries.where((country) => country != countryName).toList());
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
        _activeBoutique = Boutique.fromJson({..._activeBoutique!.toJson(), ...data});
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

  Future<bool> saveTelegramSettings(String chatId, bool enabled) async {
    try {
      final res = await _api.put('/boutiques/$_boutiqueId/telegram-settings', data: {
        'telegramChatId': chatId,
        'telegramEnabled': enabled,
      });
      _activeBoutique = Boutique.fromJson(res['data']);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> checkName(String name, {String? currentId}) async {
    try {
      return await _api.post('/boutiques/$_boutiqueId/check-name', data: {
        'name': name,
        if (currentId != null) 'currentBoutiqueId': currentId,
      });
    } catch (e) {
      return {'data': {'available': false}};
    }
  }
}
