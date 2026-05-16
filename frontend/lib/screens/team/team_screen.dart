import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _api = ApiClient();
  List<dynamic> _members = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final bp = context.read<BoutiqueProvider>();
    final bid = bp.activeBoutique?.id;
    if (bid == null) { setState(() => _loading = false); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get('/team', queryParameters: {'boutiqueId': bid});
      _members = res['data'] as List;
    } catch (_) { _error = 'Erreur de chargement'; }
    setState(() => _loading = false);
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMemberSheet(onDone: _load),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    final s = d.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  Color _roleBg(String role) {
    switch (role) {
      case 'ADMIN': return const Color(0xFFFFF3E0);
      case 'MANAGER': return AppColors.primarySurface;
      case 'STAFF': return AppColors.surfaceAlt;
      default: return AppColors.surfaceAlt;
    }
  }

  Color _roleText(String role) {
    switch (role) {
      case 'ADMIN': return AppColors.warning;
      case 'MANAGER': return AppColors.primary;
      case 'STAFF': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  Future<void> _deleteMember(dynamic id) async {
    final bp = context.read<BoutiqueProvider>();
    final bid = bp.activeBoutique?.id;
    if (bid == null || id == null) return;
    try {
      await _api.delete('/team/$id', queryParameters: {'boutiqueId': bid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membre retiré'), backgroundColor: AppColors.success));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${ApiClient.extractErrorMessage(e)}'), backgroundColor: AppColors.danger));
      }
    }
  }

  void _confirmDeleteMember(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Supprimer ce membre ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMember(id);
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion d\'Équipe'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    onPressed: _load,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4040C8), Color(0xFF8B2FC9)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.people, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gestion d\'Équipe',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${_members.length} membre(s)',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0xFFE8E4F0),
                              child: Icon(Icons.store, color: Color(0xFF4040C8)),
                            ),
                            SizedBox(width: 16),
                            Text('Ma Boutique',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+ Ajouter un membre'),
                              onPressed: _showAddMemberSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4040C8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_members.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Membres de l\'équipe',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const Divider(height: 1),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                            columns: [
                              _col('Email'),
                              _col('Rôle'),
                              _col('Invité le'),
                              _col('Permissions'),
                              _col('Actions'),
                            ],
                            rows: _members.map((m) => DataRow(cells: [
                              DataCell(Text(m['invitedEmail']?.toString() ?? m['name']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500))),
                              DataCell(_RoleBadge(
                                role: m['role'] ?? 'STAFF',
                                bgColor: _roleBg(m['role'] ?? 'STAFF'),
                                textColor: _roleText(m['role'] ?? 'STAFF'),
                              )),
                              DataCell(Text(_formatDate(m['invitedAt'] ?? m['createdAt']),
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(
                                SizedBox(
                                  height: 28,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.security, size: 14),
                                    label: const Text('Permissions', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _showPermissionsSheet(m),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      side: const BorderSide(color: AppColors.border),
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  height: 28,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 14),
                                    label: const Text('Supprimer', style: TextStyle(fontSize: 11)),
                                    onPressed: () => _confirmDeleteMember(m['id']),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      side: const BorderSide(color: AppColors.danger),
                                      foregroundColor: AppColors.danger,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                              ),
                            ])).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_members.isEmpty)
                  const Card(
                    margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 48, color: AppColors.border),
                            SizedBox(height: 8),
                            Text('Aucun membre pour le moment',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            )),
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)));

  void _showPermissionsSheet(dynamic member) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Permissions', style: AppTypography.heading3),
            const SizedBox(height: 16),
            Text('Email: ${member['invitedEmail'] ?? ''}'),
            Text('Rôle: ${member['role'] ?? 'STAFF'}'),
            const SizedBox(height: 12),
            const Divider(),
            const Text('• Gérer les produits'),
            const Text('• Gérer les commandes'),
            const Text('• Voir les clients'),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final Color bgColor;
  final Color textColor;

  const _RoleBadge({required this.role, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final displayName = role[0] + role.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(100)),
      child: Text(displayName, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _AddMemberSheet({required this.onDone});
  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _emailCtrl = TextEditingController();
  String _role = 'STAFF';
  bool _saving = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final api = ApiClient();
    try {
      await api.post('/team/invite', data: {
        'boutiqueId': context.read<BoutiqueProvider>().activeBoutique?.id,
        'email': _emailCtrl.text.trim(),
        'role': _role,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation envoyée à ${_emailCtrl.text.trim()}')));
        Navigator.pop(context);
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${ApiClient.extractErrorMessage(e)}'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajouter un membre', style: AppTypography.heading3),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email *'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: const [
              DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
              DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
              DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'STAFF'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _invite,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Inviter'),
          ),
        ],
      ),
    );
  }
}
