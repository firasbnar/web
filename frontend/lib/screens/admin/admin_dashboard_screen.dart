import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabCtrl;
  Map<String, dynamic>? _overview;
  List<dynamic> _users = [];
  List<dynamic> _boutiques = [];
  bool _loading = true;
  bool _usersError = false, _boutiquesError = false;
  int _userPage = 0, _boutiquePage = 0;
  bool _usersDone = false, _boutiquesDone = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadOverview();
    _loadUsers();
    _loadBoutiques();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final res = await _api.get('/admin/overview');
      if (mounted) setState(() => _overview = res['data']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_usersDone && !refresh) return;
    if (refresh) { _userPage = 0; _users = []; _usersDone = false; }
    try {
      final res = await _api.get('/admin/users', queryParameters: {'page': _userPage, 'size': 20});
      final data = res['data'];
      _users.addAll(data['content'] as List);
      _userPage++;
      _usersDone = _userPage >= data['totalPages'];
      _usersError = false;
    } catch (_) { _usersDone = true; _usersError = _users.isEmpty; }
    if (mounted) setState(() {});
  }

  Future<void> _loadBoutiques({bool refresh = false}) async {
    if (_boutiquesDone && !refresh) return;
    if (refresh) { _boutiquePage = 0; _boutiques = []; _boutiquesDone = false; }
    try {
      final res = await _api.get('/admin/boutiques', queryParameters: {'page': _boutiquePage, 'size': 20});
      final data = res['data'];
      _boutiques.addAll(data['content'] as List);
      _boutiquePage++;
      _boutiquesDone = _boutiquePage >= data['totalPages'];
      _boutiquesError = false;
    } catch (_) { _boutiquesDone = true; _boutiquesError = _boutiques.isEmpty; }
    if (mounted) setState(() {});
  }

  Future<void> _updateRole(String userId, String role) async {
    try {
      await _api.put('/admin/users/$userId/role', data: {'role': role});
      _loadUsers(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour'), backgroundColor: AppColors.success));
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4040C8), Color(0xFF8B2FC9)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  SizedBox(height: 12),
                  Text('Super Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Panneau d\'administration', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
              leading: const Icon(Icons.people),
              title: const Text('Owners'),
              onTap: () {
                Navigator.pop(context);
                _tabCtrl.animateTo(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Boutiques'),
              onTap: () {
                Navigator.pop(context);
                _tabCtrl.animateTo(2);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Déconnexion', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Administration'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Aperçu'),
            Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.store), text: 'Boutiques'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _overviewTab(),
          _usersTab(),
          _boutiquesTab(),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final o = _overview;
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _metricCard('Utilisateurs', '${o?['totalUsers'] ?? 0}', Icons.people, AppColors.primary),
        _metricCard('Boutiques', '${o?['totalBoutiques'] ?? 0}', Icons.store, Colors.amber),
        _metricCard('Produits', '${o?['totalProducts'] ?? 0}', Icons.inventory_2, Colors.cyan),
        _metricCard('Commandes', '${o?['totalOrders'] ?? 0}', Icons.receipt_long, AppColors.success),
        _metricCard('Revenu total', '${(o?['totalRevenue'] ?? 0).toString()} TND', Icons.trending_up, Colors.pink),
        _metricCard('Abonnements', '${o?['totalSubscriptions'] ?? 0}', Icons.card_membership, Colors.purple),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.heading3.copyWith(color: color), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _usersTab() {
    if (_users.isEmpty && _usersError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text('Impossible de charger les utilisateurs'),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: () { _usersError = false; setState(() {}); _loadUsers(refresh: true); },
            ),
          ],
        ),
      );
    }
    return _users.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length + (_usersDone ? 0 : 1),
            itemBuilder: (_, i) {
              if (i >= _users.length) {
                _loadUsers();
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              }
              final u = _users[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
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
                          Text(u['fullName'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                          Text(u['email'] ?? '', style: AppTypography.caption),
                          Text('${u['boutiqueCount']} boutique(s)', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    if (u['isSuspended'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withAlpha(30),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('SUSPENDU', style: TextStyle(fontSize: 10, color: AppColors.danger)),
                      ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: u['role'] ?? 'OWNER',
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'OWNER', child: Text('OWNER', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN', style: TextStyle(fontSize: 12, color: AppColors.primary))),
                      ],
                      onChanged: (v) => _updateRole(u['id'], v!),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _boutiquesTab() {
    if (_boutiques.isEmpty && _boutiquesError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text('Impossible de charger les boutiques'),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: () { _boutiquesError = false; setState(() {}); _loadBoutiques(refresh: true); },
            ),
          ],
        ),
      );
    }
    return _boutiques.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _boutiques.length + (_boutiquesDone ? 0 : 1),
            itemBuilder: (_, i) {
              if (i >= _boutiques.length) {
                _loadBoutiques();
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
              }
              final b = _boutiques[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.store, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['name'] ?? '', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                          Text('${b['ownerName'] ?? ""} — ${b['ownerEmail'] ?? ""}', style: AppTypography.caption),
                          Text('${b['productCount']} produits · ${b['orderCount']} commandes', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Icon(b['isActive'] == true ? Icons.check_circle : Icons.cancel,
                        color: b['isActive'] == true ? AppColors.success : AppColors.danger, size: 20),
                  ],
                ),
              );
            },
          );
  }
}
