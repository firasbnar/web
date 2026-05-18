import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/team_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../models/team_member.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  TeamProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initProvider());
  }

  void _initProvider() {
    if (_provider != null) return;
    final p = TeamProvider();
    _provider = p;
    if (mounted) setState(() {});
    final bp = context.read<BoutiqueProvider>();
    final bid = bp.activeBoutique?.id;
    if (bid != null) p.loadMembers(bid);
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<TeamProvider>(
        builder: (_, p, __) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Gestion d\'Équipe'),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Inviter un membre',
                onPressed: () => _showInviteDialog(p),
              ),
            ],
          ),
          body: _buildBody(p),
        ),
      ),
    );
  }

  Widget _buildBody(TeamProvider p) {
    if (p.loading && p.members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && p.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(p.error!, style: const TextStyle(color: AppColors.danger)),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: () {
                final bid = context.read<BoutiqueProvider>().activeBoutique?.id;
                if (bid != null) p.loadMembers(bid);
              },
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        final bid = context.read<BoutiqueProvider>().activeBoutique?.id;
        if (bid != null) p.loadMembers(bid);
      },
      child: CustomScrollView(
        slivers: [
          _statsHeader(p),
          _searchAndFilterBar(p),
          if (p.filteredMembers.isEmpty)
            SliverFillRemaining(child: _emptyState(p))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _memberCard(p.filteredMembers[i], p),
                  childCount: p.filteredMembers.length,
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _statsHeader(TeamProvider p) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4040C8), Color(0xFF8B2FC9)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestion d\'Équipe',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('Gérez les membres de votre boutique',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statBadge(Icons.people_outline, '${p.totalMembers ?? 0}', 'Total'),
                const SizedBox(width: 12),
                _statBadge(Icons.check_circle_outline, '${p.activeMembers ?? 0}', 'Actifs'),
                const SizedBox(width: 12),
                _statBadge(Icons.hourglass_empty, '${p.pendingInvitations ?? 0}', 'En attente'),
              ],
            ),
            if (p.roleDistribution != null && p.roleDistribution!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: p.roleDistribution!.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${_roleLabel(e.key)}: ${e.value}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _searchAndFilterBar(TeamProvider p) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un membre...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: p.searchQuery != null && p.searchQuery!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => p.setSearch(''),
                      )
                    : null,
              ),
              onChanged: p.setSearch,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Tous', p.roleFilter == null, () => p.setRoleFilter(null)),
                  _filterChip('Admin', p.roleFilter == 'ADMIN', () => p.setRoleFilter('ADMIN')),
                  _filterChip('Manager', p.roleFilter == 'MANAGER', () => p.setRoleFilter('MANAGER')),
                  _filterChip('Staff', p.roleFilter == 'STAFF', () => p.setRoleFilter('STAFF')),
                  _filterChip('Caissier', p.roleFilter == 'CAISSIER', () => p.setRoleFilter('CAISSIER')),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: AppColors.border),
                  const SizedBox(width: 8),
                  _filterChip('Actif', p.statusFilter == 'ACTIVE', () => p.setStatusFilter('ACTIVE')),
                  _filterChip('En attente', p.statusFilter == 'PENDING', () => p.setStatusFilter('PENDING')),
                  _filterChip('Désactivé', p.statusFilter == 'DEACTIVATED', () => p.setStatusFilter('DEACTIVATED')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberCard(TeamMember member, TeamProvider p) {
    final canManage = true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMemberDetails(member),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _avatarBg(member.role),
                child: Text(
                  _initials(member.displayName),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(member.displayName,
                              style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        _roleBadge(member.role),
                        if (member.isPending)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(30),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text('En attente',
                                  style: TextStyle(fontSize: 9, color: Colors.orange.shade700)),
                            ),
                          ),
                        if (member.isDeactivated)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withAlpha(30),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text('Désactivé',
                                  style: TextStyle(fontSize: 9, color: AppColors.danger)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(member.displayEmail,
                        style: AppTypography.caption, overflow: TextOverflow.ellipsis),
                    if (member.lastActivityAt != null)
                      Text('Dernière activité: ${_formatDate(member.lastActivityAt!)}',
                          style: AppTypography.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (v) => _handleAction(v, member, p),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'permissions', child: Text('Permissions', style: TextStyle(fontSize: 13))),
                    const PopupMenuItem(value: 'edit_role', child: Text('Changer le rôle', style: TextStyle(fontSize: 13))),
                    if (member.isActive)
                      const PopupMenuItem(value: 'deactivate', child: Text('Désactiver', style: TextStyle(fontSize: 13, color: Colors.orange)))
                    else
                      const PopupMenuItem(value: 'activate', child: Text('Activer', style: TextStyle(fontSize: 13, color: AppColors.success))),
                    const PopupMenuItem(value: 'remove', child: Text('Supprimer', style: TextStyle(fontSize: 13, color: AppColors.danger))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(String action, TeamMember member, TeamProvider p) {
    final bid = context.read<BoutiqueProvider>().activeBoutique?.id;
    if (bid == null) return;
    switch (action) {
      case 'permissions':
        _showPermissionsSheet(member);
        break;
      case 'edit_role':
        _showEditRoleDialog(member, p, bid);
        break;
      case 'deactivate':
        _confirmAndExecute('Désactiver ce membre ?', () => p.toggleStatus(member.id, bid, false));
        break;
      case 'activate':
        _confirmAndExecute('Activer ce membre ?', () => p.toggleStatus(member.id, bid, true));
        break;
      case 'remove':
        _confirmAndExecute('Supprimer ce membre ? Cette action est irréversible.', () => p.removeMember(member.id, bid));
        break;
    }
  }

  Future<void> _confirmAndExecute(String message, Future<String?> Function() action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final err = await action();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Opération réussie'),
        backgroundColor: err != null ? AppColors.danger : AppColors.success,
      ));
    }
  }

  Widget _emptyState(TeamProvider p) {
    final hasFilters = p.searchQuery != null || p.roleFilter != null || p.statusFilter != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasFilters ? Icons.search_off : Icons.people_outline, size: 56, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            hasFilters ? 'Aucun résultat' : 'Aucun membre dans l\'équipe',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: p.clearFilters,
              child: const Text('Effacer les filtres'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Inviter un membre'),
              onPressed: () => _showInviteDialog(p),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInviteDialog(TeamProvider p) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'STAFF';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Inviter un membre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Ils recevront un email avec un lien d\'invitation',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Administrateur')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                  DropdownMenuItem(value: 'CAISSIER', child: Text('Caissier')),
                ],
                onChanged: (v) => setSheetState(() => selectedRole = v ?? 'STAFF'),
              ),
              const SizedBox(height: 8),
              _roleDescription(selectedRole),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
                    setSheetState(() => saving = true);
                    final bid = context.read<BoutiqueProvider>().activeBoutique?.id;
                    if (bid == null) return;
                    final err = await p.inviteMember(bid, emailCtrl.text.trim(), nameCtrl.text.trim(), selectedRole);
                    if (ctx.mounted) {
                      if (err != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(err), backgroundColor: AppColors.danger));
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Invitation envoyée'), backgroundColor: AppColors.success));
                        Navigator.pop(ctx);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Envoyer l\'invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleDescription(String role) {
    String desc;
    switch (role) {
      case 'ADMIN':
        desc = 'Accès complet : gère l\'équipe, les produits, les commandes et les paramètres.';
        break;
      case 'MANAGER':
        desc = 'Gère les produits, commandes, catégories et clients. Accès aux analyses.';
        break;
      case 'STAFF':
        desc = 'Gère les produits et le stock. Peut voir les commandes.';
        break;
      case 'CAISSIER':
        desc = 'Crée des commandes et valide les paiements via le POS.';
        break;
      default:
        desc = '';
    }
    return Text(desc, style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
  }

  void _showEditRoleDialog(TeamMember member, TeamProvider p, String boutiqueId) {
    String newRole = member.role;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Changer le rôle de ${member.displayName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...['ADMIN', 'MANAGER', 'STAFF', 'CAISSIER'].map((r) => RadioListTile<String>(
                value: r,
                groupValue: newRole,
                title: Text(_roleLabel(r), style: const TextStyle(fontSize: 14)),
                subtitle: Text(_roleDesc(r), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                onChanged: (v) => setSheetState(() => newRole = v!),
                dense: true,
              )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final err = await p.updateRole(member.id, boutiqueId, newRole);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err ?? 'Rôle mis à jour'),
                        backgroundColor: err != null ? AppColors.danger : AppColors.success,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberDetails(TeamMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _avatarBg(member.role),
                  child: Text(_initials(member.displayName),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(member.displayEmail,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Rôle', member.roleLabel),
            _detailRow('Statut', member.statusLabel),
            if (member.joinedAt != null) _detailRow('A rejoint le', _formatDate(member.joinedAt!)),
            if (member.lastActivityAt != null) _detailRow('Dernière activité', _formatDate(member.lastActivityAt!)),
            if (member.permissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...member.permissions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(_permissionLabel(p), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  void _showPermissionsSheet(TeamMember member) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Permissions — ${member.displayName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Rôle: ${member.roleLabel}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            if (member.permissions.isEmpty)
              const Text('Aucune permission définie', style: TextStyle(color: AppColors.textSecondary))
            else
              ...member.permissions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    const SizedBox(width: 10),
                    Text(_permissionLabel(p), style: const TextStyle(fontSize: 13)),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _avatarBg(role).withAlpha(25),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(_roleLabel(role), style: TextStyle(fontSize: 9, color: _avatarBg(role), fontWeight: FontWeight.w600)),
    );
  }

  Color _avatarBg(String role) {
    switch (role) {
      case 'OWNER': return const Color(0xFF8B2FC9);
      case 'ADMIN': return const Color(0xFFE67E22);
      case 'MANAGER': return AppColors.primary;
      case 'STAFF': return AppColors.textSecondary;
      case 'CAISSIER': return const Color(0xFF27AE60);
      default: return AppColors.textSecondary;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'ADMIN': return 'Administrateur';
      case 'MANAGER': return 'Manager';
      case 'STAFF': return 'Staff';
      case 'CAISSIER': return 'Caissier';
      default: return role;
    }
  }

  String _roleDesc(String role) {
    switch (role) {
      case 'ADMIN': return 'Gère l\'équipe, les produits, les commandes et les paramètres';
      case 'MANAGER': return 'Gère les produits, commandes, catégories et clients';
      case 'STAFF': return 'Gère les produits, le stock et voit les commandes';
      case 'CAISSIER': return 'Crée des commandes et valide les paiements';
      default: return '';
    }
  }

  String _permissionLabel(String perm) {
    switch (perm) {
      case 'PRODUCT_READ': return 'Voir les produits';
      case 'PRODUCT_WRITE': return 'Ajouter/Modifier les produits';
      case 'PRODUCT_DELETE': return 'Supprimer des produits';
      case 'STOCK_UPDATE': return 'Mettre à jour le stock';
      case 'CATEGORY_READ': return 'Voir les catégories';
      case 'CATEGORY_WRITE': return 'Gérer les catégories';
      case 'ORDER_READ': return 'Voir les commandes';
      case 'ORDER_WRITE': return 'Créer/Modifier les commandes';
      case 'ORDER_DELETE': return 'Annuler des commandes';
      case 'CUSTOMER_READ': return 'Voir les clients';
      case 'CUSTOMER_WRITE': return 'Gérer les clients';
      case 'ANALYTICS_READ': return 'Voir les analyses';
      case 'TEAM_READ': return 'Voir l\'équipe';
      case 'TEAM_WRITE': return 'Inviter des membres';
      case 'TEAM_DELETE': return 'Supprimer des membres';
      case 'SETTINGS_READ': return 'Voir les paramètres';
      case 'SETTINGS_WRITE': return 'Modifier les paramètres';
      case 'BILLING_READ': return 'Voir la facturation';
      case 'BILLING_WRITE': return 'Gérer l\'abonnement';
      case 'POS_ACCESS': return 'Accès au POS';
      case 'PAYMENT_VALIDATE': return 'Valider les paiements';
      case 'MESSAGE_READ': return 'Voir les messages';
      case 'MESSAGE_WRITE': return 'Envoyer des messages';
      case 'DISCOUNT_WRITE': return 'Gérer les réductions';
      case 'INVENTORY_READ': return 'Voir l\'inventaire';
      case 'INVENTORY_WRITE': return 'Gérer l\'inventaire';
      default: return perm;
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      return iso.substring(0, 10);
    } catch (_) {
      return iso;
    }
  }
}
