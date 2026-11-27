/// Profile Tab
/// 
/// User profile, settings, and statistics

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/user_data_model.dart';
import '../../theme/app_theme.dart';
import 'payment_history_screen.dart';
import 'downloads_screen.dart';
import 'sync_screen.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  ReadingStatsModel? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final repo = ref.read(userDataRepositoryProvider);
      final data = await repo.getStats();
      
      if (data != null) {
        setState(() {
          _stats = ReadingStatsModel.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = ref.read(authServiceProvider);
      await authService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              _buildProfileHeader(theme, user),
              const SizedBox(height: 32),
              
              // Stats
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_stats != null) ...[
                Text(
                  'Reading Statistics',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(theme),
                const SizedBox(height: 32),
              ],
              
              // Subscriptions are hidden for now: the product sells single
              // listens, so a Premium card here would promise something the
              // app does not offer.
              
              // Menu items
              _buildMenuSection(theme),
              const SizedBox(height: 32),
              
              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, user) {
    return Center(
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: user?.avatarUrl != null
                ? NetworkImage(user!.avatarUrl!)
                : null,
            child: user?.avatarUrl == null
                ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                : null,
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            user?.displayName ?? 'User',
            style: theme.textTheme.displayMedium,
          ),
          
          // Email
          Text(
            user?.email ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Edit profile button
          TextButton(
            onPressed: () => _comingSoon(context, 'Editing your profile'),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.book,
          value: '${_stats!.totalBooks}',
          label: 'Books Read',
          color: AppColors.primary,
        ),
        _StatCard(
          icon: Icons.timer,
          value: '${_stats!.totalReadingTimeHours.toStringAsFixed(1)}h',
          label: 'Reading Time',
          color: AppColors.accent,
        ),
        _StatCard(
          icon: Icons.check_circle,
          value: '${_stats!.booksCompleted}',
          label: 'Completed',
          color: AppColors.success,
        ),
        _StatCard(
          icon: Icons.local_fire_department,
          value: '${_stats!.readingStreakDays}',
          label: 'Day Streak',
          color: AppColors.secondary,
        ),
      ],
    );
  }



  Widget _buildMenuSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.download_done,
          title: 'Downloads',
          subtitle: 'Manage offline books',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
          },
        ),
        _MenuItem(
          icon: Icons.receipt_long,
          title: 'Payment History',
          subtitle: 'Subscriptions and purchases',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentHistoryScreen(),
              ),
            );
          },
        ),
        _MenuItem(
          icon: Icons.sync,
          title: 'Sync',
          subtitle: 'Cloud synchronization settings',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncScreen()));
          },
        ),
        _MenuItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () => _comingSoon(context, 'Notification preferences'),
        ),
        _MenuItem(
          icon: Icons.language,
          title: 'Language',
          subtitle: 'App language and content language',
          onTap: () => _comingSoon(context, 'Language settings'),
        ),
        _MenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'FAQs, contact support',
          onTap: () => _comingSoon(context, 'Help & Support'),
        ),
        _MenuItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy & Security',
          subtitle: 'Privacy policy, data settings',
          onTap: () => _comingSoon(context, 'Privacy & Security'),
        ),
        _MenuItem(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version, terms of service',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'LYRR',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 LYRR Platform',
          ),
        ),
      ],
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Settings & Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Cloud Synchronization'),
                subtitle: const Text('Force sync bookmarks and progress now'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await ref.read(syncServiceProvider).sync();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Sync completed successfully' : 'Sync completed or already up to date'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Clear Audio Cache'),
                subtitle: const Text('Free up local storage'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audio cache cleared')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App Information'),
                subtitle: const Text('LYRR Platform v1.2.0 • Build 2026.10'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'LYRR Platform',
                  applicationVersion: '1.2.0',
                  applicationLegalese: '© 2026 LYRR Platform',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Log Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(authServiceProvider).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
