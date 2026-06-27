/// Profile Tab
/// 
/// User profile, settings, and statistics

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/user_data_model.dart';
import '../../theme/app_theme.dart';

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
            onPressed: () {
              // TODO: Navigate to settings
            },
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
              if (_stats != null) ...[
                Text(
                  'Reading Statistics',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(theme),
                const SizedBox(height: 32),
              ],
              
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
            onPressed: () {
              // TODO: Edit profile
            },
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
            // TODO: Navigate to downloads
          },
        ),
        _MenuItem(
          icon: Icons.sync,
          title: 'Sync',
          subtitle: 'Cloud synchronization settings',
          onTap: () {
            // TODO: Navigate to sync settings
          },
        ),
        _MenuItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () {
            // TODO: Navigate to notifications
          },
        ),
        _MenuItem(
          icon: Icons.language,
          title: 'Language',
          subtitle: 'App language and content language',
          onTap: () {
            // TODO: Navigate to language settings
          },
        ),
        _MenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'FAQs, contact support',
          onTap: () {
            // TODO: Navigate to help
          },
        ),
        _MenuItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy & Security',
          subtitle: 'Privacy policy, data settings',
          onTap: () {
            // TODO: Navigate to privacy
          },
        ),
        _MenuItem(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'App version, terms of service',
          onTap: () {
            // TODO: Navigate to about
          },
        ),
      ],
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
