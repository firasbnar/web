import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});
  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabCtrl;

  // Overview
  Map<String, dynamic>? _overview;
  bool _loadingOverview = true;

  // Stores
  List<dynamic> _stores = [];
  int _storePage = 0;
  bool _storesDone = false;
  bool _storesError = false;

  // Users
  List<dynamic> _users = [];
  int _userPage = 0;
  bool _usersDone = false;
  bool _usersError = false;

  // Subscriptions
  List<dynamic> _subscriptions = [];
  int _subPage = 0;
  bool _subsDone = false;
  bool _subsError = false;

  // Audit logs
  List<dynamic> _auditLogs = [];
  int _auditPage = 0;
  bool _auditDone = false;
  bool _auditError = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadOverview();
    _loadStores();
    _loadUsers();
    _loadSubscriptions();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ---- Data loading ----

  Future<void> _loadOverview() async {
    try {
      final res = await _api.get('/super-admin/dashboard');
      if (mounted) setState(() => _overview = res['data']);
    } catch (e) {
      dev.log('[SuperAdmin] overview error: $e');
    }
    if (mounted) setState(() => _loadingOverview = false);
  }

  Future<void> _loadStores({bool refresh = false}) async {
    if (_storesDone && !refresh) return;
    if (refresh) { _storePage = 0; _stores = []; _storesDone = false; }
    try {
      final res = await _api.get('/super-admin/stores', queryParameters: {'page': _storePage, 'size': 20});
      final data = res['data'];
      _stores.addAll(data['content'] as List);
      _storePage++;
      _storesDone = _storePage >= data['totalPages'];
      _storesError = false;
    } catch (_) { _storesDone = true; _storesError = _stores.isEmpty; }
    if (mounted) setState(() {});
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_usersDone && !refresh) return;
    if (refresh) { _userPage = 0; _users = []; _usersDone = false; }
    try {
      final res = await _api.get('/super-admin/users', queryParameters: {'page': _userPage, 'size': 20});
      final data = res['data'];
      _users.addAll(data['content'] as List);
      _userPage++;
      _usersDone = _userPage >= data['totalPages'];
      _usersError = false;
    } catch (_) { _usersDone = true; _usersError = _users.isEmpty; }
    if (mounted) setState(() {});
  }

  Future<void> _loadSubscriptions({bool refresh = false}) async {
    if (_subsDone && !refresh) return;
    if (refresh) { _subPage = 0; _subscriptions = []; _subsDone = false; }
    try {
      final res = await _api.get('/super-admin/subscriptions', queryParameters: {'page': _subPage, 'size': 20});
      final data = res['data'];
      _subscriptions.addAll(data['content'] as List);
      _subPage++;
      _subsDone = _subPage >= data['totalPages'];
      _subsError = false;
    } catch (_) { _subsDone = true; _subsError = _subscriptions.isEmpty; }
    if (mounted) setState(() {});
  }

  Future<void> _loadAuditLogs({bool refresh = false}) async {
    if (_auditDone && !refresh) return;
    if (refresh) { _auditPage = 0; _auditLogs = []; _auditDone = false; }
    try {
      final res = await _api.get('/super-admin/audit-logs', queryParameters: {'page': _auditPage, 'size': 20});
      final data = res['data'];
      _auditLogs.addAll(data['content'] as List);
      _auditPage++;
      _auditDone = _auditPage >= data['totalPages'];
      _auditError = false;
    } catch (_) { _auditDone = true; _auditError = _auditLogs.isEmpty; }
    if (mounted) setState(() {});
  }

  // ---- Actions ----

  Future<void> _freezeStore(String id, String name) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geler la boutique'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous geler "$name" ?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnelle)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text),
            child: const Text('Geler'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _api.put('/super-admin/stores/$id/freeze', data: {'reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boutique gelée'), backgroundColor: AppColors.success));
      }
      _loadStores(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _unfreezeStore(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dégeler la boutique'),
        content: Text('Voulez-vous dégeler "$name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dégeler'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.put('/super-admin/stores/$id/unfreeze');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boutique dégelée'), backgroundColor: AppColors.success));
      }
      _loadStores(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _api.put('/super-admin/users/$userId/role', data: {'role': newRole});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour'), backgroundColor: AppColors.success));
      }
      _loadUsers(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _verifyUserEmail(String userId) async {
    try {
      await _api.put('/super-admin/users/$userId/verify-email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email vérifié'), backgroundColor: AppColors.success));
      }
      _loadUsers(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _suspendUser(String userId, String name) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspendre l\'utilisateur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous suspendre "$name" ?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text),
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      await _api.put('/super-admin/users/$userId/suspend', data: {'reason': reason});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur suspendu'), backgroundColor: AppColors.success));
      }
      _loadUsers(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _activateUser(String userId) async {
    try {
      await _api.put('/super-admin/users/$userId/activate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur activé'), backgroundColor: AppColors.success));
      }
      _loadUsers(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> _overrideSubscription(String subId, String status) async {
    try {
      await _api.put('/super-admin/subscriptions/$subId/override', data: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statut mis à jour'), backgroundColor: AppColors.success));
      }
      _loadSubscriptions(refresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _drawer(),
      appBar: AppBar(
        title: const Text('Super Admin'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Aperçu'),
            Tab(icon: Icon(Icons.store), text: 'Boutiques'),
            Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.card_membership), text: 'Abonnements'),
            Tab(icon: Icon(Icons.history), text: 'Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _overviewTab(),
          _storesTab(),
          _usersTab(),
          _subscriptionsTab(),
          _auditTab(),
        ],
      ),
    );
  }

  Widget _drawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2710BF), Color(0xFF6C4FFF)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.shield, color: Colors.white, size: 28),
                ),
                SizedBox(height: 12),
                Text('Super Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Panneau de contrôle', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Boutiques'),
            onTap: () { Navigator.pop(context); _tabCtrl.animateTo(1); },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Utilisateurs'),
            onTap: () { Navigator.pop(context); _tabCtrl.animateTo(2); },
          ),
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('Abonnements'),
            onTap: () { Navigator.pop(context); _tabCtrl.animateTo(3); },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Audit'),
            onTap: () { Navigator.pop(context); _tabCtrl.animateTo(4); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Déconnexion', style: TextStyle(color: AppColors.danger)),
            onTap: () { Navigator.pop(context); _logout(); },
          ),
        ],
      ),
    );
  }

  // ---- Overview Tab ----

  Widget _overviewTab() {
    if (_loadingOverview) return const Center(child: CircularProgressIndicator());
    final o = _overview;
    return RefreshIndicator(
      onRefresh: () async { _loadingOverview = true; setState(() {}); await _loadOverview(); },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Vue d\'ensemble'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _metricCard('Utilisateurs', '${o?['totalUsers'] ?? 0}', Icons.people, const Color(0xFF2710BF)),
                _metricCard('Propriétaires', '${o?['totalOwners'] ?? 0}', Icons.person_outline, Colors.indigo),
                _metricCard('Boutiques', '${o?['totalBoutiques'] ?? 0}', Icons.store, Colors.amber.shade700),
                _metricCard('Produits', '${o?['totalProducts'] ?? 0}', Icons.inventory_2, Colors.cyan),
                _metricCard('Commandes', '${o?['totalOrders'] ?? 0}', Icons.receipt_long, AppColors.success),
                _metricCard('Revenu total', '${o?['totalRevenue'] ?? 0} TND', Icons.trending_up, Colors.pink),
                _metricCard('Abonnements', '${o?['totalSubscriptions'] ?? 0}', Icons.card_membership, Colors.purple),
                _metricCard('Actifs', '${o?['activeSubscriptions'] ?? 0}', Icons.check_circle, AppColors.success),
                _metricCard('Boutiques gelées', '${o?['frozenStores'] ?? 0}', Icons.ac_unit, Colors.lightBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: AppTypography.heading3.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.heading3.copyWith(color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ---- Stores Tab ----

  Widget _storesTab() {
    if (_stores.isEmpty && _storesError) {
      return _errorView(() { _storesError = false; setState(() {}); _loadStores(refresh: true); });
    }
    if (_stores.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _loadStores(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stores.length + (_storesDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= _stores.length) {
            _loadStores();
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          }
          final s = _stores[i];
          final isFrozen = s['storeStatus'] == 'FROZEN';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isFrozen ? Colors.lightBlue.shade200 : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isFrozen ? Colors.lightBlue.shade50 : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.store, color: isFrozen ? Colors.lightBlue : AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['name'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text('${s['ownerName'] ?? ""} — ${s['ownerEmail'] ?? ""}', style: AppTypography.caption),
                        Text('${s['productCount']} produits · ${s['orderCount']} commandes', style: AppTypography.caption),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.link, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(s['publicUrl'] ?? '/store/${s['slug'] ?? ""}',
                              style: AppTypography.caption.copyWith(color: AppColors.primary, fontSize: 10)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(s['storeStatus'] ?? 'ACTIVE'),
                      if (s['isPublished'] == true)
                        const SizedBox(height: 4),
                      if (s['isPublished'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('PUBLIÉ', style: TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ]),
                if (isFrozen && s['freezeReason'] != null && (s['freezeReason'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 52),
                    child: Text('Raison: ${s['freezeReason']}',
                      style: AppTypography.caption.copyWith(color: AppColors.danger, fontStyle: FontStyle.italic)),
                  ),
                if (isFrozen && s['frozenAt'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 52),
                    child: Text('Depuis: ${s['frozenAt']}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 52),
                  child: Row(children: [
                    if (isFrozen)
                      _actionChip(Icons.ac_unit, 'Dégeler', AppColors.success, () => _unfreezeStore(s['id'], s['name']))
                    else
                      _actionChip(Icons.ac_unit, 'Geler', Colors.lightBlue, () => _freezeStore(s['id'], s['name'])),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;
    switch (status) {
      case 'FROZEN':
        bg = Colors.lightBlue.shade50;
        fg = Colors.lightBlue;
        icon = Icons.ac_unit;
      case 'ACTIVE':
      default:
        bg = AppColors.success.withAlpha(25);
        fg = AppColors.success;
        icon = Icons.check_circle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ---- Users Tab ----

  Widget _usersTab() {
    if (_users.isEmpty && _usersError) return _errorView(() { _usersError = false; setState(() {}); _loadUsers(refresh: true); });
    if (_users.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _loadUsers(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_usersDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= _users.length) { _loadUsers(); return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())); }
          final u = _users[i];
          final isSuspended = u['isSuspended'] == true;
          final emailVerified = u['emailVerified'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSuspended ? AppColors.danger.withAlpha(80) : AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text(
                      ((u['fullName'] as String? ?? '?')[0].toUpperCase()),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['fullName'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text(u['email'] ?? '', style: AppTypography.caption, overflow: TextOverflow.ellipsis),
                        Text('${u['boutiqueCount']} boutique(s) · ${u['role']}', style: AppTypography.caption, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (!emailVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(100)),
                      child: const Text('NON VÉRIFIÉ', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600)),
                    ),
                  if (isSuspended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger.withAlpha(30), borderRadius: BorderRadius.circular(100)),
                      child: const Text('SUSPENDU', style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  DropdownButton<String>(
                    value: u['role'] ?? 'USER',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'OWNER', child: Text('OWNER', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN', style: TextStyle(fontSize: 12, color: AppColors.primary))),
                      DropdownMenuItem(value: 'MANAGER', child: Text('MANAGER', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'STAFF', child: Text('STAFF', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'USER', child: Text('USER', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => _updateUserRole(u['id'], v!),
                  ),
                  const Spacer(),
                  if (!emailVerified)
                    _smallActionBtn('Vérifier', AppColors.success, () => _verifyUserEmail(u['id'])),
                  if (isSuspended)
                    _smallActionBtn('Activer', AppColors.success, () => _activateUser(u['id']))
                  else
                    _smallActionBtn('Suspendre', AppColors.danger, () => _suspendUser(u['id'], u['fullName'])),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _smallActionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ---- Subscriptions Tab ----

  Widget _subscriptionsTab() {
    if (_subscriptions.isEmpty && _subsError) return _errorView(() { _subsError = false; setState(() {}); _loadSubscriptions(refresh: true); });
    if (_subscriptions.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _loadSubscriptions(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subscriptions.length + (_subsDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= _subscriptions.length) { _loadSubscriptions(); return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())); }
          final s = _subscriptions[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.card_membership, color: Colors.purple.shade300),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['planName'] ?? 'N/A', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                        Text('${s['userName'] ?? ""} — ${s['userEmail'] ?? ""}', style: AppTypography.caption),
                        if (s['expiresAt'] != null)
                          Text('Expire: ${s['expiresAt']}', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  _subStatusBadge(s['status'] ?? 'ACTIVE'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _subOverrideBtn('ACTIVE', Colors.green, s['id']),
                  _subOverrideBtn('EXPIRED', Colors.orange, s['id']),
                  _subOverrideBtn('CANCELLED', Colors.red, s['id']),
                  _subOverrideBtn('PENDING', Colors.blue, s['id']),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _subStatusBadge(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE': color = AppColors.success;
      case 'EXPIRED': color = Colors.orange;
      case 'CANCELLED': color = AppColors.danger;
      case 'PENDING': color = Colors.blue;
      default: color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _subOverrideBtn(String status, Color color, String subId) {
    return GestureDetector(
      onTap: () => _overrideSubscription(subId, status),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text(status, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ---- Audit Logs Tab ----

  Widget _auditTab() {
    if (_auditLogs.isEmpty && _auditError) return _errorView(() { _auditError = false; setState(() {}); _loadAuditLogs(refresh: true); });
    if (_auditLogs.isEmpty) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _loadAuditLogs(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _auditLogs.length + (_auditDone ? 0 : 1),
        itemBuilder: (_, i) {
          if (i >= _auditLogs.length) { _loadAuditLogs(); return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())); }
          final l = _auditLogs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              _auditIcon(l['action'] ?? ''),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l['action'] ?? ""} · ${l['targetType'] ?? ""}',
                      style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                    if (l['details'] != null && (l['details'] as String).isNotEmpty)
                      Text(l['details'], style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${l['adminEmail'] ?? ""} · ${l['createdAt'] ?? ""}',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _auditIcon(String action) {
    IconData icon;
    Color color;
    switch (action) {
      case 'FREEZE_STORE': icon = Icons.ac_unit; color = Colors.lightBlue;
      case 'UNFREEZE_STORE': icon = Icons.ac_unit; color = AppColors.success;
      case 'UPDATE_USER_ROLE': icon = Icons.swap_horiz; color = Colors.indigo;
      case 'VERIFY_EMAIL': icon = Icons.verified; color = AppColors.success;
      case 'SUSPEND_USER': icon = Icons.block; color = AppColors.danger;
      case 'ACTIVATE_USER': icon = Icons.check_circle; color = AppColors.success;
      case 'DELETE_USER': icon = Icons.delete; color = AppColors.danger;
      case 'DELETE_STORE': icon = Icons.delete; color = AppColors.danger;
      case 'OVERRIDE_SUBSCRIPTION': icon = Icons.edit; color = Colors.purple;
      default: icon = Icons.info; color = AppColors.textSecondary;
    }
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _errorView(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('Impossible de charger les données'),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
