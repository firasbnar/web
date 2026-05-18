import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/team_member.dart';

class TeamProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<TeamMember> _members = [];
  bool _loading = false;
  String? _error;
  String? _searchQuery;
  String? _roleFilter;
  String? _statusFilter;
  int? _totalMembers;
  int? _activeMembers;
  int? _pendingInvitations;
  Map<String, int>? _roleDistribution;

  List<TeamMember> get members => _members;
  bool get loading => _loading;
  String? get error => _error;
  String? get searchQuery => _searchQuery;
  String? get roleFilter => _roleFilter;
  String? get statusFilter => _statusFilter;
  int? get totalMembers => _totalMembers;
  int? get activeMembers => _activeMembers;
  int? get pendingInvitations => _pendingInvitations;
  Map<String, int>? get roleDistribution => _roleDistribution;

  List<TeamMember> get filteredMembers {
    var result = _members;
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final q = _searchQuery!.toLowerCase();
      result = result.where((m) =>
          (m.name?.toLowerCase().contains(q) ?? false) ||
          (m.invitedEmail?.toLowerCase().contains(q) ?? false) ||
          (m.userEmail?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (_roleFilter != null && _roleFilter!.isNotEmpty) {
      result = result.where((m) => m.role == _roleFilter).toList();
    }
    if (_statusFilter != null && _statusFilter!.isNotEmpty) {
      result = result.where((m) => m.status == _statusFilter).toList();
    }
    return result;
  }

  Future<void> loadMembers(String boutiqueId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/team', queryParameters: {'boutiqueId': boutiqueId});
      final data = res['data'] as List;
      _members = data.map((e) => TeamMember.fromJson(e)).toList();
      await _loadStats(boutiqueId);
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadStats(String boutiqueId) async {
    try {
      final res = await _api.get('/team/stats', queryParameters: {'boutiqueId': boutiqueId});
      final data = res['data'];
      if (data != null) {
        _totalMembers = data['totalMembers'] as int?;
        _activeMembers = data['activeMembers'] as int?;
        _pendingInvitations = data['pendingInvitations'] as int?;
        final dist = data['roleDistribution'] as Map<String, dynamic>?;
        if (dist != null) {
          _roleDistribution = dist.map((k, v) => MapEntry(k, v as int));
        }
      }
    } catch (_) {}
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setRoleFilter(String? role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = null;
    _roleFilter = null;
    _statusFilter = null;
    notifyListeners();
  }

  Future<String?> inviteMember(String boutiqueId, String email, String name, String role) async {
    try {
      await _api.post('/team/invite', data: {
        'boutiqueId': boutiqueId,
        'email': email,
        'name': name,
        'role': role,
      });
      await loadMembers(boutiqueId);
      return null;
    } catch (e) {
      return ApiClient.extractErrorMessage(e);
    }
  }

  Future<String?> updateRole(String memberId, String boutiqueId, String newRole) async {
    try {
      await _api.put('/team/$memberId/role', queryParameters: {'boutiqueId': boutiqueId}, data: {'role': newRole});
      await loadMembers(boutiqueId);
      return null;
    } catch (e) {
      return ApiClient.extractErrorMessage(e);
    }
  }

  Future<String?> toggleStatus(String memberId, String boutiqueId, bool activate) async {
    try {
      await _api.put('/team/$memberId/toggle-status',
          queryParameters: {'boutiqueId': boutiqueId, 'activate': activate});
      await loadMembers(boutiqueId);
      return null;
    } catch (e) {
      return ApiClient.extractErrorMessage(e);
    }
  }

  Future<String?> removeMember(String memberId, String boutiqueId) async {
    try {
      await _api.delete('/team/$memberId', queryParameters: {'boutiqueId': boutiqueId});
      _members.removeWhere((m) => m.id == memberId);
      notifyListeners();
      return null;
    } catch (e) {
      return ApiClient.extractErrorMessage(e);
    }
  }
}
